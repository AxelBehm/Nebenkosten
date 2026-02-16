//
//  Wohnung.swift
//  Nebenkosten
//
//  Created by Axel Behm on 22.01.26.
//

import Foundation

/// Eine Wohnung gehört zu einer HausAbrechnung. Anschrift wird standardmäßig aus dem Haus übernommen.
struct Wohnung: Identifiable, Codable, Hashable {
    let id: Int64
    let hausAbrechnungId: Int64
    /// Wohnungs-Nummer (z.B. "1", "2", "A", "B")
    let wohnungsnummer: String?
    /// z.B. "Wohnung 1", "1. OG links"
    let bezeichnung: String
    /// Quadratmeter der Wohnung
    let qm: Int
    /// Name (z.B. Name des Mieters/Bewohners)
    let name: String?
    /// Straße mit Hausnummer (default aus Haus)
    let strasse: String?
    /// Postleitzahl (default aus Haus)
    let plz: String?
    /// Ort (default aus Haus)
    let ort: String?
    /// E-Mail
    let email: String?
    /// Telefon
    let telefon: String?
    
    init(
        id: Int64 = 0,
        hausAbrechnungId: Int64,
        wohnungsnummer: String? = nil,
        bezeichnung: String,
        qm: Int,
        name: String? = nil,
        strasse: String? = nil,
        plz: String? = nil,
        ort: String? = nil,
        email: String? = nil,
        telefon: String? = nil
    ) {
        self.id = id
        self.hausAbrechnungId = hausAbrechnungId
        self.wohnungsnummer = wohnungsnummer
        self.bezeichnung = bezeichnung
        self.qm = qm
        self.name = name
        self.strasse = strasse
        self.plz = plz
        self.ort = ort
        self.email = email
        self.telefon = telefon
    }
}

