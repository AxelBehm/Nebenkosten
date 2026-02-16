//
//  WohnungDetailView.swift
//  Nebenkosten
//
//  Created by Axel Behm on 22.01.26.
//

import SwiftUI
import PhotosUI

/// Anschrift aus Haus (Straße, PLZ, Ort) standardmäßig übernehmen.
private func anschrift(from haus: HausAbrechnung) -> String {
    var parts: [String] = []
    if let plz = haus.postleitzahl, !plz.isEmpty { parts.append(plz) }
    if let ort = haus.ort, !ort.isEmpty { parts.append(ort) }
    if !haus.hausBezeichnung.isEmpty { parts.append(haus.hausBezeichnung) }
    return parts.joined(separator: ", ")
}

/// Anschrift für Wohnung: eigene Werte oder Default aus Haus
private func wohnungAnschrift(wohnung: Wohnung, haus: HausAbrechnung) -> String {
    var parts: [String] = []
    let plz = wohnung.plz ?? haus.postleitzahl
    let ort = wohnung.ort ?? haus.ort
    let strasse = wohnung.strasse ?? haus.hausBezeichnung
    if let plz = plz, !plz.isEmpty { parts.append(plz) }
    if let ort = ort, !ort.isEmpty { parts.append(ort) }
    if !strasse.isEmpty { parts.append(strasse) }
    return parts.joined(separator: ", ")
}

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

private func dateToISO(_ d: Date) -> String { isoDateFormatter.string(from: d) }
private func isoToDate(_ s: String) -> Date? { isoDateFormatter.date(from: s) }
private func isoToDeDatum(_ s: String) -> String? {
    guard let d = isoToDate(s) else { return nil }
    return deDateFormatter.string(from: d)
}

// Prüft ob ein Jahr gesperrt ist (wenn ein neueres Jahr existiert)
private func istJahrGesperrt(abrechnung: HausAbrechnung) -> Bool {
    return DatabaseManager.shared.istJahrGesperrt(hausBezeichnung: abrechnung.hausBezeichnung, jahr: abrechnung.abrechnungsJahr)
}

/// Steuert, ob das Mietzeitraum-Sheet für „Hinzufügen“ oder „Bearbeiten“ geöffnet ist (damit Fotos-ID zuverlässig ankommt).
private enum MietzeitraumSheetItem: Identifiable, Equatable {
    case add
    case edit(Mietzeitraum)
    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let m): return "edit-\(m.id)"
        }
    }
    var mietzeitraumIdForFotos: Int64? {
        if case .edit(let m) = self { return m.id }
        return nil
    }
    var isEdit: Bool {
        if case .edit = self { return true }
        return false
    }
}

struct WohnungDetailView: View {
    let wohnung: Wohnung
    let haus: HausAbrechnung
    @State private var mietzeitraeume: [Mietzeitraum] = []
    @State private var showAddMietzeitraum = false  // für onChange-Reload, Sheet nutzt mietzeitraumSheetItem
    @State private var mietzeitraumSheetItem: MietzeitraumSheetItem?
    @State private var editingMietzeitraum: Mietzeitraum?
    @State private var showDeleteMietzeitraum = false
    @State private var deletingMietzeitraum: Mietzeitraum?
    @State private var istGesperrt: Bool = false
    
    @State private var jahr = Calendar.current.component(.year, from: Date())
    @State private var vonDatum = Date()
    @State private var bisDatum = Date()
    @State private var anzahlPersonen: Int? = nil
    @State private var anzahlPersonenText = ""
    @State private var mietendeOption: MietendeOption = .mietendeOffen
    @State private var validierungsFehler: String? = nil
    @State private var showValidierungsFehler = false
    
    @State private var showAddMitmieter = false
    @State private var mietzeitraumFuerMitmieter: Mietzeitraum?
    @State private var mitmieterName = ""
    @State private var mitmieterVon = Date()
    @State private var mitmieterBis = Date()
    @State private var editingMitmieter: Mitmieter?
    @State private var showDeleteMitmieter = false
    @State private var deletingMitmieter: Mitmieter?
    @State private var mitmieterByMietzeitraum: [Int64: [Mitmieter]] = [:]
    @State private var mietzeitraumFotosByMietzeitraum: [Int64: [MietzeitraumFoto]] = [:]
    
    var body: some View {
        rootContent
    }
    
