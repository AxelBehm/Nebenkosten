//
//  DeveloperHelper.swift
//  Nebenkosten
//
//  Created by Axel Behm on 28.01.26.
//

import Foundation

struct DeveloperHelper {
    /// Developer-Bereich nur in Debug-Builds (Xcode direkt) sichtbar – nicht in TestFlight/App Store
    static var isDeveloperMode: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    /// TestFlight/Sandbox – für Test-Optionen wie „Premium zurücksetzen“
    static var isTestFlightOrSandbox: Bool {
        #if DEBUG
        return true
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }
    
    /// Gibt die aktuelle Build-Konfiguration zurück
    static var buildConfiguration: String {
        #if DEBUG
        return "Debug"
        #else
        if let receiptURL = Bundle.main.appStoreReceiptURL,
           receiptURL.lastPathComponent == "sandboxReceipt" {
            return "TestFlight"
        }
        return "Release"
        #endif
    }
}
