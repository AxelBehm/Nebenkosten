//
//  Mitmieter.swift
//  Nebenkosten
//
//  Created by Axel Behm on 22.01.26.
//

import Foundation

/// Mitmieter in Teil-Zeiträumen innerhalb eines Mietzeitraums (Hauptmieter).
struct Mitmieter: Identifiable, Codable {
    let id: Int64
    let mietzeitraumId: Int64
    let name: String
    /// Start des Teilzeitraums (ISO YYYY-MM-DD)
    let vonDatum: String
    /// Ende des Teilzeitraums (ISO YYYY-MM-DD)
    let bisDatum: String
    
    init(id: Int64 = 0, mietzeitraumId: Int64, name: String, vonDatum: String, bisDatum: String) {
        self.id = id
        self.mietzeitraumId = mietzeitraumId
        self.name = name
        self.vonDatum = vonDatum
        self.bisDatum = bisDatum
    }
}