    @ViewBuilder
    private var listContent: some View {
        List {
            wohnungSection
            kontaktdatenSection
            #if os(iOS)
            vertraegeAnhaengeSection
            #endif
            mietzeitraeumeSection
        }
    }
    
    private var contentWithNav: some View {
        listContent
            .navigationTitle("Wohnung")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadMietzeitraeume()
                istGesperrt = istJahrGesperrt(abrechnung: haus)
            }
            .onChange(of: showAddMietzeitraum) { oldVal, newVal in
                if oldVal && !newVal { loadMietzeitraeume() }
            }
            .onChange(of: mietzeitraumSheetItem) { _, newVal in
                if newVal == nil { loadMietzeitraeume() }
            }
            .onChange(of: showAddMitmieter) { oldVal, newVal in
                if oldVal && !newVal { loadMietzeitraeume() }
            }
    }
    
    private var contentWithMitmieterSheet: some View {
        contentWithNav
            .sheet(isPresented: $showAddMitmieter) {
                AddMitmieterSheet(
                    istGesperrt: istGesperrt,
                    name: $mitmieterName,
                    vonDatum: $mitmieterVon,
                    bisDatum: $mitmieterBis,
                    isEdit: editingMitmieter != nil,
                    onSave: saveMitmieter,
                    onCancel: {
                        showAddMitmieter = false
                        editingMitmieter = nil
                        mietzeitraumFuerMitmieter = nil
                    }
                )
            }
            .alert("Mitmieter löschen?", isPresented: $showDeleteMitmieter) {
                Button("Abbrechen", role: .cancel) { deletingMitmieter = nil }
                Button("Löschen", role: .destructive) {
                    if let mm = deletingMitmieter, !istGesperrt {
                        _ = DatabaseManager.shared.deleteMitmieter(id: mm.id)
                        loadMietzeitraeume()
                        deletingMitmieter = nil
                    }
                }
            } message: {
                if let mm = deletingMitmieter {
                    Text("Mitmieter „\(mm.name)“ (\(mm.vonDatum) – \(mm.bisDatum)) löschen?")
                }
            }
    }
    
    @ViewBuilder
    private var rootContent: some View {
        contentWithMitmieterSheet
            .sheet(item: $mietzeitraumSheetItem) { item in
            AddMietzeitraumSheetWithFotos(
                istGesperrt: istGesperrt,
                hauptmieterName: wohnung.name ?? "",
                jahr: $jahr,
                abrechnungsJahr: haus.abrechnungsJahr,
                vonDatum: $vonDatum,
                bisDatum: $bisDatum,
                anzahlPersonenText: $anzahlPersonenText,
                mietendeOption: $mietendeOption,
                isEdit: item.isEdit,
                onSave: { dismiss in
                    // Validierung: Prüfe, ob Daten im Abrechnungsjahr liegen
                    let vonDatumISO = dateToISO(vonDatum)
                    let bisDatumISO = dateToISO(bisDatum)
                    let vonDatumJahr = Calendar.current.component(.year, from: vonDatum)
                    let bisDatumJahr = Calendar.current.component(.year, from: bisDatum)
                    
                    if vonDatumJahr != haus.abrechnungsJahr || bisDatumJahr != haus.abrechnungsJahr {
                        validierungsFehler = "Die Daten müssen im Abrechnungsjahr \(haus.abrechnungsJahr) liegen.\n\nVon-Datum: \(vonDatumISO) (Jahr: \(vonDatumJahr))\nBis-Datum: \(bisDatumISO) (Jahr: \(bisDatumJahr))"
                        showValidierungsFehler = true
                        return
                    }
                    
                    // Validierung: Anschlussmieter nur nach Auszug des vorherigen Mieters – keine überlappenden Zeiträume
                    if let ueberlappung = DatabaseManager.shared.getUeberlappendenMietzeitraum(
                        wohnungId: wohnung.id,
                        vonDatum: vonDatumISO,
                        bisDatum: bisDatumISO,
                        ausschliessenId: editingMietzeitraum?.id
                    ) {
                        validierungsFehler = "Anlage nicht möglich.\n\nBeim 1. Mieter (\(ueberlappung.hauptmieterName)) muss das Mietende (Auszugsdatum) geändert werden, damit der 2. Mieter vom Mietzeitraum her angefügt werden kann.\n\nBestehender Zeitraum: \(ueberlappung.vonDatum) – \(ueberlappung.bisDatum)\nEingegeben: \(vonDatumISO) – \(bisDatumISO)\n\nDer Einzug des Anschlussmieters muss nach dem Auszugsdatum (\(ueberlappung.bisDatum)) liegen (z. B. 1. Mieter bis 30.12., 2. Mieter ab 31.12.)."
                        showValidierungsFehler = true
                        return
                    }
                    
                    // Validierung: Prüfe, ob das neue Einzugsdatum genau auf den Tag nach dem letzten Auszugsdatum fällt
                    if let vorheriger = DatabaseManager.shared.getVorherigenMietzeitraum(
                        wohnungId: wohnung.id,
                        vorDatum: vonDatumISO,
                        ausschliessenId: editingMietzeitraum?.id
                    ) {
                        // Berechne das erwartete Einzugsdatum (Tag nach dem Auszugsdatum des vorherigen)
                        if let letztesAuszug = isoToDate(vorheriger.bisDatum),
                           let erwartetesEinzug = Calendar.current.date(byAdding: .day, value: 1, to: letztesAuszug) {
                            let erwartetesEinzugISO = dateToISO(erwartetesEinzug)
                            if vonDatumISO != erwartetesEinzugISO {
                                validierungsFehler = "Mietzeiträume müssen aneinander anschließen.\n\nVorheriger Mietzeitraum endet: \(vorheriger.bisDatum)\nErwartetes Einzugsdatum: \(erwartetesEinzugISO)\nEingegebenes Einzugsdatum: \(vonDatumISO)\n\nDas Einzugsdatum muss genau auf den Tag nach dem Auszugsdatum des vorherigen Mietzeitraums gesetzt werden."
                                showValidierungsFehler = true
                                return
                            }
                        }
                    } else {
                        // Kein vorheriger Mietzeitraum: Anschlussmieter nur nach Auszug – prüfe, ob ein bestehender Zeitraum noch überlappt
                        if let konflikt = DatabaseManager.shared.getConflictingMietzeitraum(
                            wohnungId: wohnung.id,
                            neuesVonDatum: vonDatumISO,
                            ausschliessenId: editingMietzeitraum?.id
                        ) {
                            validierungsFehler = "Anlage nicht möglich.\n\nBeim 1. Mieter (\(konflikt.hauptmieterName)) muss das Mietende (Auszugsdatum) geändert werden, damit der 2. Mieter vom Mietzeitraum her angefügt werden kann.\n\nAuszugsdatum 1. Mieter: \(konflikt.bisDatum)\nEingegebenes Einzugsdatum 2. Mieter: \(vonDatumISO)\n\nDer Einzug muss nach dem Auszug liegen (z. B. 1. Mieter bis 30.12., 2. Mieter ab 31.12.)."
                            showValidierungsFehler = true
                            return
                        }
                    }
                    
                    // Validierung: Prüfe, ob das Auszugsdatum genau auf den Tag vor dem nächsten Einzugsdatum fällt (beim Bearbeiten)
                    if editingMietzeitraum != nil {
                        if let naechster = DatabaseManager.shared.getNaechstenMietzeitraum(
                            wohnungId: wohnung.id,
                            nachDatum: bisDatumISO,
                            ausschliessenId: editingMietzeitraum?.id
                        ) {
                            // Berechne das erwartete Auszugsdatum (Tag vor dem Einzugsdatum des nächsten)
                            if let naechstesEinzug = isoToDate(naechster.vonDatum),
                               let erwartetesAuszug = Calendar.current.date(byAdding: .day, value: -1, to: naechstesEinzug) {
                                let erwartetesAuszugISO = dateToISO(erwartetesAuszug)
                                if bisDatumISO != erwartetesAuszugISO {
                                    validierungsFehler = "Mietzeiträume müssen aneinander anschließen.\n\nNächster Mietzeitraum beginnt: \(naechster.vonDatum)\nErwartetes Auszugsdatum: \(erwartetesAuszugISO)\nEingegebenes Auszugsdatum: \(bisDatumISO)\n\nDas Auszugsdatum muss genau auf den Tag vor dem Einzugsdatum des nächsten Mietzeitraums gesetzt werden."
                                    showValidierungsFehler = true
                                    return
                                }
                            }
                        }
                    }
                    
                    let anzahl = Int(anzahlPersonenText) ?? 0
                    
                    if anzahl <= 0 {
                        validierungsFehler = "Die Anzahl Personen muss größer als 0 sein."
                        showValidierungsFehler = true
                        return
                    }
                    
                    // Verwende immer das Abrechnungsjahr
                    let speicherJahr = haus.abrechnungsJahr
                    
                    if let e = editingMietzeitraum {
                        _ = DatabaseManager.shared.updateMietzeitraum(Mietzeitraum(
                            id: e.id, wohnungId: wohnung.id,
                            jahr: speicherJahr,
                            hauptmieterName: wohnung.name ?? "",
                            vonDatum: vonDatumISO, bisDatum: bisDatumISO,
                            anzahlPersonen: anzahl,
                            mietendeOption: mietendeOption
                        ))
                    } else {
                        _ = DatabaseManager.shared.insertMietzeitraum(Mietzeitraum(
                            wohnungId: wohnung.id,
                            jahr: speicherJahr,
                            hauptmieterName: wohnung.name ?? "",
                            vonDatum: vonDatumISO, bisDatum: bisDatumISO,
                            anzahlPersonen: anzahl,
                            mietendeOption: mietendeOption
                        ))
                    }
                    loadMietzeitraeume()
                    showAddMietzeitraum = false
                    editingMietzeitraum = nil
                    mietzeitraumSheetItem = nil
                    dismiss() // Form schließen nach erfolgreichem Speichern
                },
                onCancel: {
                    showAddMietzeitraum = false
                    editingMietzeitraum = nil
                    mietzeitraumSheetItem = nil
                }
            )
        }
        .alert("Validierungsfehler", isPresented: $showValidierungsFehler) {
            Button("OK", role: .cancel) { }
        } message: {
            if let fehler = validierungsFehler {
                Text(fehler)
            }
        }
        .alert("Mietzeitraum löschen?", isPresented: $showDeleteMietzeitraum) {
            Button("Abbrechen", role: .cancel) { deletingMietzeitraum = nil }
            Button("Löschen", role: .destructive) {
                if let m = deletingMietzeitraum {
                    if istGesperrt {
                        return
                    }
                    _ = DatabaseManager.shared.deleteMietzeitraum(id: m.id)
                    loadMietzeitraeume()
                    deletingMietzeitraum = nil
                }
            }
        } message: {
            if let m = deletingMietzeitraum {
                Text("Mietzeitraum „\(m.hauptmieterName)“ (\(m.vonDatum) – \(m.bisDatum)) und alle Mitmieter löschen?")
            }
        }
    }
    
    @ViewBuilder
    private var wohnungSection: some View {
        Section {
            if let nummer = wohnung.wohnungsnummer, !nummer.isEmpty {
                LabeledContent("Wohnungs-Nummer", value: nummer)
            }
            LabeledContent("z.B. Wohnung 1, 1. OG links", value: wohnung.bezeichnung)
            LabeledContent("m²", value: "\(wohnung.qm)")
        } header: {
            Text("Wohnung")
        }
    }
    
    @ViewBuilder
    private var vertraegeAnhaengeSection: some View {
        #if os(iOS)
        Section {
            ForEach(mietzeitraeume) { m in
                MietzeitraumFotosNurAnzeigeView(
                    mietzeitraum: m,
                    fotos: mietzeitraumFotosByMietzeitraum[m.id] ?? [],
                    onFotosChanged: loadMietzeitraeume
                )
            }
            if mietzeitraeume.isEmpty {
                Text("Zuerst in der Wohnungen-Übersicht ⋯ → Bearbeiten, Wohnung anlegen und Mietzeiträume erfassen. Verträge/Anhänge im Block „Verträge / Anhänge“ zuordnen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Verträge / Anhänge")
        } footer: {
            Text("Nur Anzeige. Zum Hinzufügen/Löschen/Bearbeiten: In der Wohnungen-Übersicht bei der Wohnung ⋯ → Bearbeiten, dann Block „Verträge / Anhänge“.")
        }
        #else
        EmptyView()
        #endif
    }
    
    @ViewBuilder
    private var kontaktdatenSection: some View {
        Section {
            if let name = wohnung.name, !name.isEmpty {
                LabeledContent("Name", value: name)
            }
            if let strasse = wohnung.strasse, !strasse.isEmpty {
                LabeledContent("Straße mit Hausnummer", value: strasse)
            } else if !haus.hausBezeichnung.isEmpty {
                LabeledContent("Straße mit Hausnummer", value: haus.hausBezeichnung)
                    .foregroundStyle(.secondary)
            }
            if let plz = wohnung.plz, !plz.isEmpty {
                LabeledContent("PLZ", value: plz)
            } else if let plz = haus.postleitzahl, !plz.isEmpty {
                LabeledContent("PLZ", value: plz)
                    .foregroundStyle(.secondary)
            }
            if let ort = wohnung.ort, !ort.isEmpty {
                LabeledContent("Ort", value: ort)
            } else if let ort = haus.ort, !ort.isEmpty {
                LabeledContent("Ort", value: ort)
                    .foregroundStyle(.secondary)
            }
            if let email = wohnung.email, !email.isEmpty {
                LabeledContent("E-Mail", value: email)
            }
            if let telefon = wohnung.telefon, !telefon.isEmpty {
                LabeledContent("Telefon", value: telefon)
            }
        } header: {
            Text("Kontaktdaten")
        } footer: {
            Text("Straße, PLZ und Ort werden standardmäßig aus dem Haus übernommen.")
        }
    }
    
    @ViewBuilder
    private var mietzeitraeumeSection: some View {
        Section {
            ForEach(mietzeitraeume) { m in
                mietzeitraumDisclosureGroup(m: m)
            }
            if mietzeitraeume.isEmpty {
                Text("Keine Mietzeiträume. Hauptmieter-Wechsel = neuer Satz.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Mietzeiträume (Hauptmieter + Mitmieter)")
        } footer: {
            Text("Pro Hauptmieter einen Mietzeitraum anlegen. Bei Wechsel des Hauptmieters neuen Satz anlegen. Mitmieter können in Teil-Zeiträumen erfasst werden.")
        }
    }
    
    @ViewBuilder
    private func mietzeitraumDisclosureGroup(m: Mietzeitraum) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(mitmieterByMietzeitraum[m.id] ?? []) { mm in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mm.name)
                                .font(.subheadline)
                            Text("\(mm.vonDatum) – \(mm.bisDatum)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
                if (mitmieterByMietzeitraum[m.id] ?? []).isEmpty {
                    Text("Keine Mitmieter")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hauptmieter: \(m.hauptmieterName)")
                        .font(.subheadline.weight(.medium))
                    Text("\(m.vonDatum) – \(m.bisDatum)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(m.anzahlPersonen) Person\(m.anzahlPersonen == 1 ? "" : "en")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if m.mietendeOption == .gekuendigtZumMietzeitende {
                        Text("Gekündigt zum Mietzeitende")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        }
    }
    
    private func loadMietzeitraeume() {
        mietzeitraeume = DatabaseManager.shared.getMietzeitraeume(byWohnungId: wohnung.id)
        mitmieterByMietzeitraum = Dictionary(uniqueKeysWithValues: mietzeitraeume.map { ($0.id, DatabaseManager.shared.getMitmieter(byMietzeitraumId: $0.id)) })
        mietzeitraumFotosByMietzeitraum = Dictionary(uniqueKeysWithValues: mietzeitraeume.map { ($0.id, DatabaseManager.shared.getMietzeitraumFotos(byMietzeitraumId: $0.id)) })
    }
    
    private func saveMitmieter() {
        if let e = editingMitmieter, let mz = mietzeitraumFuerMitmieter {
            _ = DatabaseManager.shared.updateMitmieter(Mitmieter(
                id: e.id, mietzeitraumId: mz.id,
                name: mitmieterName.trimmingCharacters(in: .whitespacesAndNewlines),
                vonDatum: dateToISO(mitmieterVon), bisDatum: dateToISO(mitmieterBis)
            ))
        } else if let mz = mietzeitraumFuerMitmieter {
            _ = DatabaseManager.shared.insertMitmieter(Mitmieter(
                mietzeitraumId: mz.id,
                name: mitmieterName.trimmingCharacters(in: .whitespacesAndNewlines),
                vonDatum: dateToISO(mitmieterVon), bisDatum: dateToISO(mitmieterBis)
            ))
        }
        loadMietzeitraeume()
        showAddMitmieter = false
        editingMitmieter = nil
        mietzeitraumFuerMitmieter = nil
    }
}

// MARK: - Mietzeitraum-Fotos (Verträge / Anhänge)

#if os(iOS)
private struct MietzeitraumFotoThumbnailView: View {
    let imagePath: String
    var body: some View {
        let url = DatabaseManager.shared.mietzeitraumFotoFullURL(imagePath: imagePath)
        if FileManager.default.fileExists(atPath: url.path),
           let img = UIImage(contentsOfFile: url.path) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipped()
                .cornerRadius(8)
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 80, height: 80)
                .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
        }
    }
}

