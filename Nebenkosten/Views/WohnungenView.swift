//
//  WohnungenView.swift
//  Nebenkosten
//
//  Created by Axel Behm on 22.01.26.
//

import SwiftUI
import PhotosUI

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
/// ISO-Datum (yyyy-MM-dd) in deutsches Anzeigeformat (dd.MM.yyyy)
private func isoToDeDatum(_ s: String) -> String? {
    guard let d = isoToDate(s) else { return nil }
    return deDateFormatter.string(from: d)
}

// Prüft ob ein Jahr gesperrt ist (wenn ein neueres Jahr existiert)
private func istJahrGesperrt(abrechnung: HausAbrechnung) -> Bool {
    return DatabaseManager.shared.istJahrGesperrt(hausBezeichnung: abrechnung.hausBezeichnung, jahr: abrechnung.abrechnungsJahr)
}

struct WohnungenView: View {
    let abrechnung: HausAbrechnung
    @State private var wohnungen: [Wohnung] = []
    @State private var showAddWohnung = false
    @State private var editingWohnung: Wohnung?
    @State private var showDeleteAlert = false
    @State private var deletingWohnung: Wohnung?
    @State private var qmPruefungsFehler: String? = nil
    @State private var showQmPruefungsFehler = false
    @State private var qmPruefungsErfolg: String? = nil
    @State private var showQmPruefungsErfolg = false
    @State private var istGesperrt: Bool = false
    @State private var showUpgrade = false
    @State private var limitErrorMessage: String?
    @State private var showLimitError = false
    @ObservedObject private var purchaseManager = PurchaseManager.shared
    
    @State private var newBezeichnung = ""
    @State private var newQm = ""
    @State private var newWohnungsnummer = ""
    @State private var newName = ""
    @State private var newStrasse = ""
    @State private var newPlz = ""
    @State private var newOrt = ""
    @State private var newEmail = ""
    @State private var newTelefon = ""
    
