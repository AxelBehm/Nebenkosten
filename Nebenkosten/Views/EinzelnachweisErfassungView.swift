//
//  EinzelnachweisErfassungView.swift
//  Nebenkosten
//
//  Created by Axel Behm on 22.01.26.
//

import SwiftUI

struct EinzelnachweisErfassungView: View {
    let abrechnung: HausAbrechnung
    @Environment(\.dismiss) private var dismiss
    
    @State private var wohnungen: [Wohnung] = []
    @State private var kosten: [Kosten] = []
    @State private var einzelnachweisWerte: [String: EinzelnachweisWohnung] = [:] // "kostenId-wohnungId" -> EinzelnachweisWohnung
    @State private var istGesperrt: Bool = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Erfassen Sie für jede Wohnung die Einzelnachweis-Kostenpositionen.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                ForEach(wohnungen) { wohnung in
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            if let nummer = wohnung.wohnungsnummer, !nummer.isEmpty {
                                Text("Wohnung Nr. \(nummer)")
                                    .font(.headline)
                            }
                            Text(wohnung.bezeichnung)
                                .font(.subheadline)
                            if let name = wohnung.name {
                                Text(name)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                            }
                        }
                        
                        ForEach(einzelnachweisKosten) { kostenItem in
                            let key = "\(kostenItem.id)-\(wohnung.id)"
                            let vorhanden = einzelnachweisWerte[key]
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(kostenItem.kostenart.rawValue)
                                    .fontWeight(.medium)
                                if let bezeichnung = kostenItem.bezeichnung, !bezeichnung.isEmpty {
                                    Text(bezeichnung)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                TextField("Betrag (€)", text: Binding(
                                    get: {
                                        if let betrag = vorhanden?.betrag {
                                            return String(format: "%.2f", betrag)
                                        }
                                        return ""
                                    },
                                    set: { newValue in
                                        var betrag = Double(newValue.replacingOccurrences(of: ",", with: "."))
                                        
                                        // Bei Vorauszahlung: Wenn Wert nicht negativ ist, mit -1 multiplizieren
                                        if kostenItem.kostenart == .vorauszahlung, let b = betrag, b >= 0 {
                                            betrag = b * -1
                                        }
                                        
                                        if let vorhanden = vorhanden {
                                            einzelnachweisWerte[key] = EinzelnachweisWohnung(
                                                id: vorhanden.id,
                                                kostenId: vorhanden.kostenId,
                                                wohnungId: vorhanden.wohnungId,
                                                von: nil,
                                                betrag: betrag
                                            )
                                        } else {
                                            einzelnachweisWerte[key] = EinzelnachweisWohnung(
                                                kostenId: kostenItem.id,
                                                wohnungId: wohnung.id,
                                                von: nil,
                                                betrag: betrag
                                            )
                                        }
                                    }
                                ))
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                                .disabled(istGesperrt)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Einzelnachweis erfassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        speichereEinzelnachweise()
                        dismiss()
                    }
                    .disabled(istGesperrt)
                }
            }
            .onAppear {
                loadData()
                istGesperrt = DatabaseManager.shared.istJahrGesperrt(hausBezeichnung: abrechnung.hausBezeichnung, jahr: abrechnung.abrechnungsJahr)
            }
        }
    }
    
    private var einzelnachweisKosten: [Kosten] {
        kosten.filter { $0.verteilungsart == .nachEinzelnachweis }
    }
    
    private func loadData() {
        wohnungen = DatabaseManager.shared.getWohnungen(byHausAbrechnungId: abrechnung.id)
        kosten = DatabaseManager.shared.getKosten(byHausAbrechnungId: abrechnung.id)
        
        // Lade vorhandene Einzelnachweis-Werte
        for kostenItem in einzelnachweisKosten {
            for wohnung in wohnungen {
                if let vorhanden = DatabaseManager.shared.getEinzelnachweisWohnung(
                    kostenId: kostenItem.id,
                    wohnungId: wohnung.id
                ) {
                    let key = "\(kostenItem.id)-\(wohnung.id)"
                    // Bei Vorauszahlung: Wenn Wert nicht negativ ist, mit -1 multiplizieren
                    var betrag = vorhanden.betrag
                    if kostenItem.kostenart == .vorauszahlung, let b = betrag, b >= 0 {
                        betrag = b * -1
                    }
                    einzelnachweisWerte[key] = EinzelnachweisWohnung(
                        id: vorhanden.id,
                        kostenId: vorhanden.kostenId,
                        wohnungId: vorhanden.wohnungId,
                        von: nil,
                        betrag: betrag
                    )
                }
            }
        }
    }
    
    private func speichereEinzelnachweise() {
        for (_, wert) in einzelnachweisWerte {
            // Bei Vorauszahlung: Stelle sicher, dass der Wert negativ ist
            var finalBetrag = wert.betrag
            if let kostenItem = kosten.first(where: { $0.id == wert.kostenId }),
               kostenItem.kostenart == .vorauszahlung,
               let betrag = finalBetrag,
               betrag >= 0 {
                finalBetrag = betrag * -1
            }
            
            let finalWert = EinzelnachweisWohnung(
                id: wert.id,
                kostenId: wert.kostenId,
                wohnungId: wert.wohnungId,
                von: nil,
                betrag: finalBetrag
            )
            _ = DatabaseManager.shared.insertEinzelnachweisWohnung(finalWert)
        }
    }
}
