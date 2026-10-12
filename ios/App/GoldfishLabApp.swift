import SwiftUI

@main
struct GoldfishLabApp: App {
    var body: some Scene {
        WindowGroup {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: "fish.fill").font(.system(size: 60)).foregroundColor(.orange)
                    Text("Goldfish on your iPhone").font(.largeTitle.bold())
                    Text("1. Run Goldfish Lab on your Linux computer and link WhatsApp there.")
                    Text("2. On this iPhone, open Settings → General → Keyboard → Keyboards → Add New Keyboard → Goldfish.")
                    Text("3. Enable Allow Full Access for Goldfish. This lets the keyboard contact your computer.")
                    Text("4. In any text field, hold the globe key and choose Goldfish. Enter the computer address and pairing code once.")
                    Text("Then open a new unread WhatsApp message and tap Goldfish to try a reply.").font(.headline)
                    Text("This experiment uses recent read activity to infer a conversation. It cannot verify which chat is currently on screen. Check the draft before sending.")
                    Text("The keyboard sends text to your computer only when you tap Goldfish. Replies use your desktop Goldfish memory and its existing AI service. It never sends WhatsApp messages for you.").font(.footnote).foregroundColor(.secondary)
                }.padding(28)
            }
        }
    }
}
