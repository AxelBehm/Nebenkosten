//
//  Kosten.swift
//  Nebenkosten
//
//  Created by Axel Behm on 22.01.26.
//

import Foundation

enum Kostenart: String, Codable, CaseIterable {
    case abfall = "Abfall"
    case frischwasser = "Frischwasser"
    case warmwasser = "Warmwasser"
    case abwasser = "Abwasser"
    case strom = "Strom"
    case hausstrom = "Hausstrom"
    case gas = "Gas"
    case sachHaftpflichtVersicherung = "Sach/Haftpflicht-Versicherung"
    case grundsteuer = "Grundsteuer"
    case strassenreinigung = "Strassenreinigung"
    case niederschlagswasser = "Niederschlagswasser"
    case kabel = "Kabel"
    case schornsteinfeger = "Schornsteinfeger"
    case heizungswartung = "Heizungswartung"
    case vorauszahlung = "Vorauszahlung"
    case sonstiges = "Sonstiges"
    
    /// SF Symbol für die Kostenart (für Listen und Picker)
    var symbolName: String {
        switch self {
        case .frischwasser: return "drop.fill"
        case .warmwasser: return "drop.fill"
        case .abwasser: return "drop.triangle.fill"
        case .sachHaftpflichtVersicherung: return "shield.fill"
        case .grundsteuer: return "building.2.fill"
        case .strassenreinigung: return "map.fill"
        case .niederschlagswasser: return "cloud.rain.fill"
        case .strom: return "bolt.fill"
        case .hausstrom: return "bolt.circle.fill"
        case .kabel: return "tv.fill"
        case .schornsteinfeger: return "house.and.flag.fill"
        case .heizungswartung: return "thermometer"
        case .gas: return "flame.fill"
        case .abfall: return "trash.fill"
        case .sonstiges: return "ellipsis.circle.fill"
        case .vorauszahlung: return "banknote.fill"
        }
    }
}

enum Verteilungsart: String, Codable, CaseIterable {
    case nachQm = "nach Qm"
    case nachVerbrauch = "nach Verbrauch"
    case nachPersonen = "nach Personen"
    case nachWohneinheiten = "nach Wohneinheiten"
    case nachEinzelnachweis = "nach Einzelnachweis"
}

struct Kosten: Identifiable, Codable {
    let id: Int64
    let hausAbrechnungId: Int64
    let kostenart: Kostenart
    let betrag: Double
    let bezeichnung: String?  // Optional für zusätzliche Beschreibung, besonders bei "Sonstiges"
    let verteilungsart: Verteilungsart
    
    init(
        id: Int64 = 0,
        hausAbrechnungId: Int64,
        kostenart: Kostenart,
        betrag: Double,
        bezeichnung: String? = nil,
        verteilungsart: Verteilungsart = .nachQm
    ) {
        self.id = id
        self.hausAbrechnungId = hausAbrechnungId
        self.kostenart = kostenart
        self.betrag = betrag
        self.bezeichnung = bezeichnung
        self.verteilungsart = verteilungsart
    }
}
