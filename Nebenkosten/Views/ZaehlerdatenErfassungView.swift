//
//  ZaehlerdatenErfassungView.swift
//  Nebenkosten
//
//  Zähler-Daten Erfassung pro Wohnung im Jahr – alle Mieter sortiert nach Wohnungen.
//

import SwiftUI

private let isoDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "de_DE")
    f.timeZone = TimeZone(identifier: "Europe/Berlin")
    return f
}()

private let deDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "dd.MM.yyyy"
    f.locale = Locale(identifier: "de_DE")
    f.timeZone = TimeZone(identifier: "Europe/Berlin")
    return f
}()

private func isoToDeDatum(_ s: String) -> String? {
    guard let d = isoDateFormatter.date(from: s) else { return nil }
    return deDateFormatter.string(from: d)
}

struct ZaehlerdatenErfassungView: View {
    let abrechnung: HausAbrechnung
    @State private var wohnungen: [Wohnung] = []
    
    var body: some View {
        Group {
            if wohnungen.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "gauge.with.dots.needle.67percent")
                        .font(.system(size: 50))
                        .foregroundStyle(Color.appBlue)
                    Text("Keine Wohnungen")
                        .font(.headline)
                    Text("Fügen Sie zuerst Wohnungen unter „Whng.“ hinzu.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(wohnungen) { w in
                        NavigationLink(destination: ZaehlerstaendeView(wohnung: w, haus: abrechnung)) {
                            ZaehlerdatenWohnungRow(wohnung: w, abrechnung: abrechnung)
                        }
                    }
                }
            }
        }
        .navigationTitle("Zählerdaten \(abrechnung.abrechnungsJahr)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadWohnungen()
        }
    }
    
    private func loadWohnungen() {
        wohnungen = DatabaseManager.shared.getWohnungen(byHausAbrechnungId: abrechnung.id)
    }
}

/// Zeile für eine Wohnung mit Mieter-Liste (sortiert nach Wohnungen)
private struct ZaehlerdatenWohnungRow: View {
    let wohnung: Wohnung
    let abrechnung: HausAbrechnung
    
    private var mietzeitraeume: [Mietzeitraum] {
        DatabaseManager.shared.getMietzeitraeume(byWohnungId: wohnung.id)
            .filter { $0.jahr == abrechnung.abrechnungsJahr }
            .sorted { $0.vonDatum < $1.vonDatum }
    }
    
    private var zaehlerstaendeCount: Int {
        DatabaseManager.shared.getZaehlerstaende(byWohnungId: wohnung.id).count
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "door.left.hand.open")
                .font(.title2)
                .foregroundStyle(Color.appBlue)
                .frame(width: 28, alignment: .center)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    if let nummer = wohnung.wohnungsnummer, !nummer.isEmpty {
                        Text("Nr. \(nummer)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                    }
                    Text(wohnung.bezeichnung)
                        .font(.headline)
                    Spacer()
                    if zaehlerstaendeCount > 0 {
                        Text("\(zaehlerstaendeCount) Zähler")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 6) {
                    Text("\(wohnung.qm) m²")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if !mietzeitraeume.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(mietzeitraeume) { m in
                            VStack(alignment: .leading, spacing: 1) {
                                Text(m.hauptmieterName)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                HStack(spacing: 4) {
                                    if let von = isoToDeDatum(m.vonDatum), let bis = isoToDeDatum(m.bisDatum) {
                                        Text("(\(von)–\(bis)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text("· \(m.anzahlPersonen) Pers.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } else {
                    Text("Kein Mieter im Jahr \(abrechnung.abrechnungsJahr)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
