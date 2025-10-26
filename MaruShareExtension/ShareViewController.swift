import MaruDictionaryUICommon
import MaruReaderCore
import Social
import SwiftUI
import UIKit

class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        // Extract shared text
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first,
              itemProvider.hasItemConformingToTypeIdentifier("public.text")
        else {
            cancelRequest()
            return
        }

        itemProvider.loadItem(forTypeIdentifier: "public.text", options: nil) { [weak self] item, _ in
            guard let text = item as? String else {
                self?.cancelRequest()
                return
            }

            DispatchQueue.main.async {
                self?.showDictionarySearch(for: text)
            }
        }
    }

    private func showDictionarySearch(for text: String) {
        let searchView = SearchView(query: text) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }

        let hostingController = UIHostingController(rootView: searchView)

        // Present or embed the SwiftUI view
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostingController.didMove(toParent: self)
    }

    private func cancelRequest() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}

struct SearchView: View {
    private var viewModel = DictionarySearchViewModel()
    private let onDismiss: (() -> Void)?

    init(query: String, onDismiss: (() -> Void)? = nil) {
        viewModel.performSearch(query)
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            DictionarySearchView()
                .environment(viewModel)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            onDismiss?()
                        }
                    }
                }
        }
    }
}
