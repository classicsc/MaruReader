//
//  DictionaryPopupView.swift
//  MaruReader
//
//  Created by Sam Smoker on 10/3/25.
//

import SwiftUI
import WebKit

struct DictionaryPopupView: View {
    @State var page: WebPage

    var body: some View {
        ZStack {
            WebView(page)
            if page.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator), lineWidth: 1)
        )
        .cornerRadius(12)
        .shadow(radius: 10)
    }
}
