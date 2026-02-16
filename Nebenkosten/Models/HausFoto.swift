//
//  HausFoto.swift
//  Nebenkosten
//
//  Created by Axel Behm on 27.01.26.
//

import Foundation

/// Ein Foto, das einem Haus (über hausBezeichnung) zugeordnet ist – unabhängig vom Abrechnungsjahr.
struct HausFoto: Identifiable {
    let id: Int64
    /// Haus-Bezeichnung (Straße/Hausnummer) – alle Jahre desselben Hauses teilen dieselben Fotos
    let hausBezeichnung: String
    /// Relativer Pfad zur Bilddatei (z. B. unter Documents/HausFotos/…)
    let imagePath: String
    /// Sortierreihenfolge (0, 1, 2, …)
    let sortOrder: Int
    /// Optionale Bezeichnung/Beschreibung des Bildes
    let bildbezeichnung: String
}
