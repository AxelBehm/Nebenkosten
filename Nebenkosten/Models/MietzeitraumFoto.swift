//
//  MietzeitraumFoto.swift
//  Nebenkosten
//
//  Created by Axel Behm on 27.01.26.
//

import Foundation

/// Ein Foto/Anhang (z. B. Vertrag), das einem Mietzeitraum zugeordnet ist.
struct MietzeitraumFoto: Identifiable {
    let id: Int64
    /// ID des Mietzeitraums (Hauptmieter-Zeitraum)
    let mietzeitraumId: Int64
    /// Relativer Pfad zur Bilddatei (unter Documents/MietzeitraumFotos/…)
    let imagePath: String
    /// Sortierreihenfolge (0, 1, 2, …)
    let sortOrder: Int
    /// Optionale Bezeichnung (z. B. „Mietvertrag“, „Kaution“)
    let bildbezeichnung: String
}
