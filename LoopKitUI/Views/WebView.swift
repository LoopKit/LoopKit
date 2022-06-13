//
//  WebView.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 4/13/21.
//  Copyright © 2021 Tidepool Project. All rights reserved.
//

import SwiftUI
import WebKit

/// Opens a WKWebView on the given `url` in a new page
public struct WebView: UIViewRepresentable {
    let url: URL

    public init(url: URL) {
        self.url = url
    }
    
    public func makeUIView(context: UIViewRepresentableContext<WebView>) -> WKWebView {
        let webview = WKWebView()
        
        let request = URLRequest(url: self.url, cachePolicy: .returnCacheDataElseLoad)
        webview.load(request)
        
        return webview
    }
    
    public func updateUIView(_ webview: WKWebView, context: UIViewRepresentableContext<WebView>) {
        let request = URLRequest(url: self.url, cachePolicy: .returnCacheDataElseLoad)
        webview.load(request)
    }
}

