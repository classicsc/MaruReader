// WebDataManagementView.swift
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

import SwiftUI
import WebKit

public struct WebDataManagementView: View {
    @State private var clearCookiesAndSiteData = true
    @State private var clearCache = true
    @State private var selectedTimeRange: TimeRange = .allTime
    @State private var showingConfirmation = false
    @State private var isClearing = false

    public init() {}

    public var body: some View {
        Form {
            Section("Time Range") {
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases) { range in
                        Text(range.label).tag(range)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            Section(
                header: Text("Data to Clear"),
                footer: Text("Cookies and site data includes cookies, local storage, and databases.")
            ) {
                Toggle("Cookies & Site Data", isOn: $clearCookiesAndSiteData)
                Toggle("Cache", isOn: $clearCache)
            }
            Section {
                Button(role: .destructive) {
                    showingConfirmation = true
                } label: {
                    HStack {
                        Text("Clear Web Data")
                        if isClearing {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(!clearCookiesAndSiteData && !clearCache || isClearing)
                .confirmationDialog(
                    "Clear Web Data",
                    isPresented: $showingConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Clear", role: .destructive) {
                        Task { await clearData() }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text(confirmationMessage)
                }
            }
        }
        .navigationTitle("Website Data")
    }

    var confirmationMessage: String {
        WebDataManagementCopy.confirmationMessage(
            clearCookiesAndSiteData: clearCookiesAndSiteData,
            clearCache: clearCache,
            timeRange: selectedTimeRange
        )
    }

    private func clearData() async {
        isClearing = true
        defer { isClearing = false }

        var dataTypes: Set<String> = []
        if clearCookiesAndSiteData {
            dataTypes.formUnion([
                WKWebsiteDataTypeCookies,
                WKWebsiteDataTypeLocalStorage,
                WKWebsiteDataTypeSessionStorage,
                WKWebsiteDataTypeIndexedDBDatabases,
                WKWebsiteDataTypeWebSQLDatabases,
            ])
        }
        if clearCache {
            dataTypes.formUnion([
                WKWebsiteDataTypeDiskCache,
                WKWebsiteDataTypeMemoryCache,
                WKWebsiteDataTypeOfflineWebApplicationCache,
            ])
        }

        await WebsiteDataStore.main.removeData(
            ofTypes: dataTypes,
            modifiedSince: selectedTimeRange.sinceDate
        )
    }
}

enum TimeRange: String, CaseIterable, Identifiable {
    case pastHour
    case pastDay
    case allTime

    var id: String {
        rawValue
    }

    var label: String {
        localizedLabel()
    }

    func localizedLabel(locale: Locale = .current) -> String {
        switch self {
        case .pastHour:
            WebLocalization.string("Past Hour", locale: locale, comment: "Option label for clearing website data from the past hour.")
        case .pastDay:
            WebLocalization.string("Past Day", locale: locale, comment: "Option label for clearing website data from the past day.")
        case .allTime:
            WebLocalization.string("All Time", locale: locale, comment: "Option label for clearing website data from all time.")
        }
    }

    var sinceDate: Date {
        switch self {
        case .pastHour: Date.now.addingTimeInterval(-3600)
        case .pastDay: Date.now.addingTimeInterval(-86400)
        case .allTime: Date.distantPast
        }
    }
}

enum WebDataManagementCopy {
    private static let dataTypesToken = "__DATA_TYPES__"

    static func confirmationMessage(
        clearCookiesAndSiteData: Bool,
        clearCache: Bool,
        timeRange: TimeRange,
        locale: Locale = .current
    ) -> String {
        var types: [String] = []
        if clearCookiesAndSiteData {
            types.append(
                WebLocalization.string(
                    "cookies & site data",
                    locale: locale,
                    comment: "Lowercase noun phrase used inside the website-data clearing confirmation message."
                )
            )
        }
        if clearCache {
            types.append(
                WebLocalization.string(
                    "cache",
                    locale: locale,
                    comment: "Lowercase noun used inside the website-data clearing confirmation message."
                )
            )
        }

        let joined = types.formatted(.list(type: .and).locale(locale))
        let template = switch timeRange {
        case .pastHour:
            WebLocalization.string(
                "web.data.clear.confirmation.pastHour",
                defaultValue: "This will clear \(dataTypesToken) from the past hour. This action cannot be undone.",
                locale: locale,
                comment: "Confirmation shown before clearing website data from the past hour. The argument lists the selected data types."
            )
        case .pastDay:
            WebLocalization.string(
                "web.data.clear.confirmation.pastDay",
                defaultValue: "This will clear \(dataTypesToken) from the past day. This action cannot be undone.",
                locale: locale,
                comment: "Confirmation shown before clearing website data from the past day. The argument lists the selected data types."
            )
        case .allTime:
            WebLocalization.string(
                "web.data.clear.confirmation.allTime",
                defaultValue: "This will clear \(dataTypesToken) for all time. This action cannot be undone.",
                locale: locale,
                comment: "Confirmation shown before clearing website data for all time. The argument lists the selected data types."
            )
        }

        return template.replacingOccurrences(of: dataTypesToken, with: joined)
    }
}

#Preview {
    NavigationStack {
        WebDataManagementView()
    }
}
