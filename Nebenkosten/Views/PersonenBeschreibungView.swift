//
//  PersonenBeschreibungView.swift
//  Nebenkosten
//
//  Beschreibungsfeld mit Vorschlägen aus PersonUnits (editierbar).
//

import SwiftUI

/// TextField für Personen-Beschreibung mit tippbaren Vorschlägen aus den PersonUnits.
/// Der eingetragene Text bleibt editierbar.
struct PersonenBeschreibungMitVorschlaegenView: View {
    @Binding var text: String
    var placeholder: String = "z. B. 1 Bewohner, 1 Kind Wechselmodell"
    
    private func vorschlagTippen(_ label: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            text = label
        } else {
            text = trimmed + ", " + label
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vorschläge:")
                .font(.caption)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PersonUnits.all) { unit in
                        Button {
                            vorschlagTippen(unit.label)
                        } label: {
                            Text(unit.label)
                                .font(.caption)
                                .lineLimit(1)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray6))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(2...4)
        }
    }
}
