//  DictionarySearchView.swift
//  MaruReader
//
//  Dictionary search view with integrated HTML rendering.
//
import os.log
import ReadiumAdapterGCDWebServer
import ReadiumShared
import SwiftUI
import WebKit

struct DictionarySearchView: View {
    let initialQuery: String?
    @StateObject private var viewModel: DictionarySearchViewModel

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "DictionarySearchView")

    init(initialQuery: String? = nil) {
        self.initialQuery = initialQuery
        _viewModel = StateObject(wrappedValue: DictionarySearchViewModel(initialQuery: initialQuery))
        logger.debug("DictionarySearchView initialized with query: \(initialQuery ?? "nil")")
    }

    var body: some View {
        DictionaryWebViewRepresentable(viewModel: viewModel)
            .onAppear {
                viewModel.start()
            }
    }
}

/// View model managing the HTTP server lifecycle for dictionary search.
@MainActor
class DictionarySearchViewModel: ObservableObject {
    private var httpServer: GCDHTTPServer?
    @Published private(set) var baseURL: HTTPURL?
    private let searchService = DictionarySearchService()
    let initialQuery: String?
    weak var webView: WKWebView?

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "DictionarySearchViewModel")

    init(initialQuery: String? = nil) {
        self.initialQuery = initialQuery
    }

    func navigateToTerm(_ term: String) {
        guard let baseURL,
              let webView
        else {
            logger.debug("Cannot navigate: baseURL or webView not available")
            return
        }

        let encodedQuery = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? term
        let urlString = "\(baseURL)/dictionary-lookup/results.html?query=\(encodedQuery)"

        logger.debug("Navigating to term '\(term)' -> \(urlString)")

        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
    }

    func start() {
        guard httpServer == nil else { return }

        do {
            let server = GCDHTTPServer(assetRetriever: AssetRetriever(httpClient: DefaultHTTPClient()))

            // Register dictionary handlers - we need the base URL before registering lookup handler
            let mediaURL = try server.serve(
                at: "dictionary-media",
                handler: DictionaryHTTPHandlers.createMediaHandler()
            )

            _ = try server.serve(
                at: "dictionary-resources",
                handler: DictionaryHTTPHandlers.createResourceHandler()
            )

            // Extract base URL (scheme://host:port) from the media endpoint URL
            // mediaURL is like "http://localhost:PORT/dictionary-media/"
            // We need "http://localhost:PORT"
            guard let baseURLString = mediaURL.string.components(separatedBy: "/dictionary-media").first,
                  let serverBaseURL = HTTPURL(string: baseURLString)
            else {
                throw NSError(domain: "DictionarySearchViewModel", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to extract base URL from server",
                ])
            }

            _ = try server.serve(
                at: "dictionary-lookup",
                handler: DictionaryHTTPHandlers.createLookupHandler(
                    searchService: searchService,
                    baseURL: serverBaseURL
                )
            )

            self.httpServer = server
            self.baseURL = serverBaseURL

            logger.debug("Dictionary HTTP server started at: \(self.baseURL?.string ?? "unknown")")
        } catch {
            logger.debug("Failed to start dictionary HTTP server: \(error)")
        }
    }

    func stop() {
        httpServer = nil
        baseURL = nil
    }
}

/// UIViewRepresentable wrapper for WKWebView displaying dictionary content.
struct DictionaryWebViewRepresentable: UIViewRepresentable {
    @ObservedObject var viewModel: DictionarySearchViewModel

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "DictionaryWebViewRepresentable")

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Register message handler for recursive term lookups
        config.userContentController.add(context.coordinator, name: "dictionaryTermSelected")

        let webView = WKWebView(frame: .zero, configuration: config)

        // Store webView reference in view model for navigation
        viewModel.webView = webView

        #if DEBUG
            if #available(iOS 16.4, *) {
                webView.isInspectable = true
            }
        #endif

        return webView
    }

    class Coordinator: NSObject, WKScriptMessageHandler {
        let viewModel: DictionarySearchViewModel

        private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "DictionaryWebViewCoordinator")

        init(viewModel: DictionarySearchViewModel) {
            self.viewModel = viewModel
        }

        func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "dictionaryTermSelected",
                  let term = message.body as? String
            else {
                return
            }

            logger.debug("Dictionary term selected from popup in DictionarySearchView: \(term)")

            Task { @MainActor in
                viewModel.navigateToTerm(term)
            }
        }
    }

    func updateUIView(_ webView: WKWebView, context _: Context) {
        // Load initial page when baseURL becomes available
        guard let baseURL = viewModel.baseURL else {
            logger.debug("DictionarySearchView: baseURL not yet available")
            return
        }

        // Only load if not already loaded
        if webView.url == nil {
            let urlString: String
            if let initialQuery = viewModel.initialQuery, !initialQuery.isEmpty {
                // If we have an initial query, load the results page directly
                let encodedQuery = initialQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? initialQuery
                urlString = "\(baseURL)/dictionary-lookup/results.html?query=\(encodedQuery)"
                logger.debug("DictionarySearchView: Loading with initial query '\(initialQuery)' -> \(urlString)")
            } else {
                // Otherwise load the main dictionary search view
                urlString = "\(baseURL)/dictionary-lookup/dictionarysearchview.html"
                logger.debug("DictionarySearchView: Loading main dictionary view (no query)")
            }

            if let url = URL(string: urlString) {
                webView.load(URLRequest(url: url))
            }
        } else {
            logger.debug("DictionarySearchView: WebView already loaded, skipping")
        }
    }
}

#Preview {
    DictionarySearchView()
}
