//
//  KostenFoto.swift
//  Nebenkosten
//
//  Created by Axel Behm on 27.01.26.
//

import Foundation

/// Ein Foto/Anhang (z. B. Rechnung), das einer Kostenposition zugeordnet ist (z. B. Gemeinde-/Kreis-Rechnungen).
struct KostenFoto: Identifiable {
    let id: Int64
    let kostenId: Int64
    let imagePath: String
    let sortOrder: Int
    let bildbezeichnung: String
}