private struct MietzeitraumFotoFullScreenView: View {
    let foto: MietzeitraumFoto
    /// true = nur Anzeige (z. B. aus Detail-Ansicht), kein Bearbeiten der Bezeichnung
    let readOnly: Bool
    @State private var bildbezeichnung: String
    let onBezeichnungSaved: () -> Void
    init(foto: MietzeitraumFoto, readOnly: Bool = false, onBezeichnungSaved: @escaping () -> Void) {
        self.foto = foto
        self.readOnly = readOnly
        self._bildbezeichnung = State(initialValue: foto.bildbezeichnung)
        self.onBezeichnungSaved = onBezeichnungSaved
    }
    var body: some View {
        VStack(spacing: 0) {
            if !readOnly {
                TextField("Bildbezeichnung", text: $bildbezeichnung, prompt: Text("Bezeichnung eingeben"))
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .onSubmit {
                        _ = DatabaseManager.shared.updateMietzeitraumFotoBezeichnung(id: foto.id, bildbezeichnung: bildbezeichnung)
                        onBezeichnungSaved()
                    }
            } else if !foto.bildbezeichnung.isEmpty {
                Text(foto.bildbezeichnung)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            }
            let url = DatabaseManager.shared.mietzeitraumFotoFullURL(imagePath: foto.imagePath)
            if FileManager.default.fileExists(atPath: url.path),
               let img = UIImage(contentsOfFile: url.path) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Bild nicht gefunden")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct MietzeitraumFotoZelleView: View {
    let foto: MietzeitraumFoto
    let mietzeitraumId: Int64
    let istGesperrt: Bool
    let onDelete: () -> Void
    let onTapToView: () -> Void
    let onReload: () -> Void
    @State private var bezeichnung: String
    init(foto: MietzeitraumFoto, mietzeitraumId: Int64, istGesperrt: Bool, onDelete: @escaping () -> Void, onTapToView: @escaping () -> Void, onReload: @escaping () -> Void) {
        self.foto = foto
        self.mietzeitraumId = mietzeitraumId
        self.istGesperrt = istGesperrt
        self.onDelete = onDelete
        self.onTapToView = onTapToView
        self.onReload = onReload
        self._bezeichnung = State(initialValue: foto.bildbezeichnung)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MietzeitraumFotoThumbnailView(imagePath: foto.imagePath)
                .frame(width: 80, height: 80)
                .onTapGesture { onTapToView() }
                .overlay(alignment: .topTrailing) {
                    if !istGesperrt {
                        Button(role: .destructive, action: onDelete) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .shadow(radius: 1)
                        }
                        .buttonStyle(.plain)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                        .offset(x: 4, y: -4)
                    }
                }
            if !istGesperrt {
                TextField("Bezeichnung", text: $bezeichnung, prompt: Text("Bezeichnung"))
                    .font(.caption)
                    .lineLimit(1)
                    .onSubmit {
                        _ = DatabaseManager.shared.updateMietzeitraumFotoBezeichnung(id: foto.id, bildbezeichnung: bezeichnung)
                        onReload()
                    }
            } else if !foto.bildbezeichnung.isEmpty {
                Text(foto.bildbezeichnung)
                    .font(.caption)
                    .lineLimit(2)
            }
        }
        .frame(width: 80)
        .onChange(of: foto.bildbezeichnung) { _, newValue in
            bezeichnung = newValue
        }
    }
}

