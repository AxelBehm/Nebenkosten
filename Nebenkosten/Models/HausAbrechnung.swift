//
//  HausAbrechnung.swift
//  Nebenkosten
//
//  Created by Axel Behm on 22.01.26.
//

import Foundation

enum Leerstandspruefung: String, Codable, CaseIterable {
    case ja = "Ja (Leerstandszeiten an Vermieter)"
    case nein = "Nein (alle Kosten tragen die Mieter)"
}

struct HausAbrechnung: Identifiable, Codable, Hashable {
    let id: Int64
    let hausBezeichnung: String
    let abrechnungsJahr: Int
    let postleitzahl: String?
    let ort: String?
    let gesamtflaeche: Int?
    let anzahlWohnungen: Int?
    let leerstandspruefung: Leerstandspruefung?
    let verwalterName: String?
    let verwalterStrasse: String?
    let verwalterPLZOrt: String?
    let verwalterEmail: String?
    let verwalterTelefon: String?
    let verwalterInEmailVorbelegen: Bool?
    
    init(
        id: Int64 = 0,
        hausBezeichnung: String,
        abrechnungsJahr: Int,
        postleitzahl: String? = nil,
        ort: String? = nil,
        gesamtflaeche: Int? = nil,
        anzahlWohnungen: Int? = nil,
        leerstandspruefung: Leerstandspruefung? = nil,
        verwalterName: String? = nil,
        verwalterStrasse: String? = nil,
        verwalterPLZOrt: String? = nil,
        verwalterEmail: String? = nil,
        verwalterTelefon: String? = nil,
        verwalterInEmailVorbelegen: Bool? = nil
    ) {
        self.id = id
        self.hausBezeichnung = hausBezeichnung
        self.abrechnungsJahr = abrechnungsJahr
        self.postleitzahl = postleitzahl
        self.ort = ort
        self.gesamtflaeche = gesamtflaeche
        self.anzahlWohnungen = anzahlWohnungen
        self.leerstandspruefung = leerstandspruefung
        self.verwalterName = verwalterName
        self.verwalterStrasse = verwalterStrasse
        self.verwalterPLZOrt = verwalterPLZOrt
        self.verwalterEmail = verwalterEmail
        self.verwalterTelefon = verwalterTelefon
        self.verwalterInEmailVorbelegen = verwalterInEmailVorbelegen
    }
}
