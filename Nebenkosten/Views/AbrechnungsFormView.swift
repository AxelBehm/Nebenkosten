//
//  AbrechnungsFormView.swift
//  Nebenkosten
//
//  Created by Axel Behm on 22.01.26.
//

import SwiftUI
#if os(iOS) || os(tvOS)
import MessageUI
import PDFKit
#endif

// Wrapper für PDF-Daten um sie mit sheet(item:) zu verwenden
struct PDFDataItem: Identifiable {
    let id = UUID()
    let data: Data
}

#if os(iOS) || os(tvOS)
/// PDF-Vorschau für Teilen/E-Mail-Auswahl
private struct PDFPreviewView: UIViewRepresentable {
    let pdfData: Data
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        if let doc = PDFDocument(data: pdfData) {
            pdfView.document = doc
        }
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document == nil, let doc = PDFDocument(data: pdfData) {
            pdfView.document = doc
        }
    }
}
#endif

// DateFormatter für deutsche Datumsdarstellung
private let deDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "dd.MM.yyyy"
    f.locale = Locale(identifier: "de_DE")
    f.timeZone = TimeZone(identifier: "Europe/Berlin")
    return f
}()

private let isoDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "de_DE")
    f.timeZone = TimeZone(identifier: "Europe/Berlin")
    return f
}()

private func isoToDate(_ s: String) -> Date? {
    return isoDateFormatter.date(from: s)
}

private func formatGermanDate(_ isoString: String) -> String {
    guard let date = isoToDate(isoString) else { return isoString }
    return deDateFormatter.string(from: date)
}

private func formatPersonenAnzahlAbrechnung(_ wert: Double) -> String {
    if wert == floor(wert) { return "\(Int(wert))" }
    return String(format: "%.1f", wert).replacingOccurrences(of: ".", with: ",")
}
private func formatPersonentage(_ wert: Double) -> String {
    if wert == floor(wert) { return "\(Int(wert))" }
    return String(format: "%.1f", wert).replacingOccurrences(of: ".", with: ",")
}

/// Einheit für Anzeige: ganze Zahl → Person/Personen, Dezimal → Personenanteil
private func personenEinheitAnzeigeAbrechnung(_ wert: Double) -> String {
    if wert == floor(wert) {
        return wert == 1 ? "Person" : "Personen"
    }
    return "Personenanteil"
}

private func calculateDays(from: String, to: String) -> Int {
    guard let fromDate = isoToDate(from),
          let toDate = isoToDate(to) else { return 0 }
    let calendar = Calendar.current
    let components = calendar.dateComponents([.day], from: fromDate, to: toDate)
    // +1 weil der Tag selbst mitgezählt wird
    return (components.day ?? 0) + 1
}

/// Datumsbereich in 3 Zeilen: Zeile 1 = Von-Datum links, Zeile 2 = „bis“, Zeile 3 = Bis-Datum
private struct DatumszeilenView: View {
    let vonDatum: String
    let bisDatum: String
    var font: Font = .caption
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(formatGermanDate(vonDatum))
            Text("bis")
                .foregroundStyle(.secondary)
            Text(formatGermanDate(bisDatum))
        }
        .font(font)
    }
}

// Struktur für Leerstände
struct Leerstand: Identifiable {
    let id = UUID()
    let wohnungsnummer: String?
    let vonDatum: String
    let bisDatum: String
    let tage: Int
}

