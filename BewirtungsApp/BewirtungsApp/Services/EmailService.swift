import Foundation
import UIKit
import MessageUI

final class EmailService: NSObject {
    static let shared = EmailService()

    private var completionHandler: ((Bool) -> Void)?

    private override init() {
        super.init()
    }

    var canSendEmail: Bool {
        MFMailComposeViewController.canSendMail()
    }

    func composeEmail(
        to recipients: [String],
        subject: String,
        body: String,
        attachmentURL: URL,
        attachmentMimeType: String = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        from viewController: UIViewController,
        completion: @escaping (Bool) -> Void
    ) {
        guard canSendEmail else {
            // Fallback: try opening Outlook URL scheme
            openInOutlook(to: recipients, subject: subject, body: body)
            completion(false)
            return
        }

        self.completionHandler = completion

        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = self
        composer.setToRecipients(recipients)
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: false)

        if let data = try? Data(contentsOf: attachmentURL) {
            let fileName = attachmentURL.lastPathComponent
            composer.addAttachmentData(data, mimeType: attachmentMimeType, fileName: fileName)
        }

        viewController.present(composer, animated: true)
    }

    func openInOutlook(to recipients: [String], subject: String, body: String) {
        let recipientStr = recipients.joined(separator: ";")
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        if let url = URL(string: "ms-outlook://compose?to=\(recipientStr)&subject=\(encodedSubject)&body=\(encodedBody)") {
            UIApplication.shared.open(url)
        }
    }

    func shareViaActivitySheet(fileURL: URL, from viewController: UIViewController) {
        let activityVC = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )
        viewController.present(activityVC, animated: true)
    }
}

extension EmailService: MFMailComposeViewControllerDelegate {
    func mailComposeController(
        _ controller: MFMailComposeViewController,
        didFinishWith result: MFMailComposeResult,
        error: Error?
    ) {
        controller.dismiss(animated: true) { [weak self] in
            self?.completionHandler?(result == .sent)
            self?.completionHandler = nil
        }
    }
}
