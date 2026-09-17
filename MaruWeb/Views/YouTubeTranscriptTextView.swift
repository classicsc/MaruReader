// YouTubeTranscriptTextView.swift
// MaruReader
// Copyright (c) 2026  Samuel Smoker
//
// MaruReader is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// MaruReader is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with MaruReader.  If not, see <http://www.gnu.org/licenses/>.

import MaruReaderCore
import SwiftUI
import WebKit

struct YouTubeTranscriptTextView: UIViewRepresentable {
    let model: YouTubeTranscriptViewModel
    let activeCueID: Int?
    let followPlayback: Bool
    var fontScale = YouTubeTranscriptSettings.fontScaleDefault
    var showsTimestamps = YouTubeTranscriptSettings.showsTimestampsDefault
    @ScaledMetric(relativeTo: .body) private var fontSize = 18.0

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(context.coordinator, name: "transcript")
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.isOpaque = false
        view.backgroundColor = .clear
        view.loadHTMLString(Self.html(cues: model.cues, title: model.title, showsTimestamps: showsTimestamps), baseURL: nil)
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.activeCueID = activeCueID
        context.coordinator.followPlayback = followPlayback
        context.coordinator.fontSize = fontSize * fontScale
        context.coordinator.title = model.title
        context.coordinator.showsTimestamps = showsTimestamps
        context.coordinator.update(view)
    }

    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        coordinator.updateTask?.cancel()
        coordinator.seekTask?.cancel()
        view.configuration.userContentController.removeScriptMessageHandler(forName: "transcript")
        view.navigationDelegate = nil
    }

    static func html(cues: [YouTubeTranscriptCue], title: String = "", showsTimestamps: Bool = false) -> String {
        let scanningScript = Bundle.framework.url(forResource: "textScanning", withExtension: "js")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        let rows = cues.map { cue in
            "<article id='cue-\(cue.id)'><button data-seek='\(cue.id)'>\(cue.timestamp)</button><span data-lookup data-cue='\(cue.id)' tabindex='0' role='button'>\(escape(cue.text))</span></article>"
        }.joined()
        return """
        <!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="color-scheme" content="light dark">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'">
        <style>
        :root { color-scheme: light dark; font: -apple-system-body; }
        body { margin: 0; padding: 8px 16px 30px; overflow-wrap: anywhere; }
        h1 { font-size: 1.25em; line-height: 1.5; margin: 8px 12px 16px; }
        body:not(.timestamps) button[data-seek] { display: none; }
        article { padding: 12px; border-radius: 12px; margin-bottom: 4px; line-height: 1.8; }
        article.active { background: light-dark(#e8efff, #26344f); box-shadow: inset 3px 0 #5078ce; }
        button { display: block; border: 0; background: transparent; color: light-dark(#355a9e,#a9c5ff);
          font: inherit; font-size: .8em; font-variant-numeric: tabular-nums; min-height: 44px; min-width: 44px; padding: 0 8px; }
        span { display: block; }
        span:focus-visible, button:focus-visible { outline: 2px solid #5078ce; }
        </style></head><body class="\(showsTimestamps ? "timestamps" : "")">
        <h1 id="video-title" \(title.isEmpty ? "hidden" : "")><span data-lookup data-title tabindex="0" role="button">\(escape(title))</span></h1>\(rows)
        <script>
        \(scanningScript)
        const post = body => window.webkit.messageHandlers.transcript.postMessage(body);
        const lookup = (span, offset, rect) => post({kind:'lookup', target:span.hasAttribute('data-title') ? 'title' : 'cue', id:span.hasAttribute('data-cue') ? Number(span.dataset.cue) : null,
            offset, x:rect.x, y:rect.y, width:rect.width, height:rect.height});
        document.addEventListener('touchmove', () => post({kind:'scroll'}), {passive:true});
        document.addEventListener('wheel', () => post({kind:'scroll'}), {passive:true});
        document.addEventListener('click', event => {
            const button = event.target.closest('button[data-seek]');
            if (button) { post({kind:'seek', id:Number(button.dataset.seek)}); return; }
            const span = event.target.closest('span[data-lookup]');
            if (!span || !window.getSelection().isCollapsed) return;
            if (event.detail === 0) {
                lookup(span, 0, span.getBoundingClientRect()); return;
            }
            const scanner = window.MaruReader.textScanning;
            const hit = scanner.findCharacterAtPoint(event.clientX, event.clientY);
            if (!hit || !span.contains(hit.node)) return;
            const prefix = document.createRange();
            prefix.selectNodeContents(span);
            prefix.setEnd(hit.node, hit.offset);
            const geometry = scanner.getCharacterGeometry(hit.node, hit.offset, event.clientX, event.clientY);
            if (geometry) lookup(span, prefix.toString().length, geometry.rect);
        });
        document.addEventListener('keydown', event => {
            const span = event.target.closest('span[data-lookup]');
            if (span && (event.key === 'Enter' || event.key === ' ')) {
                event.preventDefault(); lookup(span, 0, span.getBoundingClientRect());
            }
        });
        window.updatePlayback = (id, follow, fontSize, showsTimestamps, title) => {
            const heading = document.getElementById('video-title');
            const titleSpan = heading.querySelector('span');
            const layoutChanged = document.documentElement.style.fontSize !== fontSize + 'px'
                || document.body.classList.contains('timestamps') !== showsTimestamps || titleSpan.textContent !== title;
            // Anchor a visible character through reflow, rather than keeping a stale pixel offset.
            let anchor, anchorTop;
            if (layoutChanged && !follow) {
                const text = Array.from(document.querySelectorAll('[data-lookup]')).find(span => {
                    const rect = span.getBoundingClientRect();
                    return rect.bottom > 0 && rect.top < innerHeight && rect.height > 0;
                });
                if (text) {
                    const rect = text.getBoundingClientRect();
                    anchor = document.caretRangeFromPoint((rect.left + rect.right) / 2,
                        Math.min(rect.bottom - 1, Math.max(0, rect.top) + 10));
                    if (!anchor || !text.contains(anchor.startContainer)) {
                        anchor = document.createRange();
                        anchor.selectNodeContents(text);
                        anchor.collapse(true);
                    }
                }
                if (anchor) {
                    if (anchor.startContainer.nodeType === Node.TEXT_NODE && anchor.startOffset < anchor.startContainer.length)
                        anchor.setEnd(anchor.startContainer, anchor.startOffset + 1);
                    anchorTop = anchor.getBoundingClientRect().top;
                }
            }
            document.documentElement.style.fontSize = fontSize + 'px';
            document.body.classList.toggle('timestamps', showsTimestamps);
            if (titleSpan.textContent !== title) titleSpan.textContent = title;
            heading.hidden = !title;
            if (anchor && anchor.startContainer.isConnected)
                window.scrollBy(0, anchor.getBoundingClientRect().top - anchorTop);
            const previous = document.querySelector('.active');
            const current = document.getElementById('cue-' + id);
            if (previous !== current) {
                previous?.classList.remove('active'); current?.classList.add('active');
            }
            if (follow && current) current.scrollIntoView({block:'center',behavior:'instant'});
        };
        </script></body></html>
        """
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let model: YouTubeTranscriptViewModel
        var fontSize = 18.0
        var title = ""
        var showsTimestamps = false
        var activeCueID: Int?
        var followPlayback = true
        var updateTask: Task<Void, Never>?
        var seekTask: Task<Void, Never>?
        private var ready = false
        private var lastID: Int?
        private var lastFollow = false
        private var lastFontSize = 0.0
        private var lastTitle: String?
        private var lastShowsTimestamps: Bool?

        init(model: YouTubeTranscriptViewModel) {
            self.model = model
        }

        func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
            ready = true
            update(webView)
        }

        func update(_ view: WKWebView) {
            guard ready else { return }
            let id = activeCueID
            let follow = followPlayback
            guard id != lastID || follow != lastFollow || fontSize != lastFontSize
                || title != lastTitle || showsTimestamps != lastShowsTimestamps else { return }
            lastID = id
            lastFollow = follow
            lastFontSize = fontSize
            lastTitle = title
            lastShowsTimestamps = showsTimestamps
            let fontSize = fontSize
            let title = title
            let showsTimestamps = showsTimestamps
            updateTask?.cancel()
            updateTask = Task {
                _ = try? await view.callAsyncJavaScript(
                    "window.updatePlayback(id, follow, fontSize, showsTimestamps, title)",
                    arguments: ["id": id ?? -1, "follow": follow, "fontSize": fontSize, "showsTimestamps": showsTimestamps, "title": title],
                    in: nil, contentWorld: .page
                )
            }
        }

        func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame, let body = message.body as? [String: Any], let kind = body["kind"] as? String else { return }
            if kind == "scroll" {
                model.followPlayback = false; return
            }
            if kind == "lookup", let offset = body["offset"] as? Int {
                let target: YouTubeTranscriptLookupTarget
                if body["target"] as? String == "title" {
                    target = .title
                } else if let id = body["id"] as? Int {
                    target = .cue(id)
                } else {
                    return
                }
                let anchor = CGRect(x: body["x"] as? Double ?? 0, y: body["y"] as? Double ?? 0,
                                    width: body["width"] as? Double ?? 0, height: body["height"] as? Double ?? 0)
                model.select(target: target, offset: offset, anchor: anchor)
            } else if kind == "seek", let id = body["id"] as? Int {
                seekTask?.cancel()
                seekTask = Task { await model.seek(to: id) }
            }
        }

        func webView(_: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            decisionHandler(navigationAction.request.url?.absoluteString == "about:blank" ? .allow : .cancel)
        }
    }
}
