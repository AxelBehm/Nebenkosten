//
//  NebenkostenApp.swift
//  Nebenkosten
//
//  Created by Axel Behm on 22.01.26.
//

import SwiftUI

@main
struct NebenkostenApp: App {
    init() {
        #if os(iOS) || os(tvOS)
        // Scrollbalken kräftiger sichtbar: schwarzer Stil auf hellem Hintergrund
        UIScrollView.appearance().indicatorStyle = .black
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
