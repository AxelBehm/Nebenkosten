//
//  Zaehlerstand.swift
//  Nebenkosten
//
//  Created by Axel Behm on 22.01.26.
//

import Foundation

struct Zaehlerstand: Identifiable, Codable {
    let id: Int64
    let wohnungId: Int64
    let zaehlerTyp: String  // z.B. "Frischwasser", "Strom", "Gas", etc.
    let zaehlerNummer: String?  // Zähler-Nummer (optional)
    let zaehlerStart: Double
    let zaehlerEnde: Double
    let differenz: Double  // Berechnet: zaehlerEnde - zaehlerStart (in cbm/kwh oder entsprechender Einheit)
    let auchAbwasser: Bool?  // Nur für Frischwasser: auch Abwasser berechnen (default: true)
    let beschreibung: String?  // Optionale Beschreibung (z. B. „Gartenwasser kein Abwasser“)
    
    init(
        id: Int64 = 0,
        wohnungId: Int64,
        zaehlerTyp: String,
        zaehlerNummer: String? = nil,
        zaehlerStart: Double,
        zaehlerEnde: Double,
        auchAbwasser: Bool? = nil,
        beschreibung: String? = nil
    ) {
        self.id = id
        self.wohnungId = wohnungId
        self.zaehlerTyp = zaehlerTyp
        self.zaehlerNummer = zaehlerNummer
        self.zaehlerStart = zaehlerStart
        self.zaehlerEnde = zaehlerEnde
        self.differenz = zaehlerEnde - zaehlerStart
        self.auchAbwasser = auchAbwasser
        self.beschreibung = beschreibung
    }
}

// MARK: - Symbol für Anzeige (passend zu Kosten-Symbolen)
extension Zaehlerstand {
    /// SF-Symbol-Name für den Zählertyp (für Listen und Picker)
    static func symbolName(for zaehlerTyp: String) -> String {
        switch zaehlerTyp {
        case "Frischwasser": return "drop.fill"
        case "Warmwasser": return "drop.fill"
        case "Strom": return "bolt.fill"
        case "Gas": return "flame.fill"
        case "Sonstiges": return "ellipsis.circle.fill"
        default: return "gauge.with.dots.needle.67percent"
        }
    }
}
