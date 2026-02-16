//
//  EinzelnachweisWohnung.swift
//  Nebenkosten
//
//  Created by Axel Behm on 22.01.26.
//

import Foundation

struct EinzelnachweisWohnung: Identifiable, Codable {
    let id: Int64
    let kostenId: Int64
    let wohnungId: Int64
    let von: String?
    let betrag: Double?
    
    init(
        id: Int64 = 0,
        kostenId: Int64,
        wohnungId: Int64,
        von: String? = nil,
        betrag: Double? = nil
    ) {
        self.id = id
        self.kostenId = kostenId
        self.wohnungId = wohnungId
        self.von = von
        self.betrag = betrag
    }
}
