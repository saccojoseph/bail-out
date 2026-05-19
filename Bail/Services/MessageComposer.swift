import Foundation

/// Holds the recipients and body for a pending SMS invite.
/// Using Identifiable + .sheet(item:) ensures SwiftUI captures values
/// atomically when the sheet is triggered, avoiding empty-body bugs.
struct PendingMessage: Identifiable {
    let id = UUID()
    let recipients: [String]
    let body: String
}

#if os(iOS)
import MessageUI
import SwiftUI

struct MessageComposer: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    var onFinish: () -> Void = {}
    var onSent: () -> Void = {}   // fires only when the user actually tapped Send

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.recipients = recipients
        vc.body = body
        vc.messageComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish, onSent: onSent) }

    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onFinish: () -> Void
        let onSent: () -> Void
        init(onFinish: @escaping () -> Void, onSent: @escaping () -> Void) {
            self.onFinish = onFinish
            self.onSent = onSent
        }

        func messageComposeViewController(
            _ controller: MFMessageComposeViewController,
            didFinishWith result: MessageComposeResult
        ) {
            controller.dismiss(animated: true)
            if result == .sent { onSent() }
            onFinish()
        }
    }

    static var canSend: Bool { MFMessageComposeViewController.canSendText() }
}
#endif