// Funktion zur Ermittlung von Leerständen für eine Wohnung
private func ermittleLeerstaende(
    wohnung: Wohnung,
    mietzeitraeume: [Mietzeitraum],
    jahr: Int
) -> [Leerstand] {
    let calendar = Calendar.current
    guard let jahrStart = calendar.date(from: DateComponents(year: jahr, month: 1, day: 1)),
          let jahrEnde = calendar.date(from: DateComponents(year: jahr, month: 12, day: 31)) else {
        return []
    }
    
    // DEBUG: Prüfe ob es Wohnung 5 ist
    let isWohnung5 = wohnung.wohnungsnummer == "5"
    if isWohnung5 {
        print("=== DEBUG Leerstandserkennung für Wohnung 5 ===")
        print("Wohnungs-ID: \(wohnung.id)")
        print("Wohnungsnummer: \(wohnung.wohnungsnummer ?? "keine")")
        print("Jahr: \(jahr)")
        print("JahrStart: \(isoDateFormatter.string(from: jahrStart))")
        print("JahrEnde: \(isoDateFormatter.string(from: jahrEnde))")
        print("Anzahl Mietzeiträume übergeben: \(mietzeitraeume.count)")
        print("Alle Mietzeiträume:")
        for (idx, m) in mietzeitraeume.enumerated() {
            print("  \(idx + 1). ID: \(m.id), von: \(m.vonDatum), bis: \(m.bisDatum), Mieter: \(m.hauptmieterName)")
        }
    }
    
    // Schritt 1: Sammle ALLE Mietzeiträume der Wohnung und schneide sie auf das Jahr zu
    var jahrZeitraeume: [(start: Date, ende: Date)] = []
    
    for (index, zeitraum) in mietzeitraeume.enumerated() {
        guard let zeitraumStart = isoToDate(zeitraum.vonDatum),
              let zeitraumEnde = isoToDate(zeitraum.bisDatum) else { continue }
        
        if isWohnung5 {
            print("\n--- Mietzeitraum \(index + 1) ---")
            print("Original: \(zeitraum.vonDatum) bis \(zeitraum.bisDatum)")
            print("Original (Date): \(isoDateFormatter.string(from: zeitraumStart)) bis \(isoDateFormatter.string(from: zeitraumEnde))")
        }
        
        // Prüfe, ob der Zeitraum das Jahr betrifft
        let betrifftJahr = (zeitraumStart <= jahrEnde) && (zeitraumEnde >= jahrStart)
        
        if betrifftJahr {
            // Schneide Zeitraum auf Jahr zu
            let startImJahr = max(jahrStart, zeitraumStart)
            let endeImJahr = min(jahrEnde, zeitraumEnde)
            
            if isWohnung5 {
                print("Betrifft Jahr: JA")
                print("Zugeschnitten: \(isoDateFormatter.string(from: startImJahr)) bis \(isoDateFormatter.string(from: endeImJahr))")
            }
            
            if startImJahr <= endeImJahr {
                jahrZeitraeume.append((start: startImJahr, ende: endeImJahr))
            }
        } else if isWohnung5 {
            print("Betrifft Jahr: NEIN")
        }
    }
    
    if isWohnung5 {
        print("\n--- Nach Schritt 1 (Zuschneiden) ---")
        print("Anzahl jahrZeitraeume: \(jahrZeitraeume.count)")
        for (index, (start, ende)) in jahrZeitraeume.enumerated() {
            print("Zeitraum \(index + 1): \(isoDateFormatter.string(from: start)) bis \(isoDateFormatter.string(from: ende))")
        }
    }
    
    // Schritt 2: Sortiere nach Einzugsdatum (Mieter 1, 2, 3, ...)
    // WICHTIG: Sortiere nach dem KLEINSTEN Einzugsdatum über alle Mieter dieser Wohnung
    jahrZeitraeume.sort { $0.start < $1.start }
    
    if isWohnung5 {
        print("\n--- Nach Sortierung nach Einzugsdatum (kleinstes zuerst) ---")
        for (index, (start, ende)) in jahrZeitraeume.enumerated() {
            print("Mieter \(index + 1): Einzug \(isoDateFormatter.string(from: start)), Auszug \(isoDateFormatter.string(from: ende))")
        }
    }
    
    // Schritt 3: Ermittle Leerstände nach neuer Logik
    var leerstaende: [Leerstand] = []
    
    // Wenn keine Mietzeiträume vorhanden, ist das ganze Jahr Leerstand
    if jahrZeitraeume.isEmpty {
        let tage = calendar.dateComponents([.day], from: jahrStart, to: jahrEnde).day ?? 0
        let tageMitEnde = tage + 1
        if tageMitEnde > 0 {
            let vonDatumStr = isoDateFormatter.string(from: jahrStart)
            let bisDatumStr = isoDateFormatter.string(from: jahrEnde)
            leerstaende.append(Leerstand(
                wohnungsnummer: wohnung.wohnungsnummer,
                vonDatum: vonDatumStr,
                bisDatum: bisDatumStr,
                tage: tageMitEnde
            ))
        }
        return leerstaende
    }
    
    // Test 1: Ist das 1. Einzugsdatum größer als 1.1.?
    if let ersterZeitraum = jahrZeitraeume.first {
        let erstesEinzugsdatum = ersterZeitraum.start
        
        if isWohnung5 {
            print("\n--- Test 1: Erstes Einzugsdatum prüfen ---")
            print("Erstes Einzugsdatum: \(isoDateFormatter.string(from: erstesEinzugsdatum))")
            print("JahrStart: \(isoDateFormatter.string(from: jahrStart))")
        }
        
        if erstesEinzugsdatum > jahrStart {
            // Leerstand vom 1.1. bis zum Einzugsdatum - 1 Tag
            if let leeEnde = calendar.date(byAdding: .day, value: -1, to: erstesEinzugsdatum) {
                let tage = calendar.dateComponents([.day], from: jahrStart, to: leeEnde).day ?? 0
                let tageMitEnde = tage + 1
                
                if isWohnung5 {
                    print("→ Leerstand vom Jahresanfang gefunden!")
                    print("  Von: \(isoDateFormatter.string(from: jahrStart))")
                    print("  Bis: \(isoDateFormatter.string(from: leeEnde))")
                    print("  Tage: \(tageMitEnde)")
                }
                
                if tageMitEnde > 0 {
                    let vonDatumStr = isoDateFormatter.string(from: jahrStart)
                    let bisDatumStr = isoDateFormatter.string(from: leeEnde)
                    leerstaende.append(Leerstand(
                        wohnungsnummer: wohnung.wohnungsnummer,
                        vonDatum: vonDatumStr,
                        bisDatum: bisDatumStr,
                        tage: tageMitEnde
                    ))
                }
            }
        } else if isWohnung5 {
            print("→ Kein Leerstand vom Jahresanfang (Einzugsdatum = 1.1.)")
        }
    }
    
    // Schritt 4: Gehe durch alle Mieter und prüfe Lücken
    for (index, (start, ende)) in jahrZeitraeume.enumerated() {
        if isWohnung5 {
            print("\n--- Prüfe Mieter \(index + 1) von \(jahrZeitraeume.count) ---")
            print("Einzugsdatum: \(isoDateFormatter.string(from: start))")
            print("Auszugsdatum: \(isoDateFormatter.string(from: ende))")
            print("Index: \(index), Gesamtanzahl: \(jahrZeitraeume.count)")
        }
        
        // Ist das Auszugsdatum kleiner als 31.12.?
        if ende < jahrEnde {
            if isWohnung5 {
                print("Auszugsdatum < 31.12., prüfe nächsten Mieter...")
            }
            
            // Prüfe ob es einen nächsten Mieter gibt
            if index < jahrZeitraeume.count - 1 {
                // Es gibt einen nächsten Mieter
                let naechsterZeitraum = jahrZeitraeume[index + 1]
                let naechstesEinzugsdatum = naechsterZeitraum.start
                
                if isWohnung5 {
                    print("Nächster Mieter gefunden! (Index \(index + 1))")
                    print("Nächstes Einzugsdatum: \(isoDateFormatter.string(from: naechstesEinzugsdatum))")
                }
                
                // Leerstand vom Auszugsdatum + 1 Tag bis zum Einzugsdatum des nächsten Mieters - 1 Tag
                if let leeStart = calendar.date(byAdding: .day, value: 1, to: ende),
                   let leeEnde = calendar.date(byAdding: .day, value: -1, to: naechstesEinzugsdatum) {
                    
                    // Nur wenn leeStart < leeEnde (es gibt wirklich eine Lücke)
                    if leeStart < leeEnde {
                        let tage = calendar.dateComponents([.day], from: leeStart, to: leeEnde).day ?? 0
                        let tageMitEnde = tage + 1
                        
                        if isWohnung5 {
                            print("→ Leerstand zwischen Mieter \(index + 1) und \(index + 2) gefunden!")
                            print("  Von: \(isoDateFormatter.string(from: leeStart))")
                            print("  Bis: \(isoDateFormatter.string(from: leeEnde))")
                            print("  Tage: \(tageMitEnde)")
                        }
                        
                        if tageMitEnde > 0 {
                            let vonDatumStr = isoDateFormatter.string(from: leeStart)
                            let bisDatumStr = isoDateFormatter.string(from: leeEnde)
                            leerstaende.append(Leerstand(
                                wohnungsnummer: wohnung.wohnungsnummer,
                                vonDatum: vonDatumStr,
                                bisDatum: bisDatumStr,
                                tage: tageMitEnde
                            ))
                        }
                    } else if isWohnung5 {
                        print("→ Keine Lücke (Zeiträume schließen direkt an)")
                    }
                }
            } else {
                // Kein nächster Mieter vorhanden - Leerstand bis Jahresende
                if isWohnung5 {
                    print("Kein nächster Mieter vorhanden (Index \(index) ist letzter von \(jahrZeitraeume.count))")
                }
                
                if let leeStart = calendar.date(byAdding: .day, value: 1, to: ende) {
                    let leeEnde = jahrEnde
                    let tage = calendar.dateComponents([.day], from: leeStart, to: leeEnde).day ?? 0
                    let tageMitEnde = tage + 1
                    
                    if isWohnung5 {
                        print("→ Kein nächster Mieter - Leerstand bis Jahresende!")
                        print("  Von: \(isoDateFormatter.string(from: leeStart))")
                        print("  Bis: \(isoDateFormatter.string(from: leeEnde))")
                        print("  Tage: \(tageMitEnde)")
                    }
                    
                    if tageMitEnde > 0 {
                        let vonDatumStr = isoDateFormatter.string(from: leeStart)
                        let bisDatumStr = isoDateFormatter.string(from: leeEnde)
                        leerstaende.append(Leerstand(
                            wohnungsnummer: wohnung.wohnungsnummer,
                            vonDatum: vonDatumStr,
                            bisDatum: bisDatumStr,
                            tage: tageMitEnde
                        ))
                    }
                }
            }
        } else if isWohnung5 {
            print("Auszugsdatum = 31.12., keine weiteren Aktionen")
        }
    }
    
    if isWohnung5 {
        print("\n=== ENDE DEBUG - Gefundene Leerstände: \(leerstaende.count) ===")
        for (index, leerstand) in leerstaende.enumerated() {
            print("Leerstand \(index + 1): \(leerstand.vonDatum) bis \(leerstand.bisDatum) (\(leerstand.tage) Tage)")
        }
        print("==========================================\n")
    }
    
    return leerstaende
}

struct AbrechnungsFormView: View {
    let abrechnung: HausAbrechnung
    @State private var wohnungen: [Wohnung] = []
    @State private var kosten: [Kosten] = []
    @State private var mietzeitraeume: [Int64: [Mietzeitraum]] = [:] // WohnungId -> Mietzeiträume
    @State private var mitmieter: [Int64: [Mitmieter]] = [:] // MietzeitraumId -> Mitmieter
    @State private var zaehlerstaende: [Int64: [Zaehlerstand]] = [:] // WohnungId -> Zählerstände
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerView
                