    var body: some View {
        Group {
            if wohnungen.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "door.left.hand.open")
                        .font(.system(size: 50))
                        .foregroundStyle(Color.appBlue)
                    Text("Keine Wohnungen")
                        .font(.headline)
                    Text("Fügen Sie Wohnungen für \(abrechnung.hausBezeichnung) (\(abrechnung.abrechnungsJahr)) hinzu.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(wohnungen) { w in
                        HStack(spacing: 12) {
                            Image(systemName: "door.left.hand.open")
                                .font(.title2)
                                .foregroundStyle(Color.appBlue)
                                .frame(width: 28, alignment: .center)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    if let nummer = w.wohnungsnummer, !nummer.isEmpty {
                                        Text("Nr. \(nummer)")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let name = w.name, !name.isEmpty {
                                        Text(name)
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.primary)
                                    }
                                }
                                Text(w.bezeichnung)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 6) {
                                    Text("\(w.qm) m²")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    if let letzter = DatabaseManager.shared.getLetzterMietzeitraum(wohnungId: w.id),
                                       let auszugDe = isoToDeDatum(letzter.bisDatum) {
                                        Text("· Auszug: \(auszugDe)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            Spacer()
                            Menu {
                                NavigationLink(destination: WohnungDetailView(wohnung: w, haus: abrechnung)) {
                                    Label("Detail-Anzeige", systemImage: "info.circle")
                                }
                                NavigationLink(destination: ZaehlerstaendeView(wohnung: w, haus: abrechnung)) {
                                    Label("Zählerdaten", systemImage: "gauge.with.dots.needle.67percent")
                                }
                                Button {
                                    editingWohnung = w
                                    newBezeichnung = w.bezeichnung
                                    newQm = String(w.qm)
                                    newWohnungsnummer = w.wohnungsnummer ?? ""
                                    newName = w.name ?? ""
                                    newStrasse = w.strasse ?? ""
                                    newPlz = w.plz ?? ""
                                    newOrt = w.ort ?? ""
                                    newEmail = w.email ?? ""
                                    newTelefon = w.telefon ?? ""
                                    showAddWohnung = true
                                } label: {
                                    Label("Bearbeiten", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    print("Löschen-Button geklickt für Wohnung ID: \(w.id), Bezeichnung: \(w.bezeichnung)")
                                    deletingWohnung = w
                                    showDeleteAlert = true
                                    print("showDeleteAlert gesetzt auf: true")
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                                .disabled(istGesperrt)
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundColor(.blue)
                            }
                            .fixedSize()
                        }
                        #if os(iOS)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if !istGesperrt {
                                Button(role: .destructive) {
                                    print("Swipe Löschen für Wohnung ID: \(w.id), Bezeichnung: \(w.bezeichnung)")
                                    deletingWohnung = w
                                    showDeleteAlert = true
                                    print("showDeleteAlert gesetzt auf: true (Swipe)")
                                } label: { Label("Löschen", systemImage: "trash") }
                                Button {
                                    editingWohnung = w
                                    newBezeichnung = w.bezeichnung
                                    newQm = String(w.qm)
                                    newWohnungsnummer = w.wohnungsnummer ?? ""
                                    newName = w.name ?? ""
                                    newStrasse = w.strasse ?? ""
                                    newPlz = w.plz ?? ""
                                    newOrt = w.ort ?? ""
                                    newEmail = w.email ?? ""
                                    newTelefon = w.telefon ?? ""
                                    showAddWohnung = true
                                } label: { Label("Bearbeiten", systemImage: "pencil") }
                                    .tint(.blue)
                            }
                        }
                        #endif
                    }
                }
            }
        }
        .navigationTitle("Wohnungen – Übersicht")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { 
            loadWohnungen()
            istGesperrt = istJahrGesperrt(abrechnung: abrechnung)
        }
        .onChange(of: showAddWohnung) { old, new in
            if !new && old { loadWohnungen() }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    Button(action: {
                        showUpgrade = true
                    }) {
                        Label(
                            purchaseManager.isPremium ? "Vollversion" : "Upgrade",
                            systemImage: purchaseManager.isPremium ? "checkmark.circle.fill" : "star.fill"
                        )
                        .foregroundStyle(purchaseManager.isPremium ? .green : .yellow)
                    }
                    Button {
                        editingWohnung = nil
                        newBezeichnung = ""
                        newQm = ""
                        newWohnungsnummer = ""
                        newName = ""
                        newStrasse = abrechnung.hausBezeichnung
                        newPlz = abrechnung.postleitzahl ?? ""
                        newOrt = abrechnung.ort ?? ""
                        newEmail = ""
                        newTelefon = ""
                        showAddWohnung = true
                    } label: {
                        Label("Wohnung hinzufügen", systemImage: "plus.circle")
                    }
                    .disabled(istGesperrt)
                }
            }
        }
        .sheet(isPresented: $showAddWohnung) {
            AddWohnungSheet(
                abrechnung: abrechnung,
                wohnung: editingWohnung,
                wohnungsnummer: $newWohnungsnummer,
                bezeichnung: $newBezeichnung,
                qm: $newQm,
                name: $newName,
                strasse: $newStrasse,
                plz: $newPlz,
                ort: $newOrt,
                email: $newEmail,
                telefon: $newTelefon,
                isEdit: editingWohnung != nil,
                onSave: {
                    // Die Wohnung wird bereits in AddWohnungSheet gespeichert
                    // Hier nur die Liste aktualisieren
                    loadWohnungen()
                    
                    // Prüfe Validierung nach dem Speichern (nur für Erfolgsmeldung)
                    let validierung = DatabaseManager.shared.pruefeWohnungenValidierung(hausId: abrechnung.id)
                    print("Prüfung nach Speichern - Erfolgreich: \(validierung.erfolgreich), Fehler: \(validierung.fehlermeldung ?? "kein"), Erfolg: \(validierung.erfolgsmeldung ?? "kein")")
                    if validierung.erfolgreich, let erfolg = validierung.erfolgsmeldung {
                        qmPruefungsErfolg = erfolg
                        showQmPruefungsErfolg = true
                        print("Erfolgsmeldung gesetzt: \(erfolg)")
                    } else if !validierung.erfolgreich {
                        qmPruefungsFehler = validierung.fehlermeldung ?? "Validierungsfehler aufgetreten."
                        showQmPruefungsFehler = true
                        print("Fehlermeldung gesetzt: \(qmPruefungsFehler ?? "kein")")
                    }
                    
                    showAddWohnung = false
                    editingWohnung = nil
                },
                onCancel: {
                    showAddWohnung = false
                    editingWohnung = nil
                }
            )
        }
        .sheet(isPresented: $showUpgrade) {
            UpgradeView()
        }
        .alert("Limit erreicht", isPresented: $showLimitError) {
            Button("OK", role: .cancel) { }
            Button("Upgrade") {
                showUpgrade = true
            }
        } message: {
            if let message = limitErrorMessage {
                Text(message)
            }
        }
        .alert("Wohnung löschen?", isPresented: $showDeleteAlert) {
            Button("Abbrechen", role: .cancel) { 
                print("Löschen abgebrochen")
                deletingWohnung = nil
                showDeleteAlert = false
            }
            Button("Löschen", role: .destructive) {
                print("Löschen bestätigt für Wohnung: \(deletingWohnung?.id ?? -1)")
                if let w = deletingWohnung {
                    // Prüfe ob Jahr gesperrt ist
                    if istGesperrt {
                        qmPruefungsFehler = "Dieses Jahr ist gesperrt, da ein neueres Jahr existiert. Änderungen sind nicht mehr möglich."
                        showQmPruefungsFehler = true
                        deletingWohnung = nil
                        showDeleteAlert = false
                        return
                    }
                    
                    // Löschen durchführen (ohne Prüfung VOR dem Löschen)
                    // Die Prüfung auf Vollständigkeit erfolgt erst beim Erstellen der Abrechnung
                    let deleteSuccess = DatabaseManager.shared.deleteWohnung(id: w.id)
                    print("Löschen durchgeführt für Wohnung ID: \(w.id), Erfolg: \(deleteSuccess)")
                    if deleteSuccess {
                        loadWohnungen()
                        
                        // Prüfe Validierung nach dem Löschen (nur zur Information, nicht zum Verhindern)
                        let validierungNachher = DatabaseManager.shared.pruefeWohnungenValidierung(hausId: abrechnung.id)
                        if !validierungNachher.erfolgreich {
                            // Warnung anzeigen, aber nicht verhindern
                            qmPruefungsFehler = "Hinweis: Nach dem Löschen stimmen die Daten nicht mehr überein:\n\n\(validierungNachher.fehlermeldung ?? "Validierungsfehler")\n\nBitte überprüfen Sie die eingegebenen Werte im Haus."
                            showQmPruefungsFehler = true
                        } else if let erfolg = validierungNachher.erfolgsmeldung {
                            qmPruefungsErfolg = erfolg
                            showQmPruefungsErfolg = true
                        }
                    } else {
                        // Fehler beim Löschen
                        qmPruefungsFehler = "Fehler beim Löschen der Wohnung. Bitte versuchen Sie es erneut."
                        showQmPruefungsFehler = true
                    }
                    
                    deletingWohnung = nil
                    showDeleteAlert = false
                }
            }
        } message: {
            if let w = deletingWohnung {
                Text("Wohnung „\(w.bezeichnung)“ und alle zugehörigen Mietzeiträume sowie Mitmieter löschen?")
            }
        }
        .onChange(of: showDeleteAlert) { oldValue, newValue in
            if !newValue && oldValue {
                // Alert wurde geschlossen, setze deletingWohnung zurück
                print("Alert geschlossen, deletingWohnung wird zurückgesetzt")
                deletingWohnung = nil
            }
        }
        .alert("QM-Prüfung", isPresented: $showQmPruefungsFehler) {
            Button("OK", role: .cancel) { }
        } message: {
            if let fehler = qmPruefungsFehler {
                Text(fehler)
            }
        }
        .alert("Prüfung erfolgreich", isPresented: $showQmPruefungsErfolg) {
            Button("OK", role: .cancel) { }
        } message: {
            if let erfolg = qmPruefungsErfolg {
                Text(erfolg)
            }
        }
    }
    
    func loadWohnungen() {
        wohnungen = DatabaseManager.shared.getWohnungen(byHausAbrechnungId: abrechnung.id)
    }
}

