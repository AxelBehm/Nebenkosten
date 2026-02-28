//
//  PDFGenerator.swift
//  Nebenkosten
//
//  Created by Axel Behm on 22.01.26.
//

import Foundation
import PDFKit
#if os(iOS) || os(tvOS)
import UIKit
#endif

// Helper-Funktionen für Datumsberechnungen
private func calculateDays(from: String, to: String) -> Int {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    guard let fromDate = dateFormatter.date(from: from),
          let toDate = dateFormatter.date(from: to) else {
        return 0
    }
    let calendar = Calendar.current
    let components = calendar.dateComponents([.day], from: fromDate, to: toDate)
    return (components.day ?? 0) + 1
}

private func isoToDate(_ s: String) -> Date? {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    return dateFormatter.date(from: s)
}

private func formatPersonentagePDF(_ wert: Double) -> String {
    if wert == floor(wert) { return "\(Int(wert))" }
    return String(format: "%.1f", wert).replacingOccurrences(of: ".", with: ",")
}

private func formatPersonenAnzahlPDF(_ wert: Double) -> String {
    if wert == floor(wert) { return "\(Int(wert))" }
    return String(format: "%.1f", wert).replacingOccurrences(of: ".", with: ",")
}

/// Einheit für Anzeige: ganze Zahl → Person/Personen, Dezimal → Personenanteil
private func personenEinheitAnzeigePDF(_ wert: Double) -> String {
    if wert == floor(wert) {
        return wert == 1 ? "Person" : "Personen"
    }
    return "Personenanteil"
}

struct PDFGenerator {
    static func generateAbrechnungPDF(
        haus: HausAbrechnung,
        wohnung: Wohnung,
        mietzeitraeume: [Mietzeitraum],
        mitmieter: [Int64: [Mitmieter]],
        zaehlerstaende: [Zaehlerstand],
        kosten: [Kosten],
        gesamtPersonentage: Double,
        gesamtQm: Int,
        gesamtVerbrauch: [String: Double],
        anzahlWohnungen: Int,
        personentageWohnung: Double,
        verbrauchWohnung: [String: Double],
        tageWohnung: Int,
        jahresTage: Int,
        alleLeerstaende: [Leerstand],
        alleMietzeitraeumeGesamt: [Mietzeitraum]
    ) -> Data? {
        #if os(iOS) || os(tvOS)
        let pdfMetaData = [
            kCGPDFContextCreator: "Nebenkosten App",
            kCGPDFContextAuthor: haus.verwalterName ?? "",
            kCGPDFContextTitle: "Nebenkostenabrechnung \(haus.abrechnungsJahr)"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageWidth = 595.0 // A4 width in points
        let pageHeight = 842.0 // A4 height in points
        let margin: CGFloat = 50.0
        let contentWidth = pageWidth - (2 * margin)
        
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight), format: format)
        
