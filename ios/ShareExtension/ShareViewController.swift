import UIKit

final class ShareViewController: UIViewController {
    private let appGroup = "group.com.compete.youcam2.share"
    private let sharedTextKey = "sharedProductText"
    private var completed = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        receiveSharedProduct()
    }

    private func receiveSharedProduct() {
        guard
            let item = extensionContext?.inputItems.first as? NSExtensionItem,
            let attachments = item.attachments
        else {
            finishWithoutContent()
            return
        }

        for attachment in attachments {
            if attachment.hasItemConformingToTypeIdentifier("public.url") {
                load(attachment, type: "public.url")
                return
            }
            if attachment.hasItemConformingToTypeIdentifier("public.plain-text") {
                load(attachment, type: "public.plain-text")
                return
            }
            if attachment.hasItemConformingToTypeIdentifier("public.text") {
                load(attachment, type: "public.text")
                return
            }
        }
        finishWithoutContent()
    }

    private func load(_ provider: NSItemProvider, type: String) {
        provider.loadItem(forTypeIdentifier: type, options: nil) { [weak self] value, _ in
            guard let self else { return }
            let text: String?
            if let url = value as? URL {
                text = url.absoluteString
            } else if let value = value as? String {
                text = value
            } else {
                text = nil
            }
            DispatchQueue.main.async {
                guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    self.finishWithoutContent()
                    return
                }
                self.openHostApp(with: text)
            }
        }
    }

    private func openHostApp(with text: String) {
        guard !completed else { return }
        completed = true
        let defaults = UserDefaults(suiteName: appGroup)
        defaults?.set(text, forKey: sharedTextKey)
        defaults?.synchronize()

        let url = URL(string: "ShareMedia-com.compete.youcam2://share")!
        var responder: UIResponder? = self
        while let current = responder {
            if let application = current as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                break
            }
            responder = current.next
        }
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    private func finishWithoutContent() {
        guard !completed else { return }
        completed = true
        extensionContext?.cancelRequest(
            withError: NSError(
                domain: "com.compete.youcam2.share",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No product link was shared."]
            )
        )
    }
}