private struct AddWohnungSheet: View {
    let abrechnung: HausAbrechnung
    let wohnung: Wohnung?
    @Binding var wohnungsnummer: String
    @Binding var bezeichnung: String
    @Binding var qm: String
    @Binding var name: String
    @Binding var strasse: String
    @Binding var plz: String
    @Binding var ort: String
    @Binding var email: String
    @Binding var telefon: String
    let isEdit: Bool
    let onSave: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var mietzeitraeume: [Mietzeitraum] = []  // Gespeicherte Mietzeiträume (nur beim Bearbeiten)
    @State private var mietzeitraumFotosByMietzeitraum: [Int64: [MietzeitraumFoto]] = [:]
    @State private var neueMietzeitraeume: [MietzeitraumTemp] = []  // Temporäre Mietzeiträume beim Anlegen
    @State private var showAddMietzeitraum = false
    @State private var editingMietzeitraum: Mietzeitraum?
    @State private var editingMietzeitraumTemp: MietzeitraumTemp?
    @State private var showDeleteMietzeitraum = false
    @State private var deletingMietzeitraum: Mietzeitraum?
    @State private var deletingMietzeitraumTemp: MietzeitraumTemp?
    
    @State private var vonDatum = Date()
    @State private var bisDatum = Date()
    @State private var anzahlPersonenText = ""
    @State private var mietendeOption: MietendeOption = .mietendeOffen
    @State private var validierungsFehler: String? = nil
    @State private var showValidierungsFehler = false
    @State private var qmPruefungsFehler: String? = nil
    @State private var showQmPruefungsFehler = false
    @State private var qmPruefungsErfolg: String? = nil
    @State private var showQmPruefungsErfolg = false
    @State private var istGesperrt: Bool = false
    @State private var limitErrorMessage: String? = nil
    @State private var showLimitError = false
    
    // Temporäre Struktur für Mietzeiträume beim Anlegen einer neuen Wohnung
    struct MietzeitraumTemp: Identifiable {
        let id = UUID()
        var vonDatum: Date
        var bisDatum: Date
        var anzahlPersonen: Int
        var mietendeOption: MietendeOption
    }
    
    // Berechne die Datumsgrenzen für das Abrechnungsjahr
    private var jahrStart: Date {
        var components = DateComponents(year: abrechnung.abrechnungsJahr, month: 1, day: 1)
        return Calendar.current.date(from: components) ?? Date()
    }
    
    private var jahrEnde: Date {
        var components = DateComponents(year: abrechnung.abrechnungsJahr, month: 12, day: 31)
        return Calendar.current.date(from: components) ?? Date()
    }
    