                if let verwalterName = abrechnung.verwalterName {
                    verwalterView(verwalterName: verwalterName)
                }
                
                if !kosten.isEmpty {
                    kostenUebersichtView
                }
                
                // Verbrauchsübersicht
                verbrauchsUebersichtView
                
                if !wohnungen.isEmpty {
                    mietzeitraeumeGesamtuebersichtView
                }
                
                if !wohnungen.isEmpty {
                    wohnungenView
                }
            }
            .padding()
        }
        .navigationTitle("Abrechnung")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadData()
        }
    }
    
    // MARK: - View Components
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nebenkosten")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text(abrechnung.hausBezeichnung)
                .font(.title2)
                .fontWeight(.semibold)
            
            HStack {
                Text("Abrechnungsjahr:")
                    .fontWeight(.medium)
                Text(String(abrechnung.abrechnungsJahr))
            }
            .font(.headline)
            
            if let plz = abrechnung.postleitzahl, let ort = abrechnung.ort {
                Text("\(plz) \(ort)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            if let gesamtflaeche = abrechnung.gesamtflaeche {
                HStack {
                    Text("Gesamtfläche:")
                        .fontWeight(.medium)
                    Text("\(gesamtflaeche) m²")
                }
                .font(.subheadline)
            }
            
            if let anzahlWohnungen = abrechnung.anzahlWohnungen {
                HStack {
                    Text("Anzahl Wohnungen:")
                        .fontWeight(.medium)
                    Text("\(anzahlWohnungen)")
                }
                .font(.subheadline)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private func verwalterView(verwalterName: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Verwalter")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(verwalterName)
            
            if let strasse = abrechnung.verwalterStrasse {
                Text(strasse)
            }
            
            if let plzOrt = abrechnung.verwalterPLZOrt {
                Text(plzOrt)
            }
            
            if let email = abrechnung.verwalterEmail {
                Text(email)
                    .foregroundStyle(.blue)
            }
            
            if let telefon = abrechnung.verwalterTelefon {
                Text(telefon)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private var kostenUebersichtView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kostenübersicht")
                .font(.title2)
                .fontWeight(.semibold)
            
            let gesamtKosten = kosten.reduce(0) { sum, k in
                if k.verteilungsart == .nachEinzelnachweis { return sum }
                return k.kostenart == .vorauszahlung ? sum - k.betrag : sum + k.betrag
            }
            HStack {
                Text("Gesamtkosten:")
                    .fontWeight(.medium)
                Spacer()
                Text("\(String(format: "%.2f", gesamtKosten)) €")
                    .fontWeight(.bold)
                    .font(.title3)
            }
            .padding(.bottom, 8)
            
            ForEach(kosten) { k in
                let betragAnzeige: Double = k.verteilungsart == .nachEinzelnachweis ? 0 : (k.kostenart == .vorauszahlung ? -k.betrag : k.betrag)
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(k.kostenart.rawValue)
                            .fontWeight(.medium)
                        if let bezeichnung = k.bezeichnung, !bezeichnung.isEmpty {
                            Text(bezeichnung)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(k.verteilungsart.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(String(format: "%.2f", betragAnzeige)) €")
                        .fontWeight(.medium)
                }
                .padding(.vertical, 4)
                Divider()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private var verbrauchsUebersichtView: some View {
        let gesamtFrischwasser = berechneGesamtFrischwasser()
        let gesamtFrischwasserMitAbwasser = berechneGesamtFrischwasserMitAbwasser()
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("Verbrauchsübersicht")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Gesamt Frischwasser:")
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(String(format: "%.2f", gesamtFrischwasser)) cbm")
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                }
                
                HStack {
                    Text("Frischwasser (auch Abwasser):")
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(String(format: "%.2f", gesamtFrischwasserMitAbwasser)) cbm")
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    // MARK: - Helper Functions
    
    private func berechneGesamtFrischwasser() -> Double {
        var gesamt: Double = 0
        for (_, zaehlerstaendeFuerWohnung) in zaehlerstaende {
            let frischwasserZaehler = zaehlerstaendeFuerWohnung.filter { $0.zaehlerTyp == "Frischwasser" }
            gesamt += frischwasserZaehler.reduce(0) { $0 + $1.differenz }
        }
        return gesamt
    }
    
    private func berechneGesamtFrischwasserMitAbwasser() -> Double {
        var gesamt: Double = 0
        for (_, zaehlerstaendeFuerWohnung) in zaehlerstaende {
            let frischwasserMitAbwasser = zaehlerstaendeFuerWohnung.filter { 
                $0.zaehlerTyp == "Frischwasser" && ($0.auchAbwasser ?? false)
            }
            gesamt += frischwasserMitAbwasser.reduce(0) { $0 + $1.differenz }
        }
        return gesamt
    }
    
    private var alleLeerstaende: [Leerstand] {
        guard abrechnung.leerstandspruefung == .ja else { return [] }
        var leerstaende: [Leerstand] = []
        
        // Gruppiere Wohnungen nach Wohnungsnummer
        let wohnungenNachNummer = Dictionary(grouping: wohnungen) { $0.wohnungsnummer ?? "" }
        
        // Für jede Wohnungsnummer: Sammle ALLE Mietzeiträume zusammen
        for (wohnungsnummer, wohnungenMitNummer) in wohnungenNachNummer {
            guard !wohnungsnummer.isEmpty else { continue }
            
            // Sammle ALLE Mietzeiträume für ALLE Wohnungen mit dieser Nummer
            var alleMietzeitraeumeFuerNummer: [Mietzeitraum] = []
            for wohnung in wohnungenMitNummer {
                if let mietzeitraeumeFuerWohnung = mietzeitraeume[wohnung.id] {
                    alleMietzeitraeumeFuerNummer.append(contentsOf: mietzeitraeumeFuerWohnung)
                }
            }
            
            // Verwende die erste Wohnung als Referenz (für wohnungsnummer)
            if let ersteWohnung = wohnungenMitNummer.first, !alleMietzeitraeumeFuerNummer.isEmpty {
                let leerstaendeFuerNummer = ermittleLeerstaende(
                    wohnung: ersteWohnung,
                    mietzeitraeume: alleMietzeitraeumeFuerNummer,
                    jahr: abrechnung.abrechnungsJahr
                )
                leerstaende.append(contentsOf: leerstaendeFuerNummer)
            }
        }
        
        return leerstaende
    }
    
    private var mietzeitraeumeGesamtuebersichtView: some View {
        let alleMietzeitraeume = wohnungen.flatMap { mietzeitraeume[$0.id] ?? [] }
        
        guard !alleMietzeitraeume.isEmpty || !alleLeerstaende.isEmpty else {
            return AnyView(EmptyView())
        }
        
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("Mietzeiträume - Gesamtübersicht")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                // Gruppiere alle Mietzeiträume nach Hauptmieter
                let gruppierteMietzeitraeume = Dictionary(grouping: alleMietzeitraeume) { $0.hauptmieterName }
                
                // Berechne Gesamtmiettage aus Personentagen (inkl. Leerstände)
                let gesamtLeerstandTage = alleLeerstaende.reduce(0) { $0 + $1.tage }
                let gesamtPersonentage = alleMietzeitraeume.reduce(0.0) { sum, m in
                    let tage = calculateDays(from: m.vonDatum, to: m.bisDatum)
                    return sum + Double(tage) * m.anzahlPersonen
                } + Double(gesamtLeerstandTage)
                
                HStack {
                    Text("Gesamtmiettage:")
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(formatPersonentage(gesamtPersonentage)) Personentag(e)")
                        .fontWeight(.bold)
                        .font(.title3)
                }
                .padding(.bottom, 8)
                
                ForEach(Array(gruppierteMietzeitraeume.keys.sorted()), id: \.self) { hauptmieterName in
                    if let zeitraeume = gruppierteMietzeitraeume[hauptmieterName] {
                        mietzeitraumGruppeView(hauptmieterName: hauptmieterName, zeitraeume: zeitraeume)
                    }
                }
                
                // Leerstände anzeigen, wenn vorhanden
                if !alleLeerstaende.isEmpty {
                    leerstaendeView
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        )
    }
    
    private func mietzeitraumGruppeView(hauptmieterName: String, zeitraeume: [Mietzeitraum]) -> some View {
        // Berechne Werte außerhalb des View-Builders
        let gesamtPersonentage = zeitraeume.reduce(0.0) { sum, m in
            let tage = calculateDays(from: m.vonDatum, to: m.bisDatum)
            return sum + Double(tage) * m.anzahlPersonen
        }
        let gesamtTageHauptmieter = zeitraeume.reduce(0) { sum, m in
            sum + calculateDays(from: m.vonDatum, to: m.bisDatum)
        }
        
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(hauptmieterName)
                    .fontWeight(.semibold)
                Spacer()
                Text("Gesamt: \(gesamtTageHauptmieter) Tag(e) • \(formatPersonentage(gesamtPersonentage)) Personentag(e)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Einzelne Mietzeiträume mit Hauptmieter
            ForEach(zeitraeume.sorted(by: { $0.vonDatum < $1.vonDatum })) { m in
                einzelnerMietzeitraumView(mietzeitraum: m)
            }
        }
        .padding(.vertical, 4)
        Divider()
    }
    
    private func einzelnerMietzeitraumView(mietzeitraum: Mietzeitraum) -> some View {
        let tage = calculateDays(from: mietzeitraum.vonDatum, to: mietzeitraum.bisDatum)
        let personentage = Double(tage) * mietzeitraum.anzahlPersonen
        
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                DatumszeilenView(vonDatum: mietzeitraum.vonDatum, bisDatum: mietzeitraum.bisDatum)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(tage) Tag(e)")
                        .foregroundStyle(.blue)
                    Text("• \(formatPersonenAnzahlAbrechnung(mietzeitraum.anzahlPersonen)) \(personenEinheitAnzeigeAbrechnung(mietzeitraum.anzahlPersonen))\(mietzeitraum.personenBeschreibung.map { " (\($0))" } ?? "")")
                        .foregroundStyle(.secondary)
                    Text("= \(formatPersonentage(personentage)) Personentag(e)")
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                }
                .font(.caption)
            }
            
            // Mitmieter für diesen Mietzeitraum
            if let mitmieterFuerMietzeitraum = mitmieter[mietzeitraum.id], !mitmieterFuerMietzeitraum.isEmpty {
                ForEach(mitmieterFuerMietzeitraum.sorted(by: { $0.vonDatum < $1.vonDatum })) { mitmieter in
                    let mitmieterTage = calculateDays(from: mitmieter.vonDatum, to: mitmieter.bisDatum)
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mitmieter:")
                                .fontWeight(.medium)
                            Text(mitmieter.name)
                            DatumszeilenView(vonDatum: mitmieter.vonDatum, bisDatum: mitmieter.bisDatum, font: .caption2)
                        }
                        Spacer()
                        Text("\(mitmieterTage) Tag(e)")
                            .foregroundStyle(.orange)
                            .font(.caption2)
                    }
                    .font(.caption2)
                    .padding(.leading, 16)
                }
            }
        }
        .padding(.vertical, 2)
    }
    
    private var leerstaendeView: some View {
        let vermieterName = abrechnung.verwalterName ?? "Vermieter"
        let gesamtLeerstandTage = alleLeerstaende.reduce(0) { $0 + $1.tage }
        
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(vermieterName)
                    .fontWeight(.semibold)
                Spacer()
                Text("Gesamt: \(gesamtLeerstandTage) Tag(e) (Leerstand)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            ForEach(alleLeerstaende.sorted(by: {
                // Sortiere zuerst nach Wohnungsnummer, dann nach Datum
                let nummer1 = $0.wohnungsnummer ?? ""
                let nummer2 = $1.wohnungsnummer ?? ""
                if nummer1 != nummer2 {
                    return nummer1 < nummer2
                }
                return $0.vonDatum < $1.vonDatum
            })) { leerstand in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Leerstand:")
                                .fontWeight(.medium)
                            if let nummer = leerstand.wohnungsnummer, !nummer.isEmpty {
                                Text("Wohnung \(nummer)")
                                    .fontWeight(.medium)
                            }
                        }
                        DatumszeilenView(vonDatum: leerstand.vonDatum, bisDatum: leerstand.bisDatum)
                    }
                    Spacer()
                    Text("\(leerstand.tage) Tag(e)")
                        .foregroundStyle(.red)
                        .fontWeight(.medium)
                        .font(.caption)
                }
                .font(.caption)
            }
        }
        .padding(.vertical, 4)
        Divider()
    }
    
    private var wohnungenView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Wohnungen")
                .font(.title2)
                .fontWeight(.semibold)
            
            ForEach(wohnungen) { wohnung in
                wohnungCard(wohnung: wohnung)
            }
        }
        .padding()
    }
    
    private func wohnungCard(wohnung: Wohnung) -> some View {
        // Berechne Personentage für diese Wohnung
        let mietzeitraeumeFuerWohnung = mietzeitraeume[wohnung.id] ?? []
        let personentageWohnung = mietzeitraeumeFuerWohnung.reduce(0.0) { sum, m in
            let tage = calculateDays(from: m.vonDatum, to: m.bisDatum)
            return sum + Double(tage) * m.anzahlPersonen
        }
        
        // Berechne Tage pro Wohnung (bezogen auf 1 Person)
        let tageWohnung = mietzeitraeumeFuerWohnung.reduce(0) { sum, m in
            let tage = calculateDays(from: m.vonDatum, to: m.bisDatum)
            return sum + tage
        }
        
        // Berechne Jahresanzahl der Tage (365 oder 366)
        let jahr = abrechnung.abrechnungsJahr
        let jahresTage: Int
        if let jahrStart = Calendar.current.date(from: DateComponents(year: jahr, month: 1, day: 1)),
           let jahrEnde = Calendar.current.date(from: DateComponents(year: jahr, month: 12, day: 31)),
           let range = Calendar.current.range(of: .day, in: .year, for: jahrStart) {
            jahresTage = range.count
        } else {
            // Fallback: Prüfe ob Schaltjahr
            jahresTage = (jahr % 4 == 0 && jahr % 100 != 0) || (jahr % 400 == 0) ? 366 : 365
        }
        
        // Berechne Verbrauch für diese Wohnung (pro Zählertyp)
        let zaehlerstaendeFuerWohnung = zaehlerstaende[wohnung.id] ?? []
        let verbrauchProTyp = berechneVerbrauchProTyp(zaehlerstaende: zaehlerstaendeFuerWohnung)
        
        return WohnungAbrechnungsCard(
            wohnung: wohnung,
            mietzeitraeume: mietzeitraeumeFuerWohnung,
            mitmieter: mitmieter,
            zaehlerstaende: zaehlerstaendeFuerWohnung,
            kosten: kosten,
            gesamtPersonentage: gesamtPersonentage,
            gesamtQm: abrechnung.gesamtflaeche ?? 0,
            gesamtVerbrauch: berechneGesamtverbrauch(),
            anzahlWohnungen: abrechnung.anzahlWohnungen ?? 1,
            personentageWohnung: personentageWohnung,
            verbrauchWohnung: verbrauchProTyp,
            tageWohnung: tageWohnung,
            jahresTage: jahresTage,
            haus: abrechnung,
            alleLeerstaende: alleLeerstaende,
            alleMietzeitraeumeGesamt: wohnungen.flatMap { mietzeitraeume[$0.id] ?? [] }
        )
    }
    
    // MARK: - Helper Functions
    
    private var gesamtPersonentage: Double {
        let alleMietzeitraeume = wohnungen.flatMap { mietzeitraeume[$0.id] ?? [] }
        let gesamtLeerstandTage = alleLeerstaende.reduce(0) { $0 + $1.tage }
        return alleMietzeitraeume.reduce(0.0) { sum, m in
            let tage = calculateDays(from: m.vonDatum, to: m.bisDatum)
            return sum + Double(tage) * m.anzahlPersonen
        } + Double(gesamtLeerstandTage)
    }
    
    private func berechneVerbrauchProTyp(zaehlerstaende: [Zaehlerstand]) -> [String: Double] {
        var verbrauchProTyp: [String: Double] = [:]
        
        // Gruppiere nach Zählertyp
        let zaehlerstaendeNachTyp = Dictionary(grouping: zaehlerstaende) { $0.zaehlerTyp }
        
        for (typ, zaehler) in zaehlerstaendeNachTyp {
            verbrauchProTyp[typ] = zaehler.reduce(0) { $0 + $1.differenz }
        }
        
        // Für Abwasser: Verwende nur Frischwasser-Zählerstände mit auchAbwasser = true
        let abwasserVerbrauch = zaehlerstaende
            .filter { $0.zaehlerTyp == "Frischwasser" && ($0.auchAbwasser ?? false) }
            .reduce(0) { $0 + $1.differenz }
        if abwasserVerbrauch > 0 {
            verbrauchProTyp["Abwasser"] = abwasserVerbrauch
        }
        
        return verbrauchProTyp
    }
    
    // Berechne Gesamtverbrauch pro Zählertyp
    private func berechneGesamtverbrauch() -> [String: Double] {
        var verbrauch: [String: Double] = [:]
        var abwasserVerbrauch: Double = 0
        
        for (_, zaehlerstaendeFuerWohnung) in zaehlerstaende {
            // Gruppiere nach Zählertyp
            let zaehlerstaendeNachTyp = Dictionary(grouping: zaehlerstaendeFuerWohnung) { $0.zaehlerTyp }
            
            for (typ, zaehler) in zaehlerstaendeNachTyp {
                if typ == "Frischwasser" {
                    let frischwasserSumme = zaehler.reduce(0) { $0 + $1.differenz }
                    verbrauch[typ, default: 0] += frischwasserSumme
                    
                    // Für Abwasser: Nur Zählerstände mit auchAbwasser = true
                    let abwasserSumme = zaehler
                        .filter { $0.auchAbwasser ?? false }
                        .reduce(0) { $0 + $1.differenz }
                    abwasserVerbrauch += abwasserSumme
                } else {
                    verbrauch[typ, default: 0] += zaehler.reduce(0) { $0 + $1.differenz }
                }
            }
        }
        
        // Füge Abwasser-Verbrauch hinzu, falls vorhanden
        if abwasserVerbrauch > 0 {
            verbrauch["Abwasser"] = abwasserVerbrauch
        }
        
        return verbrauch
    }
    
    private func loadData() {
        wohnungen = DatabaseManager.shared.getWohnungen(byHausAbrechnungId: abrechnung.id)
        kosten = DatabaseManager.shared.getKosten(byHausAbrechnungId: abrechnung.id)
        for wohnung in wohnungen {
            let mietzeitraeumeFuerWohnung = DatabaseManager.shared.getMietzeitraeume(byWohnungId: wohnung.id)
            mietzeitraeume[wohnung.id] = mietzeitraeumeFuerWohnung
            for mietzeitraum in mietzeitraeumeFuerWohnung {
                mitmieter[mietzeitraum.id] = DatabaseManager.shared.getMitmieter(byMietzeitraumId: mietzeitraum.id)
            }
            zaehlerstaende[wohnung.id] = DatabaseManager.shared.getZaehlerstaende(byWohnungId: wohnung.id)
        }
    }
}