/// Ein Block pro Mietzeitraum: Label + Foto-Grid + PhotosPicker. Wird in der Wohnungsbearbeitung (AddWohnungSheet) verwendet.
struct MietzeitraumFotosBlockView: View {
    let mietzeitraum: Mietzeitraum
    let fotos: [MietzeitraumFoto]
    let istGesperrt: Bool
    let onFotosChanged: () -> Void
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var fotoZumAnzeigen: MietzeitraumFoto?
    private var mid: Int64 { mietzeitraum.id }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(isoToDeDatum(mietzeitraum.vonDatum) ?? mietzeitraum.vonDatum) – \(isoToDeDatum(mietzeitraum.bisDatum) ?? mietzeitraum.bisDatum)")
                .font(.subheadline.weight(.medium))
            if !fotos.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                    ForEach(fotos) { foto in
                        MietzeitraumFotoZelleView(
                            foto: foto,
                            mietzeitraumId: mid,
                            istGesperrt: istGesperrt,
                            onDelete: {
                                let furl = DatabaseManager.shared.mietzeitraumFotoFullURL(imagePath: foto.imagePath)
                                if FileManager.default.fileExists(atPath: furl.path) {
                                    try? FileManager.default.removeItem(at: furl)
                                }
                                _ = DatabaseManager.shared.deleteMietzeitraumFoto(id: foto.id)
                                onFotosChanged()
                            },
                            onTapToView: { fotoZumAnzeigen = foto },
                            onReload: onFotosChanged
                        )
                    }
                }
            }
            if !istGesperrt {
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 20,
                    matching: .images
                ) {
                    Label("Bilder auswählen", systemImage: "photo.on.rectangle.angled")
                }
                .onChange(of: selectedPhotoItems) { _, items in
                    guard !items.isEmpty else { return }
                    Task {
                        let db = DatabaseManager.shared
                        let ordnerURL = db.mietzeitraumFotoOrdnerURL(mietzeitraumId: mid)
                        let nextOrder = db.getMietzeitraumFotos(byMietzeitraumId: mid).count
                        for (idx, item) in items.enumerated() {
                            if let data = try? await item.loadTransferable(type: Data.self), !data.isEmpty {
                                let filename = "img_\(UUID().uuidString).jpg"
                                let fileURL = ordnerURL.appendingPathComponent(filename)
                                try? data.write(to: fileURL)
                                let relPath = "\(mid)/\(filename)"
                                _ = db.insertMietzeitraumFoto(mietzeitraumId: mid, imagePath: relPath, sortOrder: nextOrder + idx, bildbezeichnung: "")
                            }
                        }
                        await MainActor.run {
                            selectedPhotoItems = []
                            onFotosChanged()
                        }
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .sheet(item: $fotoZumAnzeigen) { foto in
            NavigationStack {
                MietzeitraumFotoFullScreenView(foto: foto, onBezeichnungSaved: onFotosChanged)
                    .ignoresSafeArea(edges: .bottom)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Schließen") { fotoZumAnzeigen = nil }
                        }
                    }
            }
        }
    }
}

