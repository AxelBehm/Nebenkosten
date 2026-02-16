//
//  ZaehlerstandFoto.swift
//  Nebenkosten
//
//  Created by Axel Behm on 31.01.26.
//

import Foundation

/// Ein Foto (z. B. Zählerfoto), das einem Zählerstand zugeordnet ist.
struct ZaehlerstandFoto: Identifiable {
    let id: Int64
    let zaehlerstandId: Int64
    let imagePath: String
    let sortOrder: Int
    let bildbezeichnung: String
}