struct WohnungAbrechnungsCard: View {
    let wohnung: Wohnung
    let mietzeitraeume: [Mietzeitraum]
    let mitmieter: [Int64: [Mitmieter]] // MietzeitraumId -> Mitmieter
    let zaehlerstaende: [Zaehlerstand]
    let kosten: [Kosten]
    let gesamtPersonentage: Double
    let gesamtQm: Int
    let gesamtVerbrauch: [String: Double] // Zählertyp -> Gesamtverbrauch
    let anzahlWohnungen: Int
    let personentageWohnung: Double
    let verbrauchWohnung: [String: Double] // Zählertyp -> Verbrauch dieser Wohnung
    let tageWohnung: Int // Tage pro Wohnung (bezogen auf 1 Person)
    let jahresTage: Int // Jahresanzahl der Tage (365 oder 366)
    let haus: HausAbrechnung
    let alleLeerstaende: [Leerstand]
    let alleMietzeitraeumeGesamt: [Mietzeitraum]
    
    @State private var showShareSheet = false
    @State private var showMailCompose = false
    @State private var showShareSheetDirect = false
    @State private var pdfData: Data?
    @State private var pdfDataForSheet: Data? // Separate Variable für das Sheet
    @State private var pdfDataToShare: Data? // PDF-Daten die direkt an das Sheet übergeben werden
    @State private var pdfDataItem: PDFDataItem? // Für item-basiertes Sheet
    @State private var savedPDFURL: URL? // Speicherort des gespeicherten PDFs
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            wohnungsHeaderView
            Divider()
            mietzeitraeumeView
            zaehlerstaendeView
            kostenpositionenView
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        .sheet(item: $pdfDataItem) { item in
            // Item-basiertes Sheet - pdfData wird direkt übergeben
            let _ = print("✅ Sheet geöffnet mit item-basiertem Sheet - PDF-Daten: \(item.data.count) Bytes")
            shareSheetContentWithData(pdfData: item.data)
        }
        .sheet(isPresented: $showShareSheetDirect) {
            if let pdfData = pdfDataForSheet ?? pdfData, !pdfData.isEmpty {
                ShareSheet(items: [pdfData], emailAddress: bestimmteEmailAdresse())
            }
        }
        .sheet(isPresented: $showMailCompose) {
            if let pdfData = pdfDataForSheet ?? pdfData, !pdfData.isEmpty {
                MailComposeView(
                    pdfData: pdfData,
                    fileName: "Nebenkostenabrechnung_\(haus.abrechnungsJahr)_\(wohnung.wohnungsnummer ?? "unbekannt").pdf",
                    recipientEmail: bestimmteEmailAdresse()
                )
            }
        }
        .alert("Fehler", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Subviews
    
    private var wohnungsHeaderView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if let nummer = wohnung.wohnungsnummer, !nummer.isEmpty {
                        Text("Wohnung Nr. \(nummer)")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    Spacer()
                    HStack(spacing: 12) {
                        Button {
                            generateAndSavePDF()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "doc.fill")
                                    .foregroundStyle(.blue)
                                Text("Anzeigen")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                            }
                        }
                        
                        Button {
                            sendPDF()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "envelope.fill")
                                    .foregroundStyle(.green)
                                Text("Versenden")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                        }
                        .disabled(savedPDFURL == nil)
                    }
                }
                Text(wohnung.bezeichnung)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                if let name = wohnung.name {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            Spacer()
            Text("\(wohnung.qm) m²")
                .font(.headline)
                .fontWeight(.semibold)
        }
    }
    
    @ViewBuilder
    private var mietzeitraeumeView: some View {
        if !mietzeitraeume.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Mietzeiträume")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                let gruppierteMietzeitraeume = Dictionary(grouping: mietzeitraeume) { $0.hauptmieterName }
                
                ForEach(Array(gruppierteMietzeitraeume.keys.sorted()), id: \.self) { hauptmieterName in
                    if let zeitraeume = gruppierteMietzeitraeume[hauptmieterName] {
                        mietzeitraumGruppeView(hauptmieterName: hauptmieterName, zeitraeume: zeitraeume)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private func mietzeitraumGruppeView(hauptmieterName: String, zeitraeume: [Mietzeitraum]) -> some View {
        // Berechne Werte außerhalb des View-Builders
        let gesamtPersonentage = zeitraeume.reduce(0.0) { sum, m in
            let tage = calculateDays(from: m.vonDatum, to: m.bisDatum)
            return sum + Double(tage) * m.anzahlPersonen
        }
        
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(hauptmieterName)
                    .fontWeight(.semibold)
                Spacer()
                Text("Gesamt: \(formatPersonentage(gesamtPersonentage)) Personentag(e)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            ForEach(zeitraeume.sorted(by: { $0.vonDatum < $1.vonDatum })) { m in
                mietzeitraumDetailView(mietzeitraum: m)
            }
        }
        .padding(.vertical, 4)
        .overlay(
            Divider(),
            alignment: .bottom
        )
    }
    
    private func mietzeitraumDetailView(mietzeitraum: Mietzeitraum) -> some View {
        let tage = calculateDays(from: mietzeitraum.vonDatum, to: mietzeitraum.bisDatum)
        let personentage = Double(tage) * mietzeitraum.anzahlPersonen
        
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                DatumszeilenView(vonDatum: mietzeitraum.vonDatum, bisDatum: mietzeitraum.bisDatum)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(tage) Tag(e)")
                        .foregroundStyle(.blue)
                    Text("• \(formatPersonenAnzahlAbrechnung(mietzeitraum.anzahlPersonen)) \(personenEinheitAnzeigeAbrechnung(mietzeitraum.anzahlPersonen))\(mietzeitraum.personenBeschreibung.map { " (\($0))" } ?? "")")
                        .foregroundStyle(.secondary)
                    Text("= \(formatPersonentage(personentage)) Personentag(e)")
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                }
                .font(.caption)
            }
            
            if let mitmieterFuerMietzeitraum = mitmieter[mietzeitraum.id], !mitmieterFuerMietzeitraum.isEmpty {
                ForEach(mitmieterFuerMietzeitraum.sorted(by: { $0.vonDatum < $1.vonDatum })) { mitmieter in
                    mitmieterView(mitmieter: mitmieter)
                }
            }
        }
        .padding(.vertical, 2)
    }
    
    private func mitmieterView(mitmieter: Mitmieter) -> some View {
        let mitmieterTage = calculateDays(from: mitmieter.vonDatum, to: mitmieter.bisDatum)
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Mitmieter:")
                    .fontWeight(.medium)
                Text(mitmieter.name)
                DatumszeilenView(vonDatum: mitmieter.vonDatum, bisDatum: mitmieter.bisDatum, font: .caption2)
            }
            Spacer()
            Text("\(mitmieterTage) Tag(e)")
                .foregroundStyle(.orange)
                .font(.caption2)
        }
        .font(.caption2)
        .padding(.leading, 16)
    }
    
    @ViewBuilder
    private var zaehlerstaendeView: some View {
        if !zaehlerstaende.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Zählerstände")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                ForEach(zaehlerstaende) { z in
                    zaehlerstandView(zaehlerstand: z)
                }
            }
            .padding(.vertical, 4)
            Divider()
        }
    }
    
    private func zaehlerstandView(zaehlerstand: Zaehlerstand) -> some View {
        HStack(spacing: 10) {
            Image(systemName: Zaehlerstand.symbolName(for: zaehlerstand.zaehlerTyp))
                .font(.body)
                .foregroundStyle(Color.appBlue)
                .frame(width: 24, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(zaehlerstand.zaehlerTyp)
                    .fontWeight(.medium)
                if let nummer = zaehlerstand.zaehlerNummer, !nummer.isEmpty {
                    Text("Zähler-Nr: \(nummer)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if zaehlerstand.zaehlerTyp == "Frischwasser", let auchAbwasser = zaehlerstand.auchAbwasser {
                    Text(auchAbwasser ? "auch Abwasser: Ja" : "auch Abwasser: Nein")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(String(format: "%.2f", zaehlerstand.zaehlerStart)) → \(String(format: "%.2f", zaehlerstand.zaehlerEnde))")
                    .font(.caption)
                Text("Diff: \(String(format: "%.2f", zaehlerstand.differenz))")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
            }
        }
        .font(.caption)
    }
    
    /// Kosten sortiert: Minus-Positionen (z. B. Vorauszahlung) ans Ende
    private var kostenSortiert: [Kosten] {
        kosten.sorted { k1, k2 in
            let minus1 = (k1.kostenart == .vorauszahlung)
            let minus2 = (k2.kostenart == .vorauszahlung)
            if minus1 != minus2 { return minus2 }
            return k1.kostenart.rawValue < k2.kostenart.rawValue
        }
    }
    
    /// Kosten gefiltert für diese Wohnung: nachVerbrauch-Positionen nur anzeigen, wenn die Wohnung einen Zähler dieses Typs hat.
    /// Hausstrom wird nach Personen abgerechnet (kein Zähler) → immer anzeigen.
    private var kostenGefiltertFuerWohnung: [Kosten] {
        kosten.filter { k in
            guard k.verteilungsart == .nachVerbrauch else { return true }
            if k.kostenart == .hausstrom { return true }  // Hausstrom: nach Personen, kein Strom-Zähler
            let zaehlerTyp: String
            switch k.kostenart {
            case .frischwasser: zaehlerTyp = "Frischwasser"
            case .warmwasser: zaehlerTyp = "Warmwasser"
            case .abwasser: zaehlerTyp = "Abwasser"
            case .strom: zaehlerTyp = "Strom"  // Zähler Strom → Kostenart Strom
            case .gas, .heizungswartung: zaehlerTyp = "Gas"  // Zähler Gas → Kostenart Gas
            default: zaehlerTyp = k.kostenart.rawValue
            }
            return (verbrauchWohnung[zaehlerTyp] ?? 0) > 0
        }
    }
    
    @ViewBuilder
    private var kostenpositionenView: some View {
        let filtered = kostenGefiltertFuerWohnung
        if !filtered.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Kostenpositionen")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                let sorted = filtered.sorted { k1, k2 in
                    let minus1 = (k1.kostenart == .vorauszahlung)
                    let minus2 = (k2.kostenart == .vorauszahlung)
                    if minus1 != minus2 { return minus2 }
                    return k1.kostenart.rawValue < k2.kostenart.rawValue
                }
                let firstVorauszahlungIndex = sorted.firstIndex(where: { $0.kostenart == .vorauszahlung })
                ForEach(Array(sorted.enumerated()), id: \.element.id) { index, k in
                    if index == firstVorauszahlungIndex {
                        gesamtsummeRow(
                            sum: sorted.prefix(index).reduce(0) { sum, kostenItem in
                                sum + berechneKostenanteil(
                                    kostenItem: kostenItem,
                                    personentageWohnung: personentageWohnung,
                                    qmWohnung: wohnung.qm,
                                    verbrauchWohnung: verbrauchWohnung,
                                    wohnungId: wohnung.id,
                                    tageWohnung: tageWohnung,
                                    jahresTage: jahresTage
                                )
                            }
                        )
                    }
                    kostenpositionView(kostenItem: k)
                }
                
                Divider()
                gesamtAnteilView
            }
            .padding(.vertical, 4)
        }
    }
    
    /// Eine Zeile „Gesamtsumme: X €“ (rechtsbündig), wird vor der Vorauszahlung eingefügt.
    private func gesamtsummeRow(sum: Double) -> some View {
        HStack {
            Text("Gesamtsumme:")
                .fontWeight(.semibold)
            Spacer()
            Text("\(String(format: "%.2f", sum)) €")
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
        .font(.subheadline)
        .padding(.vertical, 4)
    }
    
    private func kostenpositionView(kostenItem: Kosten) -> some View {
        let anteil = berechneKostenanteil(
            kostenItem: kostenItem,
            personentageWohnung: personentageWohnung,
            qmWohnung: wohnung.qm,
            verbrauchWohnung: verbrauchWohnung,
            wohnungId: wohnung.id,
            tageWohnung: tageWohnung,
            jahresTage: jahresTage
        )
        
        let zeigtTage = (kostenItem.verteilungsart == .nachQm || kostenItem.verteilungsart == .nachWohneinheiten)
        
        let formel = berechneFormel(
            kostenItem: kostenItem,
            personentageWohnung: personentageWohnung,
            qmWohnung: wohnung.qm,
            verbrauchWohnung: verbrauchWohnung,
            tageWohnung: tageWohnung,
            jahresTage: jahresTage
        )
        
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(kostenItem.kostenart.rawValue)
                    .fontWeight(.medium)
                if let bezeichnung = kostenItem.bezeichnung, !bezeichnung.isEmpty {
                    Text(bezeichnung)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text("Verteilung: \(kostenItem.verteilungsart.rawValue)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if zeigtTage {
                    Text("\(tageWohnung) Tag(e) von \(jahresTage) Tag(en)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(formel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .italic()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(String(format: "%.2f", anteil)) €")
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
            }
        }
        .font(.caption)
        .padding(.vertical, 4)
    }
    
    private var gesamtAnteilView: some View {
        let gesamtAnteil = kostenGefiltertFuerWohnung.reduce(0) { sum, k in
            sum + berechneKostenanteil(
                kostenItem: k,
                personentageWohnung: personentageWohnung,
                qmWohnung: wohnung.qm,
                verbrauchWohnung: verbrauchWohnung,
                wohnungId: wohnung.id,
                tageWohnung: tageWohnung,
                jahresTage: jahresTage
            )
        }
        
        return HStack {
            Text("Gesamtanteil:")
                .fontWeight(.semibold)
            Spacer()
            Text("\(String(format: "%.2f", gesamtAnteil)) €")
                .fontWeight(.bold)
                .font(.headline)
                .foregroundStyle(gesamtAnteil < 0 ? .red : .green)
        }
        .font(.subheadline)
    }
    
    @ViewBuilder
    private func shareSheetContentWithData(pdfData: Data) -> some View {
        // Prüfe ob Mail konfiguriert ist
        #if os(iOS) || os(tvOS)
        if MFMailComposeViewController.canSendMail() {
            // Wenn Mail verfügbar ist, zeige Vorschau + Optionen
            NavigationStack {
                VStack(spacing: 0) {
                    Text("Vorschau")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    PDFPreviewView(pdfData: pdfData)
                        .frame(height: 340)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    Divider()
                    VStack(spacing: 12) {
                        Button {
                            pdfDataItem = nil
                            self.pdfData = pdfData
                            self.pdfDataForSheet = pdfData
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showMailCompose = true
                            }
                        } label: {
                            Label("Als E-Mail versenden", systemImage: "envelope.fill")
                        }
                        .buttonStyle(.appProminent)
                        Button {
                            pdfDataItem = nil
                            self.pdfData = pdfData
                            self.pdfDataForSheet = pdfData
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showShareSheetDirect = true
                            }
                        } label: {
                            Label("Teilen (andere Optionen)", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.appSecondary)
                    }
                    .padding()
                }
                .navigationTitle("PDF teilen")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Abbrechen") {
                            pdfDataItem = nil
                        }
                    }
                }
            }
        } else {
            // Wenn Mail nicht verfügbar ist, zeige normale Share Sheet
            ShareSheet(items: [pdfData], emailAddress: bestimmteEmailAdresse())
        }
        #else
        // Auf macOS kein MessageUI: direkt Share Sheet anbieten
        ShareSheet(items: [pdfData], emailAddress: bestimmteEmailAdresse())
        #endif
    }
    
    @ViewBuilder
    private var shareSheetContent: some View {
        // Verwende pdfDataForSheet statt pdfData für bessere Synchronisation
        if let pdfData = pdfDataForSheet ?? pdfData, !pdfData.isEmpty {
            // Prüfe ob Mail konfiguriert ist
            #if os(iOS) || os(tvOS)
            if MFMailComposeViewController.canSendMail() {
                // Wenn Mail verfügbar ist, zeige Optionen
                NavigationStack {
                    VStack(spacing: 16) {
                        Button {
                            showShareSheet = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showMailCompose = true
                            }
                        } label: {
                            Label("Als E-Mail versenden", systemImage: "envelope.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button {
                            showShareSheet = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showShareSheetDirect = true
                            }
                        } label: {
                            Label("Teilen (andere Optionen)", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .navigationTitle("PDF teilen")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Abbrechen") {
                                showShareSheet = false
                            }
                        }
                    }
                }
            } else {
                // Wenn Mail nicht verfügbar ist, zeige normale Share Sheet
                ShareSheet(items: [pdfData], emailAddress: bestimmteEmailAdresse())
            }
            #else
            // Auf macOS kein MessageUI: direkt Share Sheet anbieten
            ShareSheet(items: [pdfData], emailAddress: bestimmteEmailAdresse())
            #endif
        } else {
            VStack(spacing: 16) {
                Text("Fehler")
                    .font(.headline)
                Text("PDF konnte nicht geladen werden")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("PDF-Daten: nil")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
    
    private func bestimmteEmailAdresse() -> String? {
        if haus.verwalterInEmailVorbelegen == true, let verwalterEmail = haus.verwalterEmail, !verwalterEmail.isEmpty {
            return verwalterEmail
        } else {
            return wohnung.email
        }
    }
    
    // MARK: - Helper Functions
    private func berechneKostenanteil(
        kostenItem: Kosten,
        personentageWohnung: Double,
        qmWohnung: Int,
        verbrauchWohnung: [String: Double],
        wohnungId: Int64,
        tageWohnung: Int,
        jahresTage: Int
    ) -> Double {
        switch kostenItem.verteilungsart {
        case .nachPersonen:
            // Wert / Gesamtmiettage * Personentage des Mieters
            if gesamtPersonentage > 0 {
                return (kostenItem.betrag / gesamtPersonentage) * personentageWohnung
            }
            return 0
            
        case .nachQm:
            // Wert / Gesamt-QM * QM der Wohnung * Zeitanteil
            if gesamtQm > 0 && jahresTage > 0 {
                let basisAnteil = (kostenItem.betrag / Double(gesamtQm)) * Double(qmWohnung)
                let zeitanteil = Double(tageWohnung) / Double(jahresTage)
                return basisAnteil * zeitanteil
            }
            return 0
            
        case .nachVerbrauch:
            // Wert / Gesamtverbrauch * Verbrauch der Wohnung (OHNE Zeitanteil)
            // Für Frischwasser: verwende Frischwasser-Verbrauch
            // Für Abwasser: verwende nur Frischwasser-Verbrauch mit auchAbwasser = true
            // Für andere: verwende entsprechenden Zählertyp
            let zaehlerTyp: String
            switch kostenItem.kostenart {
            case .frischwasser:
                zaehlerTyp = "Frischwasser"
            case .warmwasser:
                zaehlerTyp = "Warmwasser"
            case .abwasser:
                zaehlerTyp = "Abwasser" // Wird separat berechnet (nur Frischwasser mit auchAbwasser)
            case .strom:
                zaehlerTyp = "Strom"
            case .hausstrom:
                zaehlerTyp = "Strom"
            case .heizungswartung:
                zaehlerTyp = "Gas"
            case .gas:
                zaehlerTyp = "Gas"
            default:
                zaehlerTyp = kostenItem.kostenart.rawValue
            }
            
            let verbrauchWohnungTyp = verbrauchWohnung[zaehlerTyp] ?? 0
            let gesamtVerbrauchTyp = gesamtVerbrauch[zaehlerTyp] ?? 0
            
            if gesamtVerbrauchTyp > 0 {
                return (kostenItem.betrag / gesamtVerbrauchTyp) * verbrauchWohnungTyp
            }
            return 0
            
        case .nachWohneinheiten:
            // Wert / Anzahl Wohnungen * Zeitanteil
            if anzahlWohnungen > 0 && jahresTage > 0 {
                let basisAnteil = kostenItem.betrag / Double(anzahlWohnungen)
                let zeitanteil = Double(tageWohnung) / Double(jahresTage)
                return basisAnteil * zeitanteil
            }
            return 0
            
        case .nachEinzelnachweis:
            // Wert direkt (keine Verteilung) - verwende gespeicherten Wert pro Wohnung falls vorhanden
            // Prüfe ob ein spezifischer Wert für diese Wohnung gespeichert ist
            if let einzelnachweis = DatabaseManager.shared.getEinzelnachweisWohnung(
                kostenId: kostenItem.id,
                wohnungId: wohnungId
            ), let betrag = einzelnachweis.betrag {
                return betrag
            }
            // Fallback: Verwende den Gesamtbetrag der Kosten
            return kostenItem.betrag
        }
    }
    
    // Berechne Formel für die Anzeige
    private func berechneFormel(
        kostenItem: Kosten,
        personentageWohnung: Double,
        qmWohnung: Int,
        verbrauchWohnung: [String: Double],
        tageWohnung: Int,
        jahresTage: Int
    ) -> String {
        switch kostenItem.verteilungsart {
        case .nachPersonen:
            return "\(String(format: "%.2f", kostenItem.betrag)) € / \(formatPersonentage(gesamtPersonentage)) Personentage × \(formatPersonentage(personentageWohnung)) Personentage"
            
        case .nachQm:
            let zeitanteil = jahresTage > 0 ? Double(tageWohnung) / Double(jahresTage) : 0
            if abs(zeitanteil - 1.0) < 0.0001 {
                // Zeitanteil ist 1.0, keine Anzeige nötig
                return "\(String(format: "%.2f", kostenItem.betrag)) € / \(gesamtQm) m² × \(qmWohnung) m²"
            } else {
                return "\(String(format: "%.2f", kostenItem.betrag)) € / \(gesamtQm) m² × \(qmWohnung) m² × \(String(format: "%.4f", zeitanteil))"
            }
            
        case .nachVerbrauch:
            let zaehlerTyp: String
            switch kostenItem.kostenart {
            case .frischwasser:
                zaehlerTyp = "Frischwasser"
            case .warmwasser:
                zaehlerTyp = "Warmwasser"
            case .abwasser:
                zaehlerTyp = "Abwasser"
            case .strom:
                zaehlerTyp = "Strom"
            case .hausstrom:
                zaehlerTyp = "Strom"
            case .heizungswartung:
                zaehlerTyp = "Gas"
            case .gas:
                zaehlerTyp = "Gas"
            default:
                zaehlerTyp = kostenItem.kostenart.rawValue
            }
            let verbrauchWohnungTyp = verbrauchWohnung[zaehlerTyp] ?? 0
            let gesamtVerbrauchTyp = gesamtVerbrauch[zaehlerTyp] ?? 0
            return "\(String(format: "%.2f", kostenItem.betrag)) € / \(String(format: "%.2f", gesamtVerbrauchTyp)) \(zaehlerTyp) × \(String(format: "%.2f", verbrauchWohnungTyp)) \(zaehlerTyp)"
            
        case .nachWohneinheiten:
            let zeitanteil = jahresTage > 0 ? Double(tageWohnung) / Double(jahresTage) : 0
            if abs(zeitanteil - 1.0) < 0.0001 {
                // Zeitanteil ist 1.0, keine Anzeige nötig
                return "\(String(format: "%.2f", kostenItem.betrag)) € / \(anzahlWohnungen) Wohneinheiten"
            } else {
                return "\(String(format: "%.2f", kostenItem.betrag)) € / \(anzahlWohnungen) Wohneinheiten × \(String(format: "%.4f", zeitanteil))"
            }
            
        case .nachEinzelnachweis:
            return "Direkter Wert"
        }
    }
    
    private func generateAndSavePDF() {
        print("=== PDF-Generierung und Speicherung gestartet ===")
        
        // Generiere PDF
        guard let generatedPDFData = PDFGenerator.generateAbrechnungPDF(
            haus: haus,
            wohnung: wohnung,
            mietzeitraeume: mietzeitraeume,
            mitmieter: mitmieter,
            zaehlerstaende: zaehlerstaende,
            kosten: kostenGefiltertFuerWohnung,
            gesamtPersonentage: gesamtPersonentage,
            gesamtQm: gesamtQm,
            gesamtVerbrauch: gesamtVerbrauch,
            anzahlWohnungen: anzahlWohnungen,
            personentageWohnung: personentageWohnung,
            verbrauchWohnung: verbrauchWohnung,
            tageWohnung: tageWohnung,
            jahresTage: jahresTage,
            alleLeerstaende: alleLeerstaende,
            alleMietzeitraeumeGesamt: alleMietzeitraeumeGesamt
        ) else {
            print("❌ PDF-Generierung fehlgeschlagen")
            errorMessage = "Fehler beim Generieren des PDFs"
            showError = true
            return
        }
        
        print("✅ PDF generiert, Größe: \(generatedPDFData.count) Bytes")
        
        // Speichere PDF in temporärem Verzeichnis
        let fileName = "Nebenkostenabrechnung_\(haus.abrechnungsJahr)_\(wohnung.wohnungsnummer ?? "unbekannt").pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try generatedPDFData.write(to: tempURL)
            self.savedPDFURL = tempURL
            self.pdfData = generatedPDFData
            print("✅ PDF gespeichert: \(tempURL.path)")
            
            // Öffne Share Sheet zum Anzeigen/Speichern
            self.pdfDataItem = PDFDataItem(data: generatedPDFData)
        } catch {
            print("❌ Fehler beim Speichern des PDFs: \(error.localizedDescription)")
            errorMessage = "Fehler beim Speichern des PDFs: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func sendPDF() {
        guard let pdfURL = savedPDFURL else {
            errorMessage = "Bitte erst PDF anzeigen und speichern"
            showError = true
            return
        }
        
        // Lese PDF-Daten aus gespeicherter Datei
        guard let pdfData = try? Data(contentsOf: pdfURL) else {
            errorMessage = "Fehler beim Lesen des gespeicherten PDFs"
            showError = true
            return
        }
        
        // Bestimme E-Mail-Adresse basierend auf Schalter
        let emailAdresse = bestimmteEmailAdresse()
        
        // Prüfe ob Mail konfiguriert ist
        #if os(iOS) || os(tvOS)
        if MFMailComposeViewController.canSendMail() {
            // Öffne Mail-Compose-View
            self.pdfData = pdfData
            self.pdfDataForSheet = pdfData
            showMailCompose = true
        } else {
            // Öffne Share Sheet
            self.pdfData = pdfData
            self.pdfDataForSheet = pdfData
            showShareSheetDirect = true
        }
        #else
        // Auf macOS kein MessageUI: direkt Share Sheet anbieten
        self.pdfData = pdfData
        self.pdfDataForSheet = pdfData
        showShareSheetDirect = true
        #endif
    }
}
