// WebCosmeticFilterUserScript.swift
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

// swiftformat:disable header
// This Source Code Form is subject to the terms of the Mozilla
// Public License, v. 2.0. If a copy of the MPL was not distributed
// with this file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import WebKit

enum WebCosmeticFilterUserScript {
    static let messageHandlerName = "maruwebCosmeticFilters"

    @MainActor
    static func makeUserScript() -> WKUserScript? {
        let contentScript = loadResource(named: "maru-content-cosmetic-ios", extension: "js")
        guard !contentScript.isEmpty else { return nil }

        let handlerName = jsonString(messageHandlerName)
        let source = """
        (() => {
          const handlerName = \(handlerName);
          const postNative = (payload) => {
            const handler = window.webkit?.messageHandlers?.[handlerName];
            if (!handler) {
              return Promise.resolve(null);
            }
            return handler.postMessage(payload);
          };

          postNative({ kind: "initial", url: window.location.href }).then((model) => {
            if (!model || model.enabled !== true) {
              return;
            }

            const args = {
              hideFirstPartyContent: true,
              genericHide: model.genericHide === true,
              firstSelectorsPollingDelayMs: null,
              switchToSelectorsPollingThreshold: 1000,
              fetchNewClassIdRulesThrottlingMs: 100,
              aggressiveSelectors: [],
              standardSelectors: model.hideSelectors || []
            };
            const proceduralFilters = (model.proceduralActions || []).flatMap((filter) => {
              try {
                return [JSON.parse(filter)];
              } catch (_) {
                return [];
              }
            });
            const messageHandler = handlerName;
            const partinessMessageHandler = handlerName;
            const SECURITY_TOKEN = "maruweb";
            const $ = (fn) => fn;
            $.postNativeMessage = (_handler, payload) => {
              if (payload?.data?.ids || payload?.data?.classes) {
                return postNative({
                  kind: "selectors",
                  ids: payload.data.ids || [],
                  classes: payload.data.classes || [],
                  exceptions: model.exceptions || []
                }).then((result) => ({
                  standardSelectors: result?.selectors || [],
                  aggressiveSelectors: []
                }));
              }
              return Promise.resolve({});
            };

            if (model.injectedScript) {
              try {
                const scriptletGlobals = (() => {
                  const forwardedMapMethods = ["has", "get", "set"];
                  const handler = {
                    get(target, prop) {
                      if (forwardedMapMethods.includes(prop)) {
                        return Map.prototype[prop].bind(target);
                      }
                      return target.get(prop);
                    },
                    set(target, prop, value) {
                      if (!forwardedMapMethods.includes(prop)) {
                        target.set(prop, value);
                      }
                    }
                  };
                  return new Proxy(new Map(), handler);
                })();
                const deAmpEnabled = false;
                eval(model.injectedScript);
              } catch (_) {}
            }

            \(contentScript)
          }).catch(() => {});
        })();
        """

        return WKUserScript(
            source: source,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false,
            in: .page
        )
    }

    private static func loadResource(named name: String, extension fileExtension: String) -> String {
        guard let url = Bundle(for: WebCosmeticFilterUserScriptBundleMarker.self).url(
            forResource: name,
            withExtension: fileExtension
        ) else {
            return ""
        }
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    private static func jsonString(_ string: String) -> String {
        let data = (try? JSONEncoder().encode(string)) ?? Data("\"\(string)\"".utf8)
        return String(decoding: data, as: UTF8.self)
    }
}

private final class WebCosmeticFilterUserScriptBundleMarker {}
