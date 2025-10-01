//  DictionarySearchView.swift
//  MaruReader
//
//  Dictionary search view with integrated HTML rendering.
//
import ReadiumAdapterGCDWebServer
import ReadiumShared
import SwiftUI
import WebKit

struct DictionarySearchView: View {
    let initialQuery: String?
    @StateObject private var viewModel: DictionarySearchViewModel

    init(initialQuery: String? = nil) {
        self.initialQuery = initialQuery
        _viewModel = StateObject(wrappedValue: DictionarySearchViewModel(initialQuery: initialQuery))
        print("DictionarySearchView initialized with query: \(initialQuery ?? "nil")")
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

    init(initialQuery: String? = nil) {
        self.initialQuery = initialQuery
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

            print("Dictionary HTTP server started at: \(baseURL?.string ?? "unknown")")
        } catch {
            print("Failed to start dictionary HTTP server: \(error)")
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

    func makeUIView(context _: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)

        #if DEBUG
            if #available(iOS 16.4, *) {
                webView.isInspectable = true
            }
        #endif

        return webView
    }

    func updateUIView(_ webView: WKWebView, context _: Context) {
        // Load initial page when baseURL becomes available
        guard let baseURL = viewModel.baseURL else {
            print("DictionarySearchView: baseURL not yet available")
            return
        }

        // Only load if not already loaded
        if webView.url == nil {
            let urlString: String
            if let initialQuery = viewModel.initialQuery, !initialQuery.isEmpty {
                // If we have an initial query, load the results page directly
                let encodedQuery = initialQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? initialQuery
                urlString = "\(baseURL)/dictionary-lookup/results.html?query=\(encodedQuery)"
                print("DictionarySearchView: Loading with initial query '\(initialQuery)' -> \(urlString)")
            } else {
                // Otherwise load the main dictionary search view
                urlString = "\(baseURL)/dictionary-lookup/dictionarysearchview.html"
                print("DictionarySearchView: Loading main dictionary view (no query)")
            }

            if let url = URL(string: urlString) {
                webView.load(URLRequest(url: url))
            }
        } else {
            print("DictionarySearchView: WebView already loaded, skipping")
        }
    }
}

#Preview {
    DictionarySearchView()
}
