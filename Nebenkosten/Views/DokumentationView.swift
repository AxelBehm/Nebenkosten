//
//  DokumentationView.swift
//  Nebenkosten
//
//  Created by Axel Behm on 28.01.26.
//

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct DokumentationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showKopiertHinweis = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nebenkostenabrechnung")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Professionelle Verwaltung Ihrer Nebenkostenabrechnungen")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 10)
                    
                    Divider()
                    
                    // Hauptfunktionen
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Hauptfunktionen")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        FeatureRow(
                            icon: "doc.text.fill",
                            title: "Nebenkostenabrechnungen erstellen",
                            description: "Erstellen Sie professionelle Nebenkostenabrechnungen mit automatischer Berechnung aller Positionen."
                        )
                        
                        FeatureRow(
                            icon: "calendar.badge.plus",
                            title: "Automatische Jahresübergabe",
                            description: "Am Jahresende werden automatisch Vorträge für das nächste Jahr erstellt. Die Basis-Erfassung findet nur einmal statt - alle Daten werden intelligent übernommen."
                        )
                        
                        FeatureRow(
                            icon: "photo.on.rectangle.angled",
                            title: "Foto-Hinterlegung",
                            description: "Hinterlegen Sie Fotos bei Häusern, Mietern und Kosten. Alle wichtigen Dokumente und Belege sind direkt verfügbar."
                        )
                        
                        FeatureRow(
                            icon: "slider.horizontal.3",
                            title: "Variable Abrechnungsarten",
                            description: "Definieren Sie flexible Abrechnungsarten und Verteilungsmethoden nach Personen, Quadratmetern, Verbrauch oder Wohneinheiten."
                        )
                        
                        FeatureRow(
                            icon: "calculator.fill",
                            title: "Automatische Berechnung",
                            description: "Die App berechnet automatisch alle Abrechnungsdaten. Alternativ können Sie auch Einzelkosten pro Mieter individuell definieren."
                        )
                        
                        FeatureRow(
                            icon: "envelope.fill",
                            title: "PDF-Versand per E-Mail",
                            description: "Versenden Sie fertige Abrechnungen als PDF direkt per E-Mail an Vermieter oder Mieter - alles aus der App heraus."
                        )
                        
                        FeatureRow(
                            icon: "iphone",
                            title: "Alles dabei auf dem Handy",
                            description: "Nehmen Sie nur Ihr Handy zu Besprechungen der Nebenkosten mit den Mietern mit - Sie haben alle Daten, Fotos und Abrechnungen immer dabei."
                        )
                    }
                    
                    Divider()
                    
                    // System-Funktionen
                    VStack(alignment: .leading, spacing: 16) {
                        Text("System-Funktionen")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        FeatureRow(
                            icon: "icloud.and.arrow.up",
                            title: "In iCloud sichern",
                            description: "Erstellt ein Backup des markierten Hauses inklusive aller Wohnungen, Mietzeiträume, Zählerstände und Kosten. Die Datei kann geteilt oder an einem anderen Ort gespeichert werden."
                        )
                        
                        FeatureRow(
                            icon: "icloud.and.arrow.down",
                            title: "Backup wiederherstellen",
                            description: "Importiert eine zuvor erstellte Sicherung. Die Daten werden in die App übernommen."
                        )
                        
                        FeatureRow(
                            icon: "calendar.badge.plus",
                            title: "Jahreswechsel",
                            description: "Erstellt ein neues Jahr basierend auf dem markierten Haus. Mieter mit Mietende 31.12. sowie deren Zähler werden übernommen. Kosten-Positionen werden ohne Beträge übernommen."
                        )
                        
                        FeatureRow(
                            icon: "trash",
                            title: "Dieses Jahr löschen",
                            description: "Löscht die Abrechnung für das markierte Jahr inklusive aller Wohnungen, Mietzeiträume, Zählerstände und Kosten. Nicht wiederherstellbar."
                        )
                        
                        FeatureRow(
                            icon: "trash",
                            title: "Datenbank zurücksetzen",
                            description: "Setzt die Datenbank zurück und baut sie neu auf. Alle Daten werden gelöscht. Nützlich für einen kompletten Neustart."
                        )
                    }
                    
                    Divider()
                    
                    // Vorteile
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Vorteile")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            BulletPoint(text: "Zeitersparnis durch automatische Berechnungen")
                            BulletPoint(text: "Weniger Fehler durch strukturierte Erfassung")
                            BulletPoint(text: "Professionelle PDF-Abrechnungen")
                            BulletPoint(text: "Mobiler Zugriff auf alle Daten")
                            BulletPoint(text: "Einfache Jahresübergabe ohne doppelte Eingabe")
                            BulletPoint(text: "Übersichtliche Verwaltung mehrerer Häuser und Jahre")
                        }
                    }
                    
                    Divider()
                    
                    // Hinweise
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Hinweise")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Diese App unterstützt Sie bei der Erstellung und Verwaltung von Nebenkostenabrechnungen. Bitte beachten Sie die geltenden gesetzlichen Bestimmungen für Nebenkostenabrechnungen.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Dokumentation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        kopiereDokumentation()
                        showKopiertHinweis = true
                    } label: {
                        Label("Kopieren", systemImage: "doc.on.doc")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if showKopiertHinweis {
                    VStack {
                        Spacer()
                        Text("In Zwischenablage kopiert")
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                            .padding(.bottom, 40)
                    }
                    .transition(.opacity)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { showKopiertHinweis = false }
                        }
                    }
                }
            }
        }
    }
    
    private func kopiereDokumentation() {
        let text = dokumentationAlsText
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
    
    private var dokumentationAlsText: String {
        """
        Nebenkostenabrechnung
        Professionelle Verwaltung Ihrer Nebenkostenabrechnungen

        HAUPTFUNKTIONEN

        • Nebenkostenabrechnungen erstellen
        Erstellen Sie professionelle Nebenkostenabrechnungen mit automatischer Berechnung aller Positionen.

        • Automatische Jahresübergabe
        Am Jahresende werden automatisch Vorträge für das nächste Jahr erstellt. Die Basis-Erfassung findet nur einmal statt - alle Daten werden intelligent übernommen.

        • Foto-Hinterlegung
        Hinterlegen Sie Fotos bei Häusern, Mietern und Kosten. Alle wichtigen Dokumente und Belege sind direkt verfügbar.

        • Variable Abrechnungsarten
        Definieren Sie flexible Abrechnungsarten und Verteilungsmethoden nach Personen, Quadratmetern, Verbrauch oder Wohneinheiten.

        • Automatische Berechnung
        Die App berechnet automatisch alle Abrechnungsdaten. Alternativ können Sie auch Einzelkosten pro Mieter individuell definieren.

        • PDF-Versand per E-Mail
        Versenden Sie fertige Abrechnungen als PDF direkt per E-Mail an Vermieter oder Mieter - alles aus der App heraus.

        • Alles dabei auf dem Handy
        Nehmen Sie nur Ihr Handy zu Besprechungen der Nebenkosten mit den Mietern mit - Sie haben alle Daten, Fotos und Abrechnungen immer dabei.


        SYSTEM-FUNKTIONEN

        • In iCloud sichern
        Erstellt ein Backup des markierten Hauses inklusive aller Wohnungen, Mietzeiträume, Zählerstände und Kosten. Die Datei kann geteilt oder an einem anderen Ort gespeichert werden.

        • Backup wiederherstellen
        Importiert eine zuvor erstellte Sicherung. Die Daten werden in die App übernommen.

        • Jahreswechsel
        Erstellt ein neues Jahr basierend auf dem markierten Haus. Mieter mit Mietende 31.12. sowie deren Zähler werden übernommen. Kosten-Positionen werden ohne Beträge übernommen.

        • Dieses Jahr löschen
        Löscht die Abrechnung für das markierte Jahr inklusive aller Wohnungen, Mietzeiträume, Zählerstände und Kosten. Nicht wiederherstellbar.

        • Datenbank zurücksetzen
        Setzt die Datenbank zurück und baut sie neu auf. Alle Daten werden gelöscht. Nützlich für einen kompletten Neustart.


        VORTEILE

        • Zeitersparnis durch automatische Berechnungen
        • Weniger Fehler durch strukturierte Erfassung
        • Professionelle PDF-Abrechnungen
        • Mobiler Zugriff auf alle Daten
        • Einfache Jahresübergabe ohne doppelte Eingabe
        • Übersichtliche Verwaltung mehrerer Häuser und Jahre


        HINWEISE

        Diese App unterstützt Sie bei der Erstellung und Verwaltung von Nebenkostenabrechnungen. Bitte beachten Sie die geltenden gesetzlichen Bestimmungen für Nebenkostenabrechnungen.
        """
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct BulletPoint: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.headline)
                .foregroundStyle(.blue)
            Text(text)
                .font(.body)
        }
    }
}

#Preview {
    DokumentationView()
}