/// Nur Anzeige der Fotos pro Mietzeitraum (Detail-Ansicht): Label + Thumbnails, Tipp öffnet Vollbild. Kein Hinzufügen/Löschen/Bearbeiten.
private struct MietzeitraumFotosNurAnzeigeView: View {
    let mietzeitraum: Mietzeitraum
    let fotos: [MietzeitraumFoto]
    let onFotosChanged: () -> Void
    @State private var fotoZumAnzeigen: MietzeitraumFoto?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(isoToDeDatum(mietzeitraum.vonDatum) ?? mietzeitraum.vonDatum) – \(isoToDeDatum(mietzeitraum.bisDatum) ?? mietzeitraum.bisDatum)")
                .font(.subheadline.weight(.medium))
            if !fotos.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                    ForEach(fotos) { foto in
                        VStack(alignment: .leading, spacing: 4) {
                            MietzeitraumFotoThumbnailView(imagePath: foto.imagePath)
                                .frame(width: 80, height: 80)
                                .onTapGesture { fotoZumAnzeigen = foto }
                            if !foto.bildbezeichnung.isEmpty {
                                Text(foto.bildbezeichnung)
                                    .font(.caption)
                                    .lineLimit(2)
                            }
                        }
                        .frame(width: 80)
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .sheet(item: $fotoZumAnzeigen) { foto in
            NavigationStack {
                MietzeitraumFotoFullScreenView(foto: foto, readOnly: true, onBezeichnungSaved: onFotosChanged)
                    .ignoresSafeArea(edges: .bottom)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Schließen") { fotoZumAnzeigen = nil }
                        }
                    }
            }
        }
    }
}

