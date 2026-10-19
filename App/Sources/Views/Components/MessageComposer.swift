import MessageUI
import SwiftUI

/// Pre-filled iMessage/SMS to the accountability partner. Falls back to an sms: link when
/// the device can't send messages (e.g. the simulator).
struct MessageComposer: UIViewControllerRepresentable {
    let recipient: String
    let body: String
    let onFinish: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> UIViewController {
        guard MFMessageComposeViewController.canSendText() else {
            return UIHostingController(rootView: FallbackView(recipient: recipient, message: body))
        }
        let controller = MFMessageComposeViewController()
        controller.recipients = [recipient]
        controller.body = body
        controller.messageComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {}

    // UIKit calls this delegate on the main thread.
    @MainActor
    final class Coordinator: NSObject, @preconcurrency MFMessageComposeViewControllerDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }

        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true)
            if result == .sent { onFinish() }
        }
    }

    struct FallbackView: View {
        let recipient: String
        let message: String

        var body: some View {
            VStack(spacing: 16) {
                Text("This device can't send texts.").font(.headline)
                Text(message).foregroundStyle(.secondary).padding()
                ShareLink(item: message) { Label("Share instead", systemImage: "square.and.arrow.up") }
            }
            .padding()
        }
    }
}
