//
//  LimitManager.swift
//  Nebenkosten
//
//  Created by Axel Behm on 28.01.26.
//

import Foundation

class LimitManager {
    static let shared = LimitManager()
    
    /// Einheitlicher Hinweistext bei Limit (wird nur noch für PDF-Wasserzeichen-Hinweis genutzt)
    static let limitMessage = "In der kostenlosen Version können Sie maximal ein Haus/Jahr mit 2 Wohnungen verwalten. Bitte upgraden Sie zur Vollversion für unbegrenzte Häuser, Wohnungen (nur begrenzt durch Systembegrenzungen)."
    
    private init() {}
    
    // Prüft ob Premium aktiv ist
    var isPremium: Bool {
        PurchaseManager.shared.isPremium
    }
    
    // Prüft ob ein neues Haus erstellt werden kann (Limits nur noch für PDF-Wasserzeichen relevant)
    func canCreateHaus(strasse: String, ort: String?) -> (allowed: Bool, message: String?) {
        return (true, nil)
    }
    
    // Prüft ob eine neue Wohnung erstellt werden kann (Limits nur noch für PDF-Wasserzeichen relevant)
    func canCreateWohnung(hausId: Int64, wohnungsnummer: String?) -> (allowed: Bool, message: String?) {
        return (true, nil)
    }
    
    // Prüft ob Limits erreicht sind (nur noch für PDF relevant; hier immer „nicht erreicht“)
    func hasReachedLimits() -> (reached: Bool, message: String?) {
        return (false, nil)
    }
}