#endif

private struct AddMitmieterSheet: View {
    let istGesperrt: Bool
    @Binding var name: String
    @Binding var vonDatum: Date
    @Binding var bisDatum: Date
    let isEdit: Bool
    let onSave: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name Mitmieter", text: $name)
                    DatePicker("Von", selection: $vonDatum, displayedComponents: .date)
                    DatePicker("Bis", selection: $bisDatum, displayedComponents: .date)
                } header: {
                    Text("Mitmieter")
                }
            }
            .navigationTitle(isEdit ? "Mitmieter bearbeiten" : "Neuer Mitmieter")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        onSave()
                        dismiss()
                    }
                    .disabled(istGesperrt || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

/// Mietzeitraum-Sheet in WohnungDetailView. Verträge/Anhänge werden nur in der Wohnungsbearbeitung (Übersicht → Bearbeiten) verwaltet.
private struct AddMietzeitraumSheetWithFotos: View {
    let istGesperrt: Bool
    let hauptmieterName: String
    @Binding var jahr: Int
    let abrechnungsJahr: Int
    @Binding var vonDatum: Date
    @Binding var bisDatum: Date
    @Binding var anzahlPersonenText: String
    @Binding var mietendeOption: MietendeOption
    let isEdit: Bool
    let onSave: (@escaping () -> Void) -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    init(
        istGesperrt: Bool,
        hauptmieterName: String,
        jahr: Binding<Int>,
        abrechnungsJahr: Int,
        vonDatum: Binding<Date>,
        bisDatum: Binding<Date>,
        anzahlPersonenText: Binding<String>,
        mietendeOption: Binding<MietendeOption>,
        isEdit: Bool,
        onSave: @escaping (@escaping () -> Void) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.istGesperrt = istGesperrt
        self.hauptmieterName = hauptmieterName
        self._jahr = jahr
        self.abrechnungsJahr = abrechnungsJahr
        self._vonDatum = vonDatum
        self._bisDatum = bisDatum
        self._anzahlPersonenText = anzahlPersonenText
        self._mietendeOption = mietendeOption
        self.isEdit = isEdit
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    // Berechne die Datumsgrenzen für das Abrechnungsjahr
    private var jahrStart: Date {
        var components = DateComponents(year: abrechnungsJahr, month: 1, day: 1)
        return Calendar.current.date(from: components) ?? Date()
    }
    
    private var jahrEnde: Date {
        var components = DateComponents(year: abrechnungsJahr, month: 12, day: 31)
        return Calendar.current.date(from: components) ?? Date()
    }
    
    private var isValidInput: Bool {
        // Hauptmieter-Name wird nicht mehr geprüft, da er nur angezeigt wird
        let anzahlValid = !anzahlPersonenText.isEmpty && Int(anzahlPersonenText) != nil && (Int(anzahlPersonenText) ?? 0) > 0
        // Die DatePicker begrenzen bereits die Auswahl, daher sind die Daten immer gültig wenn sie gesetzt sind
        let datumOrderValid = vonDatum <= bisDatum
        
        return anzahlValid && datumOrderValid
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Hauptmieter") {
                        Text(hauptmieterName.isEmpty ? "(Kein Name)" : hauptmieterName)
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("Jahr") {
                        Text("\(abrechnungsJahr)")
                            .foregroundStyle(.secondary)
                    }
                    DatePicker("Von", selection: $vonDatum, in: jahrStart...jahrEnde, displayedComponents: .date)
                    DatePicker("Bis", selection: $bisDatum, in: jahrStart...jahrEnde, displayedComponents: .date)
                    TextField("Anzahl Personen", text: $anzahlPersonenText)
                        .keyboardType(.numberPad)
                    Picker("Mietende", selection: $mietendeOption) {
                        ForEach(MietendeOption.allCases, id: \.self) { opt in
                            Text(opt.anzeigeText).tag(opt)
                        }
                    }
                } header: {
                    Text("Mietzeitraum")
                } footer: {
                    Text("Die Daten müssen im Abrechnungsjahr \(abrechnungsJahr) liegen. Das Einzugsdatum muss nach dem Auszugsdatum des vorherigen Hauptmieters liegen. „Gekündigt zum Mietzeitende“: Mieter wird beim Jahreswechsel nicht ins neue Jahr übernommen.")
                }
            }
            .navigationTitle(isEdit ? "Mietzeitraum bearbeiten" : "Neuer Mietzeitraum")
            .onAppear {
                jahr = abrechnungsJahr
                if vonDatum < jahrStart { vonDatum = jahrStart }
                if vonDatum > jahrEnde { vonDatum = jahrEnde }
                if bisDatum < jahrStart { bisDatum = jahrStart }
                if bisDatum > jahrEnde { bisDatum = jahrEnde }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        onSave { dismiss() }
                    }
                    .disabled(istGesperrt || !isValidInput)
                }
            }
        }
    }
}
