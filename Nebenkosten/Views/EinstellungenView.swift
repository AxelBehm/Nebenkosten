//
//  EinstellungenView.swift
//  Nebenkosten
//
//  Created by Axel Behm on 28.01.26.
//

import SwiftUI

struct EinstellungenView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showRechtliches = false
    @State private var showMusterhausAnlegenAlert = false
    /// Wird nach Anlage eines Musterhauses aufgerufen (z. B. zum Aktualisieren und Markieren in der StartView).
    var onMusterhausCreated: (() -> Void)?
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink(destination: RechtlichesView()) {
                        Label("Rechtliches", systemImage: "scale.3d")
                    }
                    NavigationLink(destination: DokumentationView()) {
                        Label("Dokumentation", systemImage: "book.fill")
                    }
                } header: {
                    Text("Informationen")
                }
                
                Section {
                    Button {
                        showMusterhausAnlegenAlert = true
                    } label: {
                        Label("Musterhaus anlegen", systemImage: "building.2.fill")
                    }
                } header: {
                    Text("Musterdaten")
                } footer: {
                    Text("Legt ein Musterhaus mit 2 Wohnungen, Zählerständen und Beispiel-Kosten für das Vorjahr an.")
                }
                
                // Developer-Bereich - nur in Debug/TestFlight sichtbar
                if DeveloperHelper.isDeveloperMode {
                    Section {
                        NavigationLink(destination: DeveloperView()) {
                            Label("Developer", systemImage: "wrench.and.screwdriver.fill")
                        }
                    } header: {
                        Text("Developer")
                    } footer: {
                        Text("Build: \(DeveloperHelper.buildConfiguration)")
                    }
                }
            }
            .scrollIndicators(.visible)
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") {
                        dismiss()
                    }
                }
            }
            .alert("Muster Haus mit 2 Muster-Wohnungen anlegen?", isPresented: $showMusterhausAnlegenAlert) {
                Button("Nein", role: .cancel) { }
                Button("Ja") {
                    let jahr = Calendar.current.component(.year, from: Date()) - 1
                    _ = DatabaseManager.shared.createMusterhaus(abrechnungsJahr: jahr)
                    onMusterhausCreated?()
                }
            } message: {
                Text("Es wird ein Musterhaus für das Jahr \(Calendar.current.component(.year, from: Date()) - 1) mit 2 Muster-Wohnungen, Zählerständen und Beispiel-Kosten angelegt.")
            }
        }
    }
}

struct RechtlichesView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            Section {
                Link(destination: URL(string: "https://kisoft4you.com/datenschutzerklaerung")!) {
                    HStack {
                        Label("Datenschutz", systemImage: "lock.shield.fill")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Link(destination: URL(string: "https://kisoft4you.com/impressum")!) {
                    HStack {
                        Label("Impressum", systemImage: "info.circle.fill")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Link(destination: URL(string: "https://kisoft4you.com/agb")!) {
                    HStack {
                        Label("AGB", systemImage: "doc.text.fill")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Rechtliche Informationen")
            } footer: {
                Text("Die rechtlichen Informationen werden auf unserer Website kisoft4you.com bereitgestellt.")
            }
        }
        .navigationTitle("Rechtliches")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    EinstellungenView()
}