        let data = pdfRenderer.pdfData { context in
            var currentY: CGFloat = margin
            
            // Starte erste Seite
            context.beginPage()
            if !LimitManager.shared.isPremium { Self.drawMusterWatermark(context: context, pageWidth: pageWidth, pageHeight: pageHeight) }
            
            // Absender-Block oben links: Verwalter Name, Strasse, PLZ Ort (jeweils eigene Zeile, kleine Schrift)
            let absenderAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9),
                .foregroundColor: UIColor.black
            ]
            if let verwalterName = haus.verwalterName, !verwalterName.isEmpty {
                let nameStr = NSAttributedString(string: verwalterName, attributes: absenderAttributes)
                nameStr.draw(in: CGRect(x: margin, y: currentY, width: contentWidth / 2, height: 12))
                currentY += 12
            }
            if let verwalterStrasse = haus.verwalterStrasse, !verwalterStrasse.isEmpty {
                let strasseStr = NSAttributedString(string: verwalterStrasse, attributes: absenderAttributes)
                strasseStr.draw(in: CGRect(x: margin, y: currentY, width: contentWidth / 2, height: 12))
                currentY += 12
            }
            if let verwalterPLZOrt = haus.verwalterPLZOrt, !verwalterPLZOrt.isEmpty {
                let plzOrtStr = NSAttributedString(string: verwalterPLZOrt, attributes: absenderAttributes)
                plzOrtStr.draw(in: CGRect(x: margin, y: currentY, width: contentWidth / 2, height: 12))
                currentY += 12
            }
            
            currentY += 30 // Abstand nach Absender-Block
            
            currentY += 15 // 1 Zeile vor der einzeiligen Verwalter-Adresse
            
            // Absender-Zeile direkt über der Anschrift (Name · Strasse · PLZ Ort, kleine Schrift, für Fensterumschlag)
            var absenderZeileTeile: [String] = []
            if let n = haus.verwalterName, !n.isEmpty { absenderZeileTeile.append(n) }
            if let s = haus.verwalterStrasse, !s.isEmpty { absenderZeileTeile.append(s) }
            if let p = haus.verwalterPLZOrt, !p.isEmpty { absenderZeileTeile.append(p) }
            if !absenderZeileTeile.isEmpty {
                let absenderZeileText = absenderZeileTeile.prefix(3).joined(separator: "  ·  ")
                let absenderZeileStr = NSAttributedString(string: absenderZeileText, attributes: absenderAttributes)
                absenderZeileStr.draw(in: CGRect(x: margin, y: currentY, width: contentWidth, height: 12))
                currentY += 14
            }
            
            currentY += 30 // 2 Zeilen Abstand zwischen Absender-Zeile und Anschrift des Mieters
            
            // Mieter-Anschrift (für Fensterumschlag)
            let mieterStrasse = wohnung.strasse ?? haus.hausBezeichnung
            let mieterPLZ = wohnung.plz ?? haus.postleitzahl ?? ""
            let mieterOrt = wohnung.ort ?? haus.ort ?? ""
            let mieterName = wohnung.name ?? ""
            
            let mieterAnschriftX = margin
            var mieterAnschriftY = currentY
            
            // Datum rechts ausrichten
            let heute = Date()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd.MM.yyyy"
            let tagesdatum = dateFormatter.string(from: heute)
            let datumAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10)
            ]
            let datumAttributedString = NSAttributedString(string: tagesdatum, attributes: datumAttributes)
            let datumSize = datumAttributedString.size()
            let datumRect = CGRect(x: margin + contentWidth - datumSize.width, y: mieterAnschriftY, width: datumSize.width, height: 15)
            datumAttributedString.draw(in: datumRect)
            
            if !mieterName.isEmpty {
                let nameAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 11)
                ]
                let nameAttributedString = NSAttributedString(string: mieterName, attributes: nameAttributes)
                let nameRect = CGRect(x: mieterAnschriftX, y: mieterAnschriftY, width: contentWidth / 2, height: 15)
                nameAttributedString.draw(in: nameRect)
                mieterAnschriftY += 15
            }
            
            if !mieterStrasse.isEmpty {
                let strasseAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10)
                ]
                let strasseAttributedString = NSAttributedString(string: mieterStrasse, attributes: strasseAttributes)
                let strasseRect = CGRect(x: mieterAnschriftX, y: mieterAnschriftY, width: contentWidth / 2, height: 15)
                strasseAttributedString.draw(in: strasseRect)
                mieterAnschriftY += 15
            }
            
            // Ort ohne Datum
            let ortText = "\(mieterPLZ) \(mieterOrt)"
            let ortAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10)
            ]
            let ortAttributedString = NSAttributedString(string: ortText, attributes: ortAttributes)
            let ortRect = CGRect(x: mieterAnschriftX, y: mieterAnschriftY, width: contentWidth / 2, height: 15)
            ortAttributedString.draw(in: ortRect)
            
            currentY = max(currentY, mieterAnschriftY) + 90 // 6 Zeilen Abstand (3 Zeilen mehr) zwischen Anschrift und Überschrift
            
            // Überschrift: Nebenkostenabrechnung für [Straße] [Ort] und Jahreszahl
            let hausStrasse = haus.hausBezeichnung
            let hausOrt = haus.ort ?? ""
            let ueberschriftText = "Nebenkostenabrechnung für \(hausStrasse) \(hausOrt)"
            let ueberschriftAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 16)
            ]
            let ueberschriftAttributedString = NSAttributedString(string: ueberschriftText, attributes: ueberschriftAttributes)
            let ueberschriftRect = CGRect(x: margin, y: currentY, width: contentWidth, height: 20)
            ueberschriftAttributedString.draw(in: ueberschriftRect)
            currentY += 25
            
            let jahrText = "Abrechnungsjahr: \(haus.abrechnungsJahr)"
            let jahrAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 14)
            ]
            let jahrAttributedString = NSAttributedString(string: jahrText, attributes: jahrAttributes)
            let jahrRect = CGRect(x: margin, y: currentY, width: contentWidth, height: 18)
            jahrAttributedString.draw(in: jahrRect)
            currentY += 25
            
            // Mietzeiträume Gesamtübersicht
            currentY = addMietzeitraeumeGesamtuebersicht(
                context: context,
                startY: currentY,
                margin: margin,
                contentWidth: contentWidth,
                alleMietzeitraeume: alleMietzeitraeumeGesamt,
                alleLeerstaende: alleLeerstaende,
                pageWidth: pageWidth,
                pageHeight: pageHeight
            )
            
            // Abrechnung Wohnung
            currentY = addWohnungsAbrechnung(
                context: context,
                startY: currentY,
                margin: margin,
                contentWidth: contentWidth,
                wohnung: wohnung,
                mietzeitraeume: mietzeitraeume,
                mitmieter: mitmieter,
                zaehlerstaende: zaehlerstaende,
                kosten: kosten,
                gesamtPersonentage: gesamtPersonentage,
                gesamtQm: gesamtQm,
                gesamtVerbrauch: gesamtVerbrauch,
                anzahlWohnungen: anzahlWohnungen,
                personentageWohnung: personentageWohnung,
                verbrauchWohnung: verbrauchWohnung,
                tageWohnung: tageWohnung,
                jahresTage: jahresTage,
                pageWidth: pageWidth,
                pageHeight: pageHeight
            )
        }
        
        // Prüfe ob PDF-Daten generiert wurden
        guard data.count > 0 else {
            print("❌ PDF-Generierung: Leere Daten zurückgegeben")
            return nil
        }
        
        print("✅ PDF-Generierung erfolgreich: \(data.count) Bytes")
        return data
        #elseif os(macOS)
        // macOS: PDF-Generierung noch nicht implementiert
        return nil
        #endif
    }
    
    #if os(iOS) || os(tvOS)
    /// Zeichnet diagonal „Muster Rechnung - Bitte Vollversion kaufen“ auf die aktuelle Seite (nur wenn keine Vollversion).
    private static func drawMusterWatermark(context: UIGraphicsPDFRendererContext, pageWidth: CGFloat, pageHeight: CGFloat) {
        let ctx = context.cgContext
        UIGraphicsPushContext(ctx)
        ctx.saveGState()
        ctx.translateBy(x: pageWidth / 2, y: pageHeight / 2)
        ctx.rotate(by: -35 * CGFloat.pi / 180)
        let text = "Muster Rechnung – Bitte Vollversion kaufen"
        let font = UIFont.boldSystemFont(ofSize: 28)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.red.withAlphaComponent(0.45)
        ]
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let size = attrStr.size()
        attrStr.draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2))
        ctx.restoreGState()
        UIGraphicsPopContext()
    }
    
    private static func addMietzeitraeumeGesamtuebersicht(
        context: UIGraphicsPDFRendererContext,
        startY: CGFloat,
        margin: CGFloat,
        contentWidth: CGFloat,
        alleMietzeitraeume: [Mietzeitraum],
        alleLeerstaende: [Leerstand],
        pageWidth: CGFloat,
        pageHeight: CGFloat
    ) -> CGFloat {
        var currentY = startY
        
        // Überschrift (kleinere Schrift für Fensterumschlag / Platzersparnis)
        let ueberschriftText = "Mietzeiträume - Gesamtübersicht"
        let ueberschriftAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 11)
        ]
        let ueberschriftAttributedString = NSAttributedString(string: ueberschriftText, attributes: ueberschriftAttributes)
        let ueberschriftRect = CGRect(x: margin, y: currentY, width: contentWidth, height: 14)
        ueberschriftAttributedString.draw(in: ueberschriftRect)
        currentY += 16
        
        // Gesamtmiettage
        let gesamtLeerstandTage = alleLeerstaende.reduce(0) { $0 + $1.tage }
        let gesamtPersonentage = alleMietzeitraeume.reduce(0.0) { sum, m in
            let tage = calculateDays(from: m.vonDatum, to: m.bisDatum)
            return sum + Double(tage) * m.anzahlPersonen
        } + Double(gesamtLeerstandTage)
        
        let gesamtText = "Gesamtmiettage: \(formatPersonentagePDF(gesamtPersonentage)) Personentag(e)"
        let gesamtAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 10)
        ]
        let gesamtAttributedString = NSAttributedString(string: gesamtText, attributes: gesamtAttributes)
        let gesamtRect = CGRect(x: margin, y: currentY, width: contentWidth, height: 12)
        gesamtAttributedString.draw(in: gesamtRect)
        currentY += 14
        
        // Gruppiere nach Hauptmieter
        let gruppierteMietzeitraeume = Dictionary(grouping: alleMietzeitraeume) { $0.hauptmieterName }
        
        for hauptmieterName in gruppierteMietzeitraeume.keys.sorted() {
            if let zeitraeume = gruppierteMietzeitraeume[hauptmieterName] {
                // Prüfe ob neue Seite nötig
                if currentY > pageHeight - 100 {
                    context.beginPage()
                    if !LimitManager.shared.isPremium { Self.drawMusterWatermark(context: context, pageWidth: pageWidth, pageHeight: pageHeight) }
                    currentY = margin
                }
                
                let hauptmieterText = hauptmieterName
                let hauptmieterAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 10)
                ]
                let hauptmieterAttributedString = NSAttributedString(string: hauptmieterText, attributes: hauptmieterAttributes)
                let hauptmieterRect = CGRect(x: margin, y: currentY, width: contentWidth, height: 12)
                hauptmieterAttributedString.draw(in: hauptmieterRect)
                currentY += 14
                
                let gesamtPersonentageHauptmieter = zeitraeume.reduce(0.0) { sum, m in
                    let tage = calculateDays(from: m.vonDatum, to: m.bisDatum)
                    return sum + Double(tage) * m.anzahlPersonen
                }
                
                let gesamtHauptmieterText = "Gesamt: \(formatPersonentagePDF(gesamtPersonentageHauptmieter)) Personentag(e)"
                let gesamtHauptmieterAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 9)
                ]
                let gesamtHauptmieterAttributedString = NSAttributedString(string: gesamtHauptmieterText, attributes: gesamtHauptmieterAttributes)
                let gesamtHauptmieterRect = CGRect(x: margin + 20, y: currentY, width: contentWidth - 20, height: 11)
                gesamtHauptmieterAttributedString.draw(in: gesamtHauptmieterRect)
                currentY += 13
                
                // Einzelne Zeiträume (kleinere Schrift)
                for mietzeitraum in zeitraeume.sorted(by: { $0.vonDatum < $1.vonDatum }) {
                    if currentY > pageHeight - 80 {
                        context.beginPage()
                        if !LimitManager.shared.isPremium { Self.drawMusterWatermark(context: context, pageWidth: pageWidth, pageHeight: pageHeight) }
                        currentY = margin
                    }
                    
                    let tage = calculateDays(from: mietzeitraum.vonDatum, to: mietzeitraum.bisDatum)
                    let personentage = Double(tage) * mietzeitraum.anzahlPersonen
                    let personenText = mietzeitraum.personenBeschreibung.map { " (\($0))" } ?? ""
                    
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "dd.MM.yyyy"
                    guard let vonDate = isoToDate(mietzeitraum.vonDatum),
                          let bisDate = isoToDate(mietzeitraum.bisDatum) else {
                        continue
                    }
                    let vonStr = dateFormatter.string(from: vonDate)
                    let bisStr = dateFormatter.string(from: bisDate)
                    
                    let zeitraumText = "\(vonStr) - \(bisStr): \(tage) Tag(e) × \(formatPersonenAnzahlPDF(mietzeitraum.anzahlPersonen)) \(personenEinheitAnzeigePDF(mietzeitraum.anzahlPersonen))\(personenText) = \(formatPersonentagePDF(personentage)) Personentag(e)"
                    let zeitraumAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 8)
                    ]
                    let zeitraumAttributedString = NSAttributedString(string: zeitraumText, attributes: zeitraumAttributes)
                    let zeitraumRect = CGRect(x: margin + 20, y: currentY, width: contentWidth - 20, height: 11)
                    zeitraumAttributedString.draw(in: zeitraumRect)
                    currentY += 12
                }
                
                currentY += 3
            }
        }
        
        // Leerstände
        if !alleLeerstaende.isEmpty {
            if currentY > pageHeight - 60 {
                context.beginPage()
                if !LimitManager.shared.isPremium { Self.drawMusterWatermark(context: context, pageWidth: pageWidth, pageHeight: pageHeight) }
                currentY = margin
            }
            
            let leerstandUeberschriftText = "Leerstände (Vermieter):"
            let leerstandUeberschriftAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 10)
            ]
            let leerstandUeberschriftAttributedString = NSAttributedString(string: leerstandUeberschriftText, attributes: leerstandUeberschriftAttributes)
            let leerstandUeberschriftRect = CGRect(x: margin, y: currentY, width: contentWidth, height: 12)
            leerstandUeberschriftAttributedString.draw(in: leerstandUeberschriftRect)
            currentY += 14
            
            for leerstand in alleLeerstaende {
                if currentY > pageHeight - 50 {
                    context.beginPage()
                    if !LimitManager.shared.isPremium { Self.drawMusterWatermark(context: context, pageWidth: pageWidth, pageHeight: pageHeight) }
                    currentY = margin
                }
                
                let leerstandText = "Wohnung \(leerstand.wohnungsnummer ?? ""): \(leerstand.vonDatum) - \(leerstand.bisDatum) (\(leerstand.tage) Tag(e))"
                let leerstandAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 8)
                ]
                let leerstandAttributedString = NSAttributedString(string: leerstandText, attributes: leerstandAttributes)
                let leerstandRect = CGRect(x: margin + 20, y: currentY, width: contentWidth - 20, height: 11)
                leerstandAttributedString.draw(in: leerstandRect)
                currentY += 12
            }
        }
        
        return currentY + 20
    }
    
    private static func addWohnungsAbrechnung(
        context: UIGraphicsPDFRendererContext,
        startY: CGFloat,
        margin: CGFloat,
        contentWidth: CGFloat,
        wohnung: Wohnung,
        mietzeitraeume: [Mietzeitraum],
        mitmieter: [Int64: [Mitmieter]],
        zaehlerstaende: [Zaehlerstand],
        kosten: [Kosten],
        gesamtPersonentage: Double,
        gesamtQm: Int,
        gesamtVerbrauch: [String: Double],
        anzahlWohnungen: Int,
        personentageWohnung: Double,
        verbrauchWohnung: [String: Double],
        tageWohnung: Int,
        jahresTage: Int,
        pageWidth: CGFloat,
        pageHeight: CGFloat
    ) -> CGFloat {
        var currentY = startY
        
        // Prüfe ob neue Seite nötig
        if currentY > pageHeight - 100 {
            context.beginPage()
            if !LimitManager.shared.isPremium { Self.drawMusterWatermark(context: context, pageWidth: pageWidth, pageHeight: pageHeight) }
            currentY = margin
        }
        
        // Wohnungs-Header
        let wohnungHeaderText = "Abrechnung Wohnung"
        let wohnungHeaderAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14)
        ]
        let wohnungHeaderAttributedString = NSAttributedString(string: wohnungHeaderText, attributes: wohnungHeaderAttributes)
        let wohnungHeaderRect = CGRect(x: margin, y: currentY, width: contentWidth, height: 18)
        wohnungHeaderAttributedString.draw(in: wohnungHeaderRect)
        currentY += 20
        
        if let nummer = wohnung.wohnungsnummer, !nummer.isEmpty {
            let nummerText = "Wohnung Nr. \(nummer)"
            let nummerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 12)
            ]
            let nummerAttributedString = NSAttributedString(string: nummerText, attributes: nummerAttributes)
            let nummerRect = CGRect(x: margin, y: currentY, width: contentWidth, height: 16)
            nummerAttributedString.draw(in: nummerRect)
            currentY += 18
        }
        
        let bezeichnungText = wohnung.bezeichnung
        let bezeichnungAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11)
        ]
        let bezeichnungAttributedString = NSAttributedString(string: bezeichnungText, attributes: bezeichnungAttributes)
        let bezeichnungRect = CGRect(x: margin, y: currentY, width: contentWidth, height: 14)
        bezeichnungAttributedString.draw(in: bezeichnungRect)
        currentY += 16
        
        if let name = wohnung.name {
            let nameText = "Mieter: \(name)"
            let nameAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 11)
            ]
            let nameAttributedString = NSAttributedString(string: nameText, attributes: nameAttributes)
            let nameRect = CGRect(x: margin, y: currentY, width: contentWidth, height: 14)
            nameAttributedString.draw(in: nameRect)
            currentY += 16
        }
        
        let qmText = "\(wohnung.qm) m²"
        let qmAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10)
        ]
        let qmAttributedString = NSAttributedString(string: qmText, attributes: qmAttributes)
        let qmRect = CGRect(x: margin, y: currentY, width: contentWidth, height: 12)
        qmAttributedString.draw(in: qmRect)
        currentY += 20
        
        // Mietzeiträume
        if !mietzeitraeume.isEmpty {
            if currentY > pageHeight - 100 {
                context.beginPage()
                if !LimitManager.shared.isPremium { Self.drawMusterWatermark(context: context, pageWidth: pageWidth, pageHeight: pageHeight) }
                currentY = margin
            }
            
            let mietzeitraeumeHeaderText = "Mietzeiträume"
            let mietzeitraeumeHeaderAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 12)
            ]
            let mietzeitraeumeHeaderAttributedString = NSAttributedString(string: mietzeitraeumeHeaderText, attributes: mietzeitraeumeHeaderAttributes)
            let mietzeitraeumeHeaderRect = CGRect(x: margin, y: currentY, width: contentWidth, height: 16)
            mietzeitraeumeHeaderAttributedString.draw(in: mietzeitraeumeHeaderRect)
            currentY += 18
            
            let gruppierteMietzeitraeume = Dictionary(grouping: mietzeitraeume) { $0.hauptmieterName }
            
            for hauptmieterName in gruppierteMietzeitraeume.keys.sorted() {
                if let zeitraeume = gruppierteMietzeitraeume[hauptmieterName] {
                    if currentY > pageHeight - 80 {
                        context.beginPage()
                        if !LimitManager.shared.isPremium { Self.drawMusterWatermark(context: context, pageWidth: pageWidth, pageHeight: pageHeight) }
                        currentY = margin
                    }
                    
                    let hauptmieterText = hauptmieterName
                    let hauptmieterAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.boldSystemFont(ofSize: 11)
                    ]
                    let hauptmieterAttributedString = NSAttributedString(string: hauptmieterText, attributes: hauptmieterAttributes)
                    let hauptmieterRect = CGRect(x: margin, y: currentY, width: contentWidth, height: 15)
                    hauptmieterAttributedString.draw(in: hauptmieterRect)
                    currentY += 17
                    
                    let gesamtPersonentageHauptmieter = zeitraeume.reduce(0.0) { sum, m in
                        let tage = calculateDays(from: m.vonDatum, to: m.bisDatum)
                        return sum + Double(tage) * m.anzahlPersonen
                    }
                    
                    let gesamtText = "Gesamt: \(formatPersonentagePDF(gesamtPersonentageHauptmieter)) Personentag(e)"
                    let gesamtAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 10)
                    ]
                    let gesamtAttributedString = NSAttributedString(string: gesamtText, attributes: gesamtAttributes)
                    let gesamtRect = CGRect(x: margin + 20, y: currentY, width: contentWidth - 20, height: 14)
                    gesamtAttributedString.draw(in: gesamtRect)
                    currentY += 16
                    
                    for mietzeitraum in zeitraeume.sorted(by: { $0.vonDatum < $1.vonDatum }) {
                        if currentY > pageHeight - 80 {
                            context.beginPage()
                            if !LimitManager.shared.isPremium { Self.drawMusterWatermark(context: context, pageWidth: pageWidth, pageHeight: pageHeight) }
                            currentY = margin
                        }
                        
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "dd.MM.yyyy"
                        guard let vonDate = isoToDate(mietzeitraum.vonDatum),
                              let bisDate = isoToDate(mietzeitraum.bisDatum) else {
                            continue
                        }
                        let vonStr = dateFormatter.string(from: vonDate)
                        let bisStr = dateFormatter.string(from: bisDate)
                        let tage = calculateDays(from: mietzeitraum.vonDatum, to: mietzeitraum.bisDatum)
                        let personentage = Double(tage) * mietzeitraum.anzahlPersonen
                        let personenText = mietzeitraum.personenBeschreibung.map { " (\($0))" } ?? ""
                        
                        let zeitraumText = "Hauptmieter: \(vonStr) - \(bisStr), \(tage) Tag(e), \(formatPersonenAnzahlPDF(mietzeitraum.anzahlPersonen)) \(personenEinheitAnzeigePDF(mietzeitraum.anzahlPersonen))\(personenText), \(formatPersonentagePDF(personentage)) Personentag(e)"
                        let zeitraumAttributes: [NSAttributedString.Key: Any] = [
                            .font: UIFont.systemFont(ofSize: 9)
                        ]
                        let zeitraumAttributedString = NSAttributedString(string: zeitraumText, attributes: zeitraumAttributes)
                        let zeitraumRect = CGRect(x: margin + 20, y: currentY, width: contentWidth - 20, height: 12)
                        zeitraumAttributedString.draw(in: zeitraumRect)
                        currentY += 14
                        
                        // Mitmieter
                        if let mitmieterListe = mitmieter[mietzeitraum.id] {
                            for mitmieterItem in mitmieterListe {
                                if currentY > pageHeight - 50 {
                                    context.beginPage()
                                    if !LimitManager.shared.isPremium { Self.drawMusterWatermark(context: context, pageWidth: pageWidth, pageHeight: pageHeight) }
                                    currentY = margin
                                }
                                
                                guard let mitmieterVonDate = isoToDate(mitmieterItem.vonDatum),
                                      let mitmieterBisDate = isoToDate(mitmieterItem.bisDatum) else {
                                    continue
                                }
                                let mitmieterVonStr = dateFormatter.string(from: mitmieterVonDate)
                                let mitmieterBisStr = dateFormatter.string(from: mitmieterBisDate)
                                
                                let mitmieterText = "Mitmieter: \(mitmieterItem.name), \(mitmieterVonStr) - \(mitmieterBisStr)"
                                let mitmieterAttributes: [NSAttributedString.Key: Any] = [
                                    .font: UIFont.systemFont(ofSize: 9)
                                ]
                                let mitmieterAttributedString = NSAttributedString(string: mitmieterText, attributes: mitmieterAttributes)
                                let mitmieterRect = CGRect(x: margin + 40, y: currentY, width: contentWidth - 40, height: 12)
                                mitmieterAttributedString.draw(in: mitmieterRect)
                                currentY += 12
                            }
                        }
                    }
                    
                    currentY += 5
                }
            }
            
            currentY += 10
        }
        
        // Zählerstände
        if !zaehlerstaende.isEmpty {
            if currentY > pageHeight - 100 {
                context.beginPage()
                if !LimitManager.shared.isPremium { Self.drawMusterWatermark(context: context, pageWidth: pageWidth, pageHeight: pageHeight) }
                currentY = margin
            }
            
            let zaehlerHeaderText = "Zählerstände"
            let zaehlerHeaderAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 12)
            ]
            let zaehlerHeaderAttributedString = NSAttributedString(string: zaehlerHeaderText, attributes: zaehlerHeaderAttributes)
            let zaehlerHeaderRect = CGRect(x: margin, y: currentY, width: contentWidth, height: 16)
            zaehlerHeaderAttributedString.draw(in: zaehlerHeaderRect)
            currentY += 18
            
            for zaehlerstand in zaehlerstaende {
                if currentY > pageHeight - 50 {
                    context.beginPage()
                    if !LimitManager.shared.isPremium { Self.drawMusterWatermark(context: context, pageWidth: pageWidth, pageHeight: pageHeight) }
                    currentY = margin
                }
                
                var zaehlerText = "\(zaehlerstand.zaehlerTyp): \(String(format: "%.2f", zaehlerstand.zaehlerStart)) → \(String(format: "%.2f", zaehlerstand.zaehlerEnde))"
                if zaehlerstand.auchAbwasser == true {
                    zaehlerText += " (auch Abwasser)"
                }
                if let beschreibung = zaehlerstand.beschreibung, !beschreibung.isEmpty {
                    zaehlerText += " (\(beschreibung))"
                }
                zaehlerText += ", Diff: \(String(format: "%.2f", zaehlerstand.differenz))"
                
                let zaehlerAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 9)
                ]
                let zaehlerAttributedString = NSAttributedString(string: zaehlerText, attributes: zaehlerAttributes)
                let zaehlerRect = CGRect(x: margin + 20, y: currentY, width: contentWidth - 20, height: 12)
                zaehlerAttributedString.draw(in: zaehlerRect)
                currentY += 14
            }
            
            currentY += 10
        }
        
        // Kostenpositionen
        if !kosten.isEmpty {
            if currentY > pageHeight - 100 {
                context.beginPage()
                if !LimitManager.shared.isPremium { Self.drawMusterWatermark(context: context, pageWidth: pageWidth, pageHeight: pageHeight) }
                currentY = margin
            }
            
            let kostenHeaderText = "Kostenpositionen"
            let kostenHeaderAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 12)
            ]
            let kostenHeaderAttributedString = NSAttributedString(string: kostenHeaderText, attributes: kostenHeaderAttributes)
            let kostenHeaderRect = CGRect(x: margin, y: currentY, width: contentWidth, height: 16)
            kostenHeaderAttributedString.draw(in: kostenHeaderRect)
            currentY += 18
            
            var gesamtAnteil: Double = 0
            let sortierteKosten = kosten.sorted { k1, k2 in
                let minus1 = (k1.kostenart == .vorauszahlung)
                let minus2 = (k2.kostenart == .vorauszahlung)
                if minus1 != minus2 { return minus2 }
                return k1.kostenart.rawValue < k2.kostenart.rawValue
            }
            
            for kostenItem in sortierteKosten {
                if currentY > pageHeight - 100 {
                    context.beginPage()
                    if !LimitManager.shared.isPremium { Self.drawMusterWatermark(context: context, pageWidth: pageWidth, pageHeight: pageHeight) }
                    currentY = margin
                }
                
                // Vor der Vorauszahlung (Minus-Wert) eine Gesamtsumme ausgeben (Betrag rechtsbündig)
                if kostenItem.kostenart == .vorauszahlung {
                    let gesamtsummeLabel = "Gesamtsumme:"
                    let gesamtsummeLabelAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.boldSystemFont(ofSize: 11),
                        .foregroundColor: UIColor.black
                    ]
                    let gesamtsummeLabelAttributedString = NSAttributedString(string: gesamtsummeLabel, attributes: gesamtsummeLabelAttributes)
                    let gesamtsummeLabelRect = CGRect(x: margin, y: currentY, width: contentWidth / 2, height: 14)
                    gesamtsummeLabelAttributedString.draw(in: gesamtsummeLabelRect)
                    let gesamtsummeWertText = "\(String(format: "%.2f", gesamtAnteil)) €"
                    let gesamtsummeWertAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.boldSystemFont(ofSize: 11),
                        .foregroundColor: UIColor.black
                    ]
                    let gesamtsummeWertAttributedString = NSAttributedString(string: gesamtsummeWertText, attributes: gesamtsummeWertAttributes)
                    let gesamtsummeWertSize = gesamtsummeWertAttributedString.size()
                    let gesamtsummeWertRect = CGRect(x: margin + contentWidth - gesamtsummeWertSize.width, y: currentY, width: gesamtsummeWertSize.width, height: 14)
                    gesamtsummeWertAttributedString.draw(in: gesamtsummeWertRect)
                    currentY += 18
                }
                
                let anteil = berechneKostenanteil(
                    kostenItem: kostenItem,
                    personentageWohnung: personentageWohnung,
                    qmWohnung: wohnung.qm,
                    verbrauchWohnung: verbrauchWohnung,
                    wohnungId: wohnung.id,
                    tageWohnung: tageWohnung,
                    jahresTage: jahresTage,
                    gesamtPersonentage: gesamtPersonentage,
                    gesamtQm: gesamtQm,
                    gesamtVerbrauch: gesamtVerbrauch,
                    anzahlWohnungen: anzahlWohnungen
                )
                
                gesamtAnteil += anteil
                
                // Kostenart (fett)
                let kostenartText = kostenItem.kostenart.rawValue
                let kostenartAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 10)
                ]
                let kostenartAttributedString = NSAttributedString(string: kostenartText, attributes: kostenartAttributes)
                let kostenartRect = CGRect(x: margin, y: currentY, width: contentWidth / 2, height: 14)
                kostenartAttributedString.draw(in: kostenartRect)
                
                // Betrag rechts
                let anteilText = "\(String(format: "%.2f", anteil)) €"
                let anteilAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 10),
                    .foregroundColor: anteil < 0 ? UIColor.red : UIColor.black
                ]
                let anteilAttributedString = NSAttributedString(string: anteilText, attributes: anteilAttributes)
                let anteilSize = anteilAttributedString.size()
                let anteilRect = CGRect(x: margin + contentWidth - anteilSize.width, y: currentY, width: anteilSize.width, height: 14)
                anteilAttributedString.draw(in: anteilRect)
                currentY += 16
                
                // Bezeichnung (falls vorhanden)
                if let bezeichnung = kostenItem.bezeichnung, !bezeichnung.isEmpty {
                    let bezeichnungText = bezeichnung
                    let bezeichnungAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 9),
                        .foregroundColor: UIColor.gray
                    ]
                    let bezeichnungAttributedString = NSAttributedString(string: bezeichnungText, attributes: bezeichnungAttributes)
                    let bezeichnungRect = CGRect(x: margin + 20, y: currentY, width: contentWidth - 20, height: 12)
                    bezeichnungAttributedString.draw(in: bezeichnungRect)
                    currentY += 14
                }
                
                // Verteilung
                let verteilungText = "Verteilung: \(kostenItem.verteilungsart.rawValue)"
                let verteilungAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 9),
                    .foregroundColor: UIColor.gray
                ]
                let verteilungAttributedString = NSAttributedString(string: verteilungText, attributes: verteilungAttributes)
                let verteilungRect = CGRect(x: margin + 20, y: currentY, width: contentWidth - 20, height: 12)
                verteilungAttributedString.draw(in: verteilungRect)
                currentY += 14
                
                // Tage-Anzeige (nur für nachQm und nachWohneinheiten)
                let zeigtTage = (kostenItem.verteilungsart == .nachQm || kostenItem.verteilungsart == .nachWohneinheiten)
                if zeigtTage {
                    let tageText = "\(tageWohnung) Tag(e) von \(jahresTage) Tag(en)"
                    let tageAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 9),
                        .foregroundColor: UIColor.gray
                    ]
                    let tageAttributedString = NSAttributedString(string: tageText, attributes: tageAttributes)
                    let tageRect = CGRect(x: margin + 20, y: currentY, width: contentWidth - 20, height: 12)
                    tageAttributedString.draw(in: tageRect)
                    currentY += 14
                }
                
                // Formel
                let formel = berechneFormel(
                    kostenItem: kostenItem,
                    personentageWohnung: personentageWohnung,
                    qmWohnung: wohnung.qm,
                    verbrauchWohnung: verbrauchWohnung,
                    tageWohnung: tageWohnung,
                    jahresTage: jahresTage,
                    gesamtPersonentage: gesamtPersonentage,
                    gesamtQm: gesamtQm,
                    gesamtVerbrauch: gesamtVerbrauch,
                    anzahlWohnungen: anzahlWohnungen
                )
                let formelAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.italicSystemFont(ofSize: 9),
                    .foregroundColor: UIColor.gray
                ]
                let formelAttributedString = NSAttributedString(string: formel, attributes: formelAttributes)
                let formelRect = CGRect(x: margin + 20, y: currentY, width: contentWidth - 20, height: 12)
                formelAttributedString.draw(in: formelRect)
                currentY += 16
                
                currentY += 5
            }
            
            // Gesamtanteil
            if currentY > pageHeight - 50 {
                context.beginPage()
                if !LimitManager.shared.isPremium { Self.drawMusterWatermark(context: context, pageWidth: pageWidth, pageHeight: pageHeight) }
                currentY = margin
            }
            
            let gesamtText = "Gesamtanteil: \(String(format: "%.2f", gesamtAnteil)) €"
            let gesamtAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 12),
                .foregroundColor: gesamtAnteil < 0 ? UIColor.red : UIColor.black
            ]
            let gesamtAttributedString = NSAttributedString(string: gesamtText, attributes: gesamtAttributes)
            let gesamtRect = CGRect(x: margin, y: currentY, width: contentWidth, height: 16)
            gesamtAttributedString.draw(in: gesamtRect)
            currentY += 20
            
            // Zahlungshinweis basierend auf Gesamtanteil
            let zahlungshinweisText: String
            if gesamtAnteil < 0 {
                zahlungshinweisText = "Der Betrag wird Ihnen in den nächsten Tagen überwiesen"
            } else {
                zahlungshinweisText = "Bitte überweisen Sie den Betrag in den nächsten Tagen"
            }
            let zahlungshinweisAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11)
            ]
            let zahlungshinweisAttributedString = NSAttributedString(string: zahlungshinweisText, attributes: zahlungshinweisAttributes)
            let zahlungshinweisRect = CGRect(x: margin, y: currentY, width: contentWidth, height: 14)
            zahlungshinweisAttributedString.draw(in: zahlungshinweisRect)
            currentY += 18
        }
        
        return currentY
    }
    #endif
    
    private static func berechneKostenanteil(
        kostenItem: Kosten,
        personentageWohnung: Double,
        qmWohnung: Int,
        verbrauchWohnung: [String: Double],
        wohnungId: Int64,
        tageWohnung: Int,
        jahresTage: Int,
        gesamtPersonentage: Double,
        gesamtQm: Int,
        gesamtVerbrauch: [String: Double],
        anzahlWohnungen: Int
    ) -> Double {
        switch kostenItem.verteilungsart {
        case .nachPersonen:
            if gesamtPersonentage > 0 {
                return (kostenItem.betrag / gesamtPersonentage) * personentageWohnung
            }
            return 0
            
        case .nachQm:
            if gesamtQm > 0 && jahresTage > 0 {
                let basisAnteil = (kostenItem.betrag / Double(gesamtQm)) * Double(qmWohnung)
                let zeitanteil = Double(tageWohnung) / Double(jahresTage)
                return basisAnteil * zeitanteil
            }
            return 0
            
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
            
            if gesamtVerbrauchTyp > 0 {
                return (kostenItem.betrag / gesamtVerbrauchTyp) * verbrauchWohnungTyp
            }
            return 0
            
        case .nachWohneinheiten:
            if anzahlWohnungen > 0 && jahresTage > 0 {
                let basisAnteil = kostenItem.betrag / Double(anzahlWohnungen)
                let zeitanteil = Double(tageWohnung) / Double(jahresTage)
                return basisAnteil * zeitanteil
            }
            return 0
            
        case .nachEinzelnachweis:
            if let einzelnachweis = DatabaseManager.shared.getEinzelnachweisWohnung(
                kostenId: kostenItem.id,
                wohnungId: wohnungId
            ), let betrag = einzelnachweis.betrag {
                return betrag
            }
            return kostenItem.betrag
        }
    }
    
    private static func berechneFormel(
        kostenItem: Kosten,
        personentageWohnung: Double,
        qmWohnung: Int,
        verbrauchWohnung: [String: Double],
        tageWohnung: Int,
        jahresTage: Int,
        gesamtPersonentage: Double,
        gesamtQm: Int,
        gesamtVerbrauch: [String: Double],
        anzahlWohnungen: Int
    ) -> String {
        switch kostenItem.verteilungsart {
        case .nachPersonen:
            return "\(String(format: "%.2f", kostenItem.betrag)) € / \(formatPersonentagePDF(gesamtPersonentage)) Personentage × \(formatPersonentagePDF(personentageWohnung)) Personentage"
            
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
    
    private static func calculateDays(from: String, to: String) -> Int {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        guard let fromDate = dateFormatter.date(from: from),
              let toDate = dateFormatter.date(from: to) else {
            return 0
        }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: fromDate, to: toDate)
        return (components.day ?? 0) + 1
    }
    
    private static func isoToDate(_ s: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter.date(from: s)
    }
}