    var body: some View {
        NavigationStack {
            Form {
                if istGesperrt && isEdit {
                    gesperrtSection
                }
                
                wohnungSection
                kontaktdatenSection
                mietzeitraeumeSection
                
                #if os(iOS)
                if isEdit, let w = wohnung, !mietzeitraeume.isEmpty {
                    vertraegeSection(wohnung: w)
                }
                #endif
            }
            .navigationTitle(isEdit ? "Wohnung bearbeiten" : "Neue Wohnung")
            .onAppear {
                if isEdit, let w = wohnung {
                    loadMietzeitraeume(wohnungId: w.id)
                }
                istGesperrt = istJahrGesperrt(abrechnung: abrechnung)
            }
            .sheet(isPresented: $showAddMietzeitraum) {
                mietzeitraumSheet
            }
            .alert("Validierungsfehler", isPresented: $showValidierungsFehler) {
                Button("OK", role: .cancel) { }
            } message: {
                if let fehler = validierungsFehler {
                    Text(fehler)
                }
            }
            .alert("QM-Prüfung", isPresented: $showQmPruefungsFehler) {
                Button("OK", role: .cancel) { }
            } message: {
                if let fehler = qmPruefungsFehler {
                    Text(fehler)
                }
            }
            .alert("Prüfung erfolgreich", isPresented: $showQmPruefungsErfolg) {
                Button("OK", role: .cancel) { }
            } message: {
                if let erfolg = qmPruefungsErfolg {
                    Text(erfolg)
                }
            }
            .alert("Mietzeitraum löschen?", isPresented: $showDeleteMietzeitraum) {
                Button("Abbrechen", role: .cancel) {
                    deletingMietzeitraum = nil
                    deletingMietzeitraumTemp = nil
                }
                Button("Löschen", role: .destructive) {
                    if let m = deletingMietzeitraum {
                        _ = DatabaseManager.shared.deleteMietzeitraum(id: m.id)
                        if let w = wohnung {
                            loadMietzeitraeume(wohnungId: w.id)
                        }
                        deletingMietzeitraum = nil
                    }
                    if let m = deletingMietzeitraumTemp {
                        neueMietzeitraeume.removeAll { $0.id == m.id }
                        deletingMietzeitraumTemp = nil
                    }
                }
            } message: {
                if let m = deletingMietzeitraum {
                    Text("Mietzeitraum \"\(m.hauptmieterName)\" (\(isoToDeDatum(m.vonDatum) ?? m.vonDatum) – \(isoToDeDatum(m.bisDatum) ?? m.bisDatum)) und alle Mitmieter löschen?")
                } else if let m = deletingMietzeitraumTemp {
                    Text("Mietzeitraum (\(isoToDeDatum(dateToISO(m.vonDatum)) ?? dateToISO(m.vonDatum)) – \(isoToDeDatum(dateToISO(m.bisDatum)) ?? dateToISO(m.bisDatum))) löschen?")
                }
            }
            .alert("Limit erreicht", isPresented: $showLimitError) {
                Button("OK", role: .cancel) { }
            } message: {
                if let message = limitErrorMessage {
                    Text(message)
                }
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
                        speichernWohnung()
                    }
                    .disabled(istGesperrt || bezeichnung.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || Int(qm) == nil || (Int(qm) ?? 0) <= 0 || (!isEdit && neueMietzeitraeume.isEmpty))
                }
            }
        }
    }
    
    @ViewBuilder
    private var gesperrtSection: some View {
        Section {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.orange)
                Text("Dieses Jahr ist gesperrt, da ein neueres Jahr existiert. Änderungen sind nicht mehr möglich.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
    
    @ViewBuilder
    private var wohnungSection: some View {
        Section {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("Whng.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Nr.", text: $wohnungsnummer)
                    .disabled(istGesperrt && isEdit)
                    .onChange(of: wohnungsnummer) { oldValue, newValue in
                            // Validierung: Prüfe, ob die Nummer größer als die Anzahl der Wohnungen ist
                            let trimmedNummer = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmedNummer.isEmpty, let nummerInt = Int(trimmedNummer) {
                                if let maxAnzahl = abrechnung.anzahlWohnungen, nummerInt > maxAnzahl {
                                    validierungsFehler = "Die Wohnungsnummer \(nummerInt) ist größer als die im Haus hinterlegte Anzahl der Wohnungen (\(maxAnzahl))."
                                    showValidierungsFehler = true
                                    // Setze die Nummer zurück auf den alten Wert
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        wohnungsnummer = oldValue
                                    }
                                    return
                                }
                            }
                            
                            // Wenn eine neue Wohnung angelegt wird (nicht bearbeitet) und eine Nummer eingegeben wird
                            if !isEdit && !newValue.isEmpty {
                                // Prüfe, ob eine Wohnung mit dieser Nummer bereits existiert
                                if !trimmedNummer.isEmpty,
                                   let vorhandeneWohnung = DatabaseManager.shared.getWohnung(
                                    byWohnungsnummer: trimmedNummer,
                                    hausAbrechnungId: abrechnung.id
                                ) {
                                    // Übernehme qm und bezeichnung nur wenn die Felder leer sind
                                    if qm.isEmpty {
                                        qm = String(vorhandeneWohnung.qm)
                                    }
                                    if bezeichnung.isEmpty {
                                        bezeichnung = vorhandeneWohnung.bezeichnung
                                    }
                                }
                            }
                        }
            }
            TextField("z.B. Wohnung 1, 1. OG links", text: $bezeichnung)
                .disabled(istGesperrt && isEdit)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("qm")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("m²", text: $qm)
                    .keyboardType(.numberPad)
                    .disabled(istGesperrt && isEdit)
            }
        } header: {
            HStack(spacing: 6) {
                Image(systemName: "building.2")
                    .foregroundStyle(Color.appBlue)
                Text("Wohnung")
            }
        }
    }
    
    @ViewBuilder
    private var kontaktdatenSection: some View {
        Section {
            TextField("Name", text: $name)
                .disabled(istGesperrt && isEdit)
            TextField("Straße mit Hausnummer", text: $strasse)
                .disabled(istGesperrt && isEdit)
            TextField("PLZ", text: $plz)
                .keyboardType(.numberPad)
                .disabled(istGesperrt && isEdit)
            TextField("Ort", text: $ort)
                .disabled(istGesperrt && isEdit)
            TextField("E-Mail", text: $email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .disabled(istGesperrt && isEdit)
            TextField("Telefon", text: $telefon)
                .keyboardType(.phonePad)
                .disabled(istGesperrt && isEdit)
        } header: {
            Label("Kontaktdaten", systemImage: "person.crop.circle")
        } footer: {
            Text("Straße, PLZ und Ort werden standardmäßig aus dem Haus übernommen.")
        }
    }
    
    @ViewBuilder
    private var mietzeitraeumeSection: some View {
        Section {
                    if isEdit, let w = wohnung {
                        // Beim Bearbeiten: Zeige gespeicherte Mietzeiträume
                        ForEach(mietzeitraeume) { m in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(isoToDeDatum(m.vonDatum) ?? m.vonDatum) – \(isoToDeDatum(m.bisDatum) ?? m.bisDatum)")
                                        .font(.subheadline.weight(.medium))
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
                                Menu {
                                    Button {
                                        editingMietzeitraum = m
                                        vonDatum = isoToDate(m.vonDatum) ?? jahrStart
                                        bisDatum = isoToDate(m.bisDatum) ?? jahrEnde
                                        anzahlPersonenText = String(m.anzahlPersonen)
                                        mietendeOption = m.mietendeOption
                                        showAddMietzeitraum = true
                                    } label: { Label("Bearbeiten", systemImage: "pencil") }
                                    Button(role: .destructive) {
                                        deletingMietzeitraum = m
                                        showDeleteMietzeitraum = true
                                    } label: { Label("Löschen", systemImage: "trash") }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .foregroundStyle(.blue)
                                }
                                .fixedSize()
                            }
                        }
                        if mietzeitraeume.isEmpty {
                            Text("Keine Mietzeiträume")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Button {
                            editingMietzeitraum = nil
                            // Setze Von-Datum auf das Datum nach dem letzten Auszugsdatum
                            if let letzter = DatabaseManager.shared.getLetzterMietzeitraum(wohnungId: w.id),
                               let letztesAuszug = isoToDate(letzter.bisDatum) {
                                // Setze auf den Tag nach dem Auszugsdatum
                                vonDatum = Calendar.current.date(byAdding: .day, value: 1, to: letztesAuszug) ?? jahrStart
                            } else {
                                vonDatum = jahrStart
                            }
                            bisDatum = jahrEnde
                            anzahlPersonenText = "1"
                            mietendeOption = .mietendeOffen
                            showAddMietzeitraum = true
                        } label: {
                            Label("Mietzeitraum hinzufügen", systemImage: "plus.circle")
                        }
                    } else {
                        // Beim Anlegen: Zeige temporäre Mietzeiträume
                        ForEach(neueMietzeitraeume) { m in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(isoToDeDatum(dateToISO(m.vonDatum)) ?? dateToISO(m.vonDatum)) – \(isoToDeDatum(dateToISO(m.bisDatum)) ?? dateToISO(m.bisDatum))")
                                        .font(.subheadline.weight(.medium))
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
                                Menu {
                                    Button {
                                        editingMietzeitraumTemp = m
                                        vonDatum = m.vonDatum
                                        bisDatum = m.bisDatum
                                        anzahlPersonenText = String(m.anzahlPersonen)
                                        mietendeOption = m.mietendeOption
                                        showAddMietzeitraum = true
                                    } label: { Label("Bearbeiten", systemImage: "pencil") }
                                    Button(role: .destructive) {
                                        deletingMietzeitraumTemp = m
                                        showDeleteMietzeitraum = true
                                    } label: { Label("Löschen", systemImage: "trash") }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .foregroundStyle(.blue)
                                }
                                .fixedSize()
                            }
                        }
                        if neueMietzeitraeume.isEmpty {
                            Text("Keine Mietzeiträume")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Button {
                            editingMietzeitraumTemp = nil
                            editingMietzeitraum = nil
                            // Setze Von-Datum auf das Datum nach dem letzten Auszugsdatum der vorhandenen Wohnung
                            let trimmedNummer = wohnungsnummer.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmedNummer.isEmpty,
                               let letzter = DatabaseManager.shared.getLetzterMietzeitraum(
                                byWohnungsnummer: trimmedNummer,
                                hausAbrechnungId: abrechnung.id
                               ),
                               let letztesAuszug = isoToDate(letzter.bisDatum) {
                                // Setze auf den Tag nach dem Auszugsdatum
                                vonDatum = Calendar.current.date(byAdding: .day, value: 1, to: letztesAuszug) ?? jahrStart
                            } else {
                                // Prüfe, ob es bereits temporäre Mietzeiträume gibt
                                if let letzterTemp = neueMietzeitraeume.max(by: { $0.bisDatum < $1.bisDatum }) {
                                    vonDatum = Calendar.current.date(byAdding: .day, value: 1, to: letzterTemp.bisDatum) ?? jahrStart
                                } else {
                                    vonDatum = jahrStart
                                }
                            }
                            bisDatum = jahrEnde
                            anzahlPersonenText = "1"
                            mietendeOption = .mietendeOffen
                            showAddMietzeitraum = true
                        } label: {
                            Label("Mietzeitraum hinzufügen", systemImage: "plus.circle")
                        }
                    }
        } header: {
            Label("Mietzeiträume", systemImage: "calendar")
        } footer: {
            if !isEdit && neueMietzeitraeume.isEmpty {
                Text("Bitte erfassen Sie mindestens einen Mietzeitraum, bevor Sie die Wohnung speichern.")
                    .foregroundStyle(.red)
            } else {
                Text("Die Daten müssen im Abrechnungsjahr \(abrechnung.abrechnungsJahr) liegen.")
            }
        }
    }
    
    @ViewBuilder
    private func vertraegeSection(wohnung: Wohnung) -> some View {
        #if os(iOS)
        Section {
            ForEach(mietzeitraeume) { m in
                MietzeitraumFotosBlockView(
                    mietzeitraum: m,
                    fotos: mietzeitraumFotosByMietzeitraum[m.id] ?? [],
                    istGesperrt: istGesperrt,
                    onFotosChanged: { loadMietzeitraeume(wohnungId: wohnung.id) }
                )
            }
        } header: {
            Text("Verträge / Anhänge")
        } footer: {
            Text("Bilder (z. B. Mietvertrag, Kaution) den Mietzeiträumen zuordnen.")
        }
        #endif
    }
    
    @ViewBuilder
    private var mietzeitraumSheet: some View {
        AddMietzeitraumSheet(
            istGesperrt: istGesperrt,
            hauptmieterName: isEdit ? (wohnung?.name ?? "") : name,
            abrechnungsJahr: abrechnung.abrechnungsJahr,
            vonDatum: $vonDatum,
            bisDatum: $bisDatum,
            anzahlPersonenText: $anzahlPersonenText,
            mietendeOption: $mietendeOption,
            isEdit: editingMietzeitraum != nil || editingMietzeitraumTemp != nil,
            onSave: { dismiss in
                mietzeitraumSpeichern(dismiss: dismiss)
            },
            onCancel: {
                showAddMietzeitraum = false
                editingMietzeitraum = nil
                editingMietzeitraumTemp = nil
            }
        )
    }
    
    private func mietzeitraumSpeichern(dismiss: @escaping () -> Void) {
        // Validierung: Prüfe, ob Daten im Abrechnungsjahr liegen
        let vonDatumISO = dateToISO(vonDatum)
        let bisDatumISO = dateToISO(bisDatum)
        let vonDatumJahr = Calendar.current.component(.year, from: vonDatum)
        let bisDatumJahr = Calendar.current.component(.year, from: bisDatum)
        
        if vonDatumJahr != abrechnung.abrechnungsJahr || bisDatumJahr != abrechnung.abrechnungsJahr {
            validierungsFehler = "Die Daten müssen im Abrechnungsjahr \(abrechnung.abrechnungsJahr) liegen.\n\nVon-Datum: \(vonDatumISO) (Jahr: \(vonDatumJahr))\nBis-Datum: \(bisDatumISO) (Jahr: \(bisDatumJahr))"
            showValidierungsFehler = true
            return
        }
        
        let anzahl = Int(anzahlPersonenText) ?? 0
        
        if anzahl <= 0 {
            validierungsFehler = "Die Anzahl Personen muss größer als 0 sein."
            showValidierungsFehler = true
            return
        }
        
        if isEdit, let w = wohnung {
            // Beim Bearbeiten: Speichere direkt in die Datenbank
            // Validierung: Prüfe, ob es Überlappungen gibt
            if let ueberlappung = DatabaseManager.shared.getUeberlappendenMietzeitraum(
                wohnungId: w.id,
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
                wohnungId: w.id,
                vorDatum: vonDatumISO,
                ausschliessenId: editingMietzeitraum?.id
            ) {
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
                // Kein vorheriger Mietzeitraum: Anschlussmieter darf nur NACH Auszug des 1. Mieters. Prüfe, ob ein bestehender Zeitraum noch „drüber“ liegt.
                if let konflikt = DatabaseManager.shared.getConflictingMietzeitraum(
                    wohnungId: w.id,
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
                    wohnungId: w.id,
                    nachDatum: bisDatumISO,
                    ausschliessenId: editingMietzeitraum?.id
                ) {
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
            
            if let e = editingMietzeitraum {
                _ = DatabaseManager.shared.updateMietzeitraum(Mietzeitraum(
                    id: e.id, wohnungId: w.id,
                    jahr: abrechnung.abrechnungsJahr,
                    hauptmieterName: wohnung?.name ?? "",
                    vonDatum: vonDatumISO, bisDatum: bisDatumISO,
                    anzahlPersonen: anzahl,
                    mietendeOption: mietendeOption
                ))
            } else {
                _ = DatabaseManager.shared.insertMietzeitraum(Mietzeitraum(
                    wohnungId: w.id,
                    jahr: abrechnung.abrechnungsJahr,
                    hauptmieterName: wohnung?.name ?? "",
                    vonDatum: vonDatumISO, bisDatum: bisDatumISO,
                    anzahlPersonen: anzahl,
                    mietendeOption: mietendeOption
                ))
            }
            loadMietzeitraeume(wohnungId: w.id)
        } else {
            // Beim Anlegen: Speichere temporär
            // Validierung: Prüfe auf Überlappungen mit temporären Mietzeiträumen
            let trimmedNummer = wohnungsnummer.trimmingCharacters(in: .whitespacesAndNewlines)
            var alleMietzeitraeume: [(vonDatum: Date, bisDatum: Date)] = []
            
            // Füge temporäre Mietzeiträume hinzu (außer dem aktuell bearbeiteten)
            for temp in neueMietzeitraeume {
                if temp.id != editingMietzeitraumTemp?.id {
                    alleMietzeitraeume.append((vonDatum: temp.vonDatum, bisDatum: temp.bisDatum))
                }
            }
            
            // Prüfe auf Überlappungen mit temporären Mietzeiträumen
            for existing in alleMietzeitraeume {
                if vonDatum <= existing.bisDatum && bisDatum >= existing.vonDatum {
                    validierungsFehler = "Es gibt bereits einen Mietzeitraum, der mit diesem Zeitraum überlappt.\n\nZeitraum: \(dateToISO(existing.vonDatum)) – \(dateToISO(existing.bisDatum))\n\nMietzeiträume müssen aneinander anschließen."
                    showValidierungsFehler = true
                    return
                }
            }
            
            // Validierung: Prüfe auf konsekutive Zeiträume mit temporären Mietzeiträumen
            if let letzterTemp = neueMietzeitraeume.max(by: { $0.bisDatum < $1.bisDatum }),
               letzterTemp.id != editingMietzeitraumTemp?.id {
                let erwartetesEinzug = Calendar.current.date(byAdding: .day, value: 1, to: letzterTemp.bisDatum)
                if let erwartetesEinzug = erwartetesEinzug, vonDatum != erwartetesEinzug {
                    validierungsFehler = "Mietzeiträume müssen aneinander anschließen.\n\nVorheriger Mietzeitraum endet: \(dateToISO(letzterTemp.bisDatum))\nErwartetes Einzugsdatum: \(dateToISO(erwartetesEinzug))\nEingegebenes Einzugsdatum: \(vonDatumISO)\n\nDas Einzugsdatum muss genau auf den Tag nach dem Auszugsdatum des vorherigen Mietzeitraums gesetzt werden."
                    showValidierungsFehler = true
                    return
                }
            }
            
            // Speichere temporären Mietzeitraum
            if let editing = editingMietzeitraumTemp {
                if let index = neueMietzeitraeume.firstIndex(where: { $0.id == editing.id }) {
                    neueMietzeitraeume[index] = MietzeitraumTemp(
                        vonDatum: vonDatum,
                        bisDatum: bisDatum,
                        anzahlPersonen: anzahl,
                        mietendeOption: mietendeOption
                    )
                }
            } else {
                neueMietzeitraeume.append(MietzeitraumTemp(
                    vonDatum: vonDatum,
                    bisDatum: bisDatum,
                    anzahlPersonen: anzahl,
                    mietendeOption: mietendeOption
                ))
            }
        }
        
        showAddMietzeitraum = false
        editingMietzeitraum = nil
        editingMietzeitraumTemp = nil
        dismiss() // Form schließen nach erfolgreichem Speichern
    }
    
    private func speichernWohnung() {
        // Prüfe ob Jahr gesperrt ist
        if istGesperrt && isEdit {
            validierungsFehler = "Dieses Jahr ist gesperrt, da ein neueres Jahr existiert. Änderungen sind nicht mehr möglich."
            showValidierungsFehler = true
            return
        }
        
        // Validierung: Prüfe, ob die Wohnungsnummer größer als die Anzahl der Wohnungen ist
        let trimmedNummer = wohnungsnummer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNummer.isEmpty, let nummerInt = Int(trimmedNummer) {
            if let maxAnzahl = abrechnung.anzahlWohnungen, nummerInt > maxAnzahl {
                validierungsFehler = "Die Wohnungsnummer \(nummerInt) ist größer als die im Haus hinterlegte Anzahl der Wohnungen (\(maxAnzahl))."
                showValidierungsFehler = true
                return
            }
        }
        
        // Speichere zuerst die Wohnung
        var savedWohnungId: Int64?
        
        if isEdit, let e = wohnung {
            guard let q = Int(qm), q > 0 else { return }
            _ = DatabaseManager.shared.updateWohnung(Wohnung(
                id: e.id,
                hausAbrechnungId: e.hausAbrechnungId,
                wohnungsnummer: wohnungsnummer.isEmpty ? nil : wohnungsnummer,
                bezeichnung: bezeichnung.trimmingCharacters(in: .whitespacesAndNewlines),
                qm: q,
                name: name.isEmpty ? nil : name,
                strasse: strasse.isEmpty ? nil : strasse,
                plz: plz.isEmpty ? nil : plz,
                ort: ort.isEmpty ? nil : ort,
                email: email.isEmpty ? nil : email,
                telefon: telefon.isEmpty ? nil : telefon
            ))
            savedWohnungId = e.id
        } else {
            guard let q = Int(qm), q > 0, !bezeichnung.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            
            // Prüfe Limits vor dem Speichern
            let limitCheck = LimitManager.shared.canCreateWohnung(
                hausId: abrechnung.id,
                wohnungsnummer: wohnungsnummer.isEmpty ? nil : wohnungsnummer
            )
            if !limitCheck.allowed {
                limitErrorMessage = limitCheck.message
                showLimitError = true
                return
            }
            
            // Prüfe: Wohnungsnummer schon vorhanden? Wenn ja, nur erlauben wenn Mietzeitende der bestehenden Wohnung < 31.12. des Abrechnungsjahres
            if !trimmedNummer.isEmpty {
                let nummerCheck = DatabaseManager.shared.canCreateWohnungWithNummer(
                    wohnungsnummer: trimmedNummer,
                    hausAbrechnungId: abrechnung.id,
                    abrechnungsJahr: abrechnung.abrechnungsJahr
                )
                if !nummerCheck.allowed {
                    validierungsFehler = nummerCheck.message
                    showValidierungsFehler = true
                    return
                }
            }
            
            let newW = Wohnung(
                hausAbrechnungId: abrechnung.id,
                wohnungsnummer: wohnungsnummer.isEmpty ? nil : wohnungsnummer,
                bezeichnung: bezeichnung.trimmingCharacters(in: .whitespacesAndNewlines),
                qm: q,
                name: name.isEmpty ? nil : name,
                strasse: strasse.isEmpty ? nil : strasse,
                plz: plz.isEmpty ? nil : plz,
                ort: ort.isEmpty ? nil : ort,
                email: email.isEmpty ? nil : email,
                telefon: telefon.isEmpty ? nil : telefon
            )
            if let insertedId = DatabaseManager.shared.insertWohnung(newW) {
                savedWohnungId = insertedId
                
                // Wenn eine Wohnungsnummer eingegeben wurde, prüfe ob es einen Vormieter gibt
                if !wohnungsnummer.isEmpty {
                    let trimmedNummer = wohnungsnummer.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let vormieterWohnung = DatabaseManager.shared.getVormieterWohnung(
                        wohnungsnummer: trimmedNummer,
                        hausAbrechnungId: abrechnung.id,
                        ausschliessenId: insertedId
                    ) {
                        // Übernehme Zählerstände vom Vormieter
                        let vormieterZaehlerstaende = DatabaseManager.shared.getZaehlerstaende(byWohnungId: vormieterWohnung.id)
                        
                        for vormieterZaehler in vormieterZaehlerstaende {
                            // Erstelle neuen Zählerstand für Nachmieter mit Endwert des Vormieters als Startwert
                            let neuerZaehlerstand = Zaehlerstand(
                                wohnungId: insertedId,
                                zaehlerTyp: vormieterZaehler.zaehlerTyp,
                                zaehlerNummer: vormieterZaehler.zaehlerNummer,
                                zaehlerStart: vormieterZaehler.zaehlerEnde, // Endwert des Vormieters wird Startwert
                                zaehlerEnde: 0.0, // Wird später eingegeben
                                auchAbwasser: vormieterZaehler.auchAbwasser
                            )
                            _ = DatabaseManager.shared.insertZaehlerstand(neuerZaehlerstand)
                            print("Zählerstand übernommen: \(vormieterZaehler.zaehlerTyp), Start: \(vormieterZaehler.zaehlerEnde)")
                        }
                    }
                }
            }
        }
        
        // Wenn eine Wohnung gespeichert wurde und es temporäre Mietzeiträume gibt, speichere diese
        if let wohnungId = savedWohnungId, !neueMietzeitraeume.isEmpty {
            for temp in neueMietzeitraeume {
                let vonDatumISO = dateToISO(temp.vonDatum)
                let bisDatumISO = dateToISO(temp.bisDatum)
                _ = DatabaseManager.shared.insertMietzeitraum(Mietzeitraum(
                    wohnungId: wohnungId,
                    jahr: abrechnung.abrechnungsJahr,
                    hauptmieterName: name.isEmpty ? "(Kein Name)" : name,
                    vonDatum: vonDatumISO,
                    bisDatum: bisDatumISO,
                    anzahlPersonen: temp.anzahlPersonen,
                    mietendeOption: temp.mietendeOption
                ))
            }
        }
        
        // Prüfe Validierung nach dem Speichern (in der richtigen Reihenfolge)
        let validierung = DatabaseManager.shared.pruefeWohnungenValidierung(hausId: abrechnung.id)
        print("Prüfung im Sheet - Erfolgreich: \(validierung.erfolgreich), Fehler: \(validierung.fehlermeldung ?? "kein"), Erfolg: \(validierung.erfolgsmeldung ?? "kein")")
        
        // Formular immer schließen und zur Übersicht wechseln
        onSave()
        dismiss()
    }
    
    private func loadMietzeitraeume(wohnungId: Int64) {
        mietzeitraeume = DatabaseManager.shared.getMietzeitraeume(byWohnungId: wohnungId)
        mietzeitraumFotosByMietzeitraum = Dictionary(uniqueKeysWithValues: mietzeitraeume.map { ($0.id, DatabaseManager.shared.getMietzeitraumFotos(byMietzeitraumId: $0.id)) })
    }
}

private struct AddMietzeitraumSheet: View {
    let istGesperrt: Bool
    let hauptmieterName: String
    let abrechnungsJahr: Int
    @Binding var vonDatum: Date
    @Binding var bisDatum: Date
    @Binding var anzahlPersonenText: String
    @Binding var mietendeOption: MietendeOption
    let isEdit: Bool
    let onSave: (@escaping () -> Void) -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    private var jahrStart: Date {
        var components = DateComponents(year: abrechnungsJahr, month: 1, day: 1)
        return Calendar.current.date(from: components) ?? Date()
    }
    
    private var jahrEnde: Date {
        var components = DateComponents(year: abrechnungsJahr, month: 12, day: 31)
        return Calendar.current.date(from: components) ?? Date()
    }
    
    private var isValidInput: Bool {
        let anzahlValid = !anzahlPersonenText.isEmpty && Int(anzahlPersonenText) != nil && (Int(anzahlPersonenText) ?? 0) > 0
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
                        .environment(\.locale, Locale(identifier: "de_DE"))
                    DatePicker("Bis", selection: $bisDatum, in: jahrStart...jahrEnde, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "de_DE"))
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
                    Text("Die Daten müssen im Abrechnungsjahr \(abrechnungsJahr) liegen. Das Einzugsdatum muss nach dem Auszugsdatum des vorherigen Hauptmieters liegen. \"Gekündigt zum Mietzeitende\": Mieter wird beim Jahreswechsel nicht ins neue Jahr übernommen.")
                }
            }
            .navigationTitle(isEdit ? "Mietzeitraum bearbeiten" : "Neuer Mietzeitraum")
            .onAppear {
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
