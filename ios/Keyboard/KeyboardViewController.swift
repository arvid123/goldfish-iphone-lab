import UIKit

@MainActor
final class KeyboardViewController: UIInputViewController {
    private let stack = UIStackView()
    private let status = UILabel()
    private let defaults = UserDefaults.standard // Extension-local storage; no App Group needed.
    private var endpoint = ""
    private var token = ""
    private var code = ""
    private var editingServer = false
    private var numbers = false
    private var shifted = false
    private var busy = false
    private var operation: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()
        endpoint = defaults.string(forKey: "endpoint") ?? "http://192.168.1.2:8765"
        token = defaults.string(forKey: "token") ?? ""
        view.backgroundColor = .secondarySystemBackground
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        let height = view.heightAnchor.constraint(equalToConstant: 330)
        height.priority = .defaultHigh
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8), height
        ])
        rebuild()
    }

    override func viewWillDisappear(_ animated: Bool) {
        operation?.cancel()
        operation = nil
        busy = false
        super.viewWillDisappear(animated)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if isViewLoaded { rebuild() }
    }

    private func button(_ title: String, color: UIColor = .label, action: @escaping () -> Void) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.setTitleColor(color, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        b.backgroundColor = .tertiarySystemBackground
        b.layer.cornerRadius = 7
        b.accessibilityLabel = title
        b.addAction(UIAction { _ in action() }, for: .touchUpInside)
        b.heightAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
        return b
    }

    private func row(_ buttons: [UIButton]) {
        let r = UIStackView(arrangedSubviews: buttons)
        r.axis = .horizontal
        r.spacing = 5
        r.distribution = .fillEqually
        stack.addArrangedSubview(r)
    }

    private func rebuild() {
        for v in stack.arrangedSubviews { stack.removeArrangedSubview(v); v.removeFromSuperview() }
        status.numberOfLines = 2
        status.font = .systemFont(ofSize: 12)
        status.textColor = .secondaryLabel
        status.text = token.isEmpty ? "Connect once. Type the server address and pairing code using the keys below." : "Goldfish uses recent WhatsApp reads; the current chat is inferred."
        stack.addArrangedSubview(status)
        if token.isEmpty {
            row([
                button("Server: \(endpoint)") { [weak self] in self?.editingServer = true; self?.endpoint = ""; self?.rebuild() },
                button("Code: \(code)") { [weak self] in self?.editingServer = false; self?.rebuild() },
                button(busy ? "Connecting…" : "Connect", color: .systemOrange) { [weak self] in self?.pair() }
            ])
        } else {
            row([
                button(busy ? "Thinking…" : "Goldfish", color: .systemOrange) { [weak self] in self?.goldfish() },
                button("Reconnect") { [weak self] in
                    guard let self = self, !self.busy else { return }
                    self.token = ""; self.defaults.removeObject(forKey: "token"); self.rebuild()
                }
            ])
        }
        let letters = numbers ? ["1234567890", "-/:.?!@_", "'+=(),"] : ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
        for line in letters {
            row(line.map { ch in
                let text = shifted && !numbers ? String(ch).uppercased() : String(ch)
                return button(text) { [weak self] in self?.type(text) }
            })
        }
        let globe = button("🌐") {}
        globe.accessibilityLabel = "Next keyboard"
        globe.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        row([
            globe,
            button(numbers ? "ABC" : "123") { [weak self] in self?.numbers.toggle(); self?.rebuild() },
            button("⇧") { [weak self] in self?.shifted.toggle(); self?.rebuild() },
            button("space") { [weak self] in self?.type(" ") },
            button("⌫") { [weak self] in
                guard let self = self, !self.busy else { return }
                if self.token.isEmpty {
                    if self.editingServer { if !self.endpoint.isEmpty { self.endpoint.removeLast() } }
                    else if !self.code.isEmpty { self.code.removeLast() }
                    self.rebuild()
                } else { self.textDocumentProxy.deleteBackward() }
            },
            button("return") { [weak self] in self?.type("\n") }
        ])
    }

    private func type(_ text: String) {
        guard !busy else { return }
        if token.isEmpty {
            if editingServer { if endpoint.count < 180 { endpoint += text } }
            else if code.count < 6 && text.allSatisfy({ $0.isNumber }) { code += text }
            rebuild()
        } else { textDocumentProxy.insertText(text) }
    }

    private func request(_ path: String, body: [String: String]) async throws -> [String: Any] {
        guard let base = URL(string: endpoint), base.scheme == "http" || base.scheme == "https", base.host != nil,
              let url = URL(string: path, relativeTo: base) else { throw failure("Enter a valid computer address.") }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 80
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !token.isEmpty { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw failure("Unexpected computer response.") }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw failure(result["error"] as? String ?? "Could not reach Goldfish.") }
        return result
    }

    private func failure(_ message: String) -> NSError { NSError(domain: "GoldfishLab", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }

    private func pair() {
        guard !busy else { return }
        guard hasFullAccess else { status.text = "Enable Allow Full Access for Goldfish in Keyboard Settings."; return }
        busy = true; rebuild()
        operation = Task { [weak self] in
            guard let self = self else { return }
            defer { self.busy = false; self.operation = nil }
            do {
                let r = try await self.request("/pair", body: ["pin": self.code])
                try Task.checkCancellation()
                guard let t = r["token"] as? String else { throw self.failure("No pairing token received.") }
                self.token = t
                self.defaults.set(self.endpoint, forKey: "endpoint")
                self.defaults.set(t, forKey: "token")
                self.busy = false; self.rebuild()
            } catch { if !Task.isCancelled { self.busy = false; self.rebuild(); self.status.text = error.localizedDescription } }
        }
    }

    private func goldfish() {
        guard !busy else { return }
        guard hasFullAccess else { status.text = "Enable Allow Full Access for Goldfish in Keyboard Settings."; return }
        let proxy = textDocumentProxy
        let document = proxy.documentIdentifier
        let before = proxy.documentContextBeforeInput
        let after = proxy.documentContextAfterInput
        let selection = proxy.selectedText
        let draft = selection ?? before ?? ""
        guard draft.count <= 2000 else { status.text = "Select a shorter passage to rewrite."; return }
        busy = true; rebuild()
        operation = Task { [weak self] in
            guard let self = self else { return }
            defer { self.busy = false; self.operation = nil }
            do {
                let r = try await self.request("/generate", body: ["draft": draft])
                try Task.checkCancellation()
                let current = self.textDocumentProxy
                guard current.documentIdentifier == document, current.documentContextBeforeInput == before,
                      current.documentContextAfterInput == after, current.selectedText == selection else {
                    throw self.failure("Text or cursor changed while drafting. Nothing inserted.")
                }
                guard let text = r["text"] as? String, !text.isEmpty else { throw self.failure("No draft returned.") }
                // Only replace the selected text or the exposed suffix before the cursor.
                // iOS may truncate context, so never assume we have the entire field.
                if selection == nil { for _ in draft { current.deleteBackward() } }
                current.insertText(text)
                self.busy = false; self.rebuild()
                self.status.text = "Draft for \(r["conversation"] as? String ?? "you"). Check before sending."
            } catch { if !Task.isCancelled { self.busy = false; self.rebuild(); self.status.text = error.localizedDescription } }
        }
    }
}
