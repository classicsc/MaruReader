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
    @StateObject private var viewModel = DictionarySearchViewModel()

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
        guard let baseURL = viewModel.baseURL else { return }

        // Only load if not already loaded
        if webView.url == nil {
            if let url = URL(string: "\(baseURL)/dictionary-lookup/dictionarysearchview.html") {
                webView.load(URLRequest(url: url))
            }
        }
    }
}

#Preview {
    DictionarySearchView()
}
