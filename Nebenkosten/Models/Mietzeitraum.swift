//
//  Mietzeitraum.swift
//  Nebenkosten
//
//  Created by Axel Behm on 22.01.26.
//

import Foundation

/// Option für das Mietende: offen (läuft weiter) oder gekündigt zum Mietzeitende
enum MietendeOption: String, Codable, CaseIterable {
    /// Mietende offen – Mieter wird beim Jahreswechsel ins neue Jahr übernommen
    case mietendeOffen = "mietendeOffen"
    /// Gekündigt zum Mietzeitende – Mieter wird beim Jahreswechsel nicht übernommen
    case gekuendigtZumMietzeitende = "gekuendigtZumMietzeitende"
    
    var anzeigeText: String {
        switch self {
        case .mietendeOffen: return "Mietende offen"
        case .gekuendigtZumMietzeitende: return "Gekündigt zum Mietzeitende"
        }
    }
}

/// Ein Mietzeitraum = ein Hauptmieter für einen Zeitraum. Bei Hauptmieter-Wechsel neuen Satz anlegen.
struct Mietzeitraum: Identifiable, Codable, Equatable {
    let id: Int64
    let wohnungId: Int64
    /// Jahr des Mietzeitraums
    let jahr: Int
    /// Name des Hauptmieters
    let hauptmieterName: String
    /// Start des Mietzeitraums (ISO YYYY-MM-DD)
    let vonDatum: String
    /// Ende des Mietzeitraums (ISO YYYY-MM-DD)
    let bisDatum: String
    /// Anzahl der Personen im Mietzeitraum (Pflichtfeld) – Dezimal erlaubt, z. B. 2,3
    let anzahlPersonen: Double
    /// Beschreibung der Personenzusammensetzung (Pflicht bei Dezimalwerten, z. B. „1 Bewohner, 1 Kind Wechselmodell“)
    let personenBeschreibung: String?
    /// Mietende-Status: offen oder gekündigt zum Mietzeitende
    let mietendeOption: MietendeOption
    
    init(id: Int64 = 0, wohnungId: Int64, jahr: Int, hauptmieterName: String, vonDatum: String, bisDatum: String, anzahlPersonen: Double, personenBeschreibung: String? = nil, mietendeOption: MietendeOption = .mietendeOffen) {
        self.id = id
        self.wohnungId = wohnungId
        self.jahr = jahr
        self.hauptmieterName = hauptmieterName
        self.vonDatum = vonDatum
        self.bisDatum = bisDatum
        self.anzahlPersonen = anzahlPersonen
        self.personenBeschreibung = personenBeschreibung
        self.mietendeOption = mietendeOption
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int64.self, forKey: .id)
        wohnungId = try c.decode(Int64.self, forKey: .wohnungId)
        jahr = try c.decode(Int.self, forKey: .jahr)
        hauptmieterName = try c.decode(String.self, forKey: .hauptmieterName)
        vonDatum = try c.decode(String.self, forKey: .vonDatum)
        bisDatum = try c.decode(String.self, forKey: .bisDatum)
        if let d = try c.decodeIfPresent(Double.self, forKey: .anzahlPersonen) {
            anzahlPersonen = d
        } else if let i = try c.decodeIfPresent(Int.self, forKey: .anzahlPersonen) {
            anzahlPersonen = Double(i)
        } else {
            anzahlPersonen = 1.0
        }
        personenBeschreibung = try c.decodeIfPresent(String.self, forKey: .personenBeschreibung)
        mietendeOption = (try c.decodeIfPresent(MietendeOption.self, forKey: .mietendeOption)) ?? .mietendeOffen
    }
}

