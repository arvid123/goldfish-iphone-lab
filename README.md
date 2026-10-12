# Goldfish iPhone keyboard experiment

A native iPhone keyboard and a Linux backend. The keyboard's Goldfish button
rewrites exposed input text, or drafts an empty-field reply using a recent
WhatsApp read signal, synchronized conversation text, and local Goldfish memory.
It inserts drafts only. It never sends WhatsApp messages.

## What is and isn't established

The Linux state checks and API access checks passed. The app and keyboard
compiled successfully on a standard GitHub macOS runner (run 38244690315).
The unsigned IPA includes both the app and the keyboard extension, targeting
iOS 16 or newer. Signing, sideloading, and actual WhatsApp read synchronization
must still be verified on the user's device.
The app cannot establish which chat is on screen. A read signal is an inference
and may originate from another linked device or a notification. Switching to an
already-read chat can leave that inference wrong, even within its 30-second
expiry. Check the recipient and draft before sending. This is a feasibility
experiment, not a finished messaging product.

## Start the Linux backend

Goldfish must be running and signed in on this computer.

```sh
bun install
bun test
bun run start
```

Open `http://127.0.0.1:8765/setup` on the computer. Use WhatsApp on your iPhone
to link a device by scanning the displayed QR code. Keep the phone and computer
on the same trusted Wi-Fi. The console shows the computer address.

The setup page also shows a six-digit keyboard pairing code, valid for ten
minutes and one use. Refresh the computer setup page for another code. The backend is
reachable on your LAN; `/setup` is restricted to loopback and the phone API
requires its own bearer token. This local prototype uses HTTP on Wi-Fi; don't
expose it to the internet. Production needs an encrypted connection.

Credentials are saved in `.state/` (or `LAB_STATE_DIR`) with restrictive
permissions. Chat text stays in bounded RAM and is lost on restart. WhatsApp
credentials persist so you don't need to link each time. The library may persist
protocol key/state data. No Goldfish account tokens are sent to the phone.
Selected conversation/memory is sent to Goldfish's existing AI gateway only
when you tap the button. No new payment, subscription, or paid model key is
configured; existing Goldfish account usage limits still apply.

## Build without owning a Mac

The included workflow runs only on a **public** repository and uses a standard
GitHub-hosted macOS runner. It refuses private-repository runs to avoid relying
on potentially billable allowances. No signing secrets, backend addresses,
pairing tokens, or memory are required by the workflow.

Run the `Free unsigned iPhone build` workflow. Download and unzip the
`GoldfishLab-unsigned` artifact to get the IPA. An unsigned IPA cannot be
installed directly: an installer must sign both the app and keyboard extension
using your ordinary Apple account.

On a Mac the equivalent commands are:

```sh
brew install xcodegen
cd ios
xcodegen generate
xcodebuild -project GoldfishLab.xcodeproj -scheme GoldfishLab \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

## Install for free from Linux

Use SideStore's current official instructions, which support Linux and ordinary
Apple accounts: https://docs.sidestore.io/docs/installation/prerequisites

The current initial installer is **iloader**, not the older SideServer Linux
instructions. USB pairing, trusting the computer, and any developer-mode prompts
need to be completed on your own phone. Enter Apple credentials directly into
the trusted signing tool, never into this project's code, GitHub, or chat.
Keep the keyboard extension when the installer offers extension selection.
Keyboard signing through this exact route remains to be validated.

On this Arch Linux computer, `libimobiledevice` is installed but `usbmuxd` is
missing. Install the USB service once with `sudo pacman -S usbmuxd`, then connect
and unlock the iPhone and accept Trust This Computer when prompted.

Free provisioning expires after seven days, so apps need periodic refresh.
Paid Apple membership, TestFlight, rented Macs, and paid GitHub runners are not
required by this proposed route. Initial signing/renewal is separate from the
normal Goldfish button interaction.

## Enable and pair the keyboard once

1. Open Goldfish Lab for instructions.
2. Add Goldfish under Settings → General → Keyboard → Keyboards.
3. Enable Allow Full Access for Goldfish so it can reach your computer.
4. Switch to Goldfish with the globe key in any text field.
5. Tap the Server field and type the LAN address shown by the Linux backend.
   Tap the Code field and type the pairing code; tap Connect.

The keyboard stores its connection in its own container. No App Group or
shared-container entitlement is used. The test target is iOS 16 or newer.

After setup, open a newly received unread WhatsApp chat and tap Goldfish.
No copying, screenshots, or conversation picker are used. If no fresh signal
exists, or different chats changed within three seconds, the backend refuses
to select a conversation. The status line identifies the inferred recipient
after a draft is inserted. Typing still works without network/Full Access.

When rewriting, iOS may expose only part of a field. The keyboard replaces
the selected text, or only the exposed text before the cursor; it never assumes
it can read and replace an entire long draft. Text/cursor changes during a
request cancel insertion. Use a short test draft initially.

## Device experiment

Test direct chats, groups, receipts enabled/disabled, notification reads,
two newly-read chats in quick succession, an already-read chat, switching from
a fresh chat to an old chat, and reading on a second linked device. In each
case record whether the recipient inference is correct and how long the signal
takes to arrive. A no-signal error is a valid result. A wrong-chat draft is a
failure, not a successful button interaction.

The WhatsApp adapter uses unofficial Baileys 7.0.0-rc14. It is a test dependency,
not an assertion of official integration or production suitability.
