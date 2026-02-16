//
//  PurchaseManager.swift
//  Nebenkosten
//
//  Created by Axel Behm on 28.01.26.
//

import Foundation
import StoreKit
import Combine

class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()
    
    @Published var isPremium: Bool = false
    @Published var isLoading: Bool = false
    
    // Product ID - muss in App Store Connect konfiguriert werden
    private let premiumProductID = "com.christinebehm.Nebenkosten.Premium"
    
    private init() {
        #if DEBUG
        // Debug (Xcode): Premium standardmäßig auf false, kann manuell über Developer-Bereich aktiviert werden
        isPremium = false
        #else
        // Release + TestFlight: Kaufstatus prüfen – nach Kauf wird Vollversion aktiv
        Task { @MainActor in
            await checkPurchaseStatus()
        }
        #endif
    }
    
    // Prüft ob Premium bereits gekauft wurde
    @MainActor
    func checkPurchaseStatus() async {
        isLoading = true
        defer { isLoading = false }
        
        // Prüfe ob Produkt bereits gekauft wurde
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == premiumProductID {
                    isPremium = true
                    return
                }
            }
        }
        
        isPremium = false
    }
    
    // Kaufe Premium-Version
    func purchasePremium() async throws {
        isLoading = true
        defer { isLoading = false }
        
        let products: [Product]
        do {
            products = try await Product.products(for: [premiumProductID])
        } catch {
            throw PurchaseError.productNotFound(
                productID: premiumProductID,
                bundleID: Bundle.main.bundleIdentifier ?? "?",
                receivedCount: 0,
                storeKitError: error.localizedDescription
            )
        }
        guard let product = products.first else {
            #if DEBUG
            // Debug: StoreKit-Config nicht aktiv? Premium trotzdem aktivieren zum Testen
            isPremium = true
            return
            #else
            throw PurchaseError.productNotFound(
                productID: premiumProductID,
                bundleID: Bundle.main.bundleIdentifier ?? "?",
                receivedCount: products.count,
                storeKitError: nil
            )
            #endif
        }
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            if case .verified(let transaction) = verification {
                isPremium = true
                await transaction.finish()
            } else {
                throw PurchaseError.verificationFailed
            }
        case .userCancelled:
            throw PurchaseError.userCancelled
        case .pending:
            throw PurchaseError.pending
        @unknown default:
            throw PurchaseError.unknown
        }
    }
    
    /// Stellt Premium wieder her (für Gerätewechsel). Gibt true zurück, wenn ein Kauf gefunden wurde.
    @discardableResult
    func restorePurchases() async throws -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        try await AppStore.sync()
        await checkPurchaseStatus()
        return isPremium
    }
}

enum PurchaseError: LocalizedError {
    case productNotFound(productID: String, bundleID: String, receivedCount: Int, storeKitError: String?)
    case verificationFailed
    case userCancelled
    case pending
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .productNotFound(let id, let bundleId, let count, let skError):
            var msg = "Produkt nicht gefunden.\n\n"
            msg += "Gesucht: \(id)\n"
            msg += "App-Bundle: \(bundleId)\n"
            msg += "Gefunden: \(count) Produkt(e)\n"
            if let err = skError, !err.isEmpty {
                msg += "StoreKit: \(err)\n\n"
            }
            msg += "App Store Connect prüfen:\n"
            msg += "• In-App-Kauf mit ID \"\(id)\" angelegt?\n"
            msg += "• Status „Bereit zum Senden“?\n"
            msg += "• IAP zur App-Version hinzugefügt?\n"
            msg += "• Paid-Apps-Vereinbarung akzeptiert?"
            return msg
        case .verificationFailed:
            return "Kauf konnte nicht verifiziert werden."
        case .userCancelled:
            return "Kauf abgebrochen."
        case .pending:
            return "Kauf wird bearbeitet. Bitte warten Sie."
        case .unknown:
            return "Unbekannter Fehler."
        }
    }
}
