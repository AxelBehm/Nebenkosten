//
//  StartView.swift
//  Nebenkosten
//
//  Created by Axel Behm on 22.01.26.
//

import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

/// Thumbnail für ein gespeichertes Haus-Foto
private struct HausFotoThumbnailView: View {
    let imagePath: String
    var body: some View {
        let url = DatabaseManager.shared.hausFotoFullURL(imagePath: imagePath)
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

/// Vollbild-Ansicht für ein Haus-Foto (mit Anzeige/Bearbeitung der Bildbezeichnung)
private struct HausFotoFullScreenView: View {
    let foto: HausFoto
    @State private var bildbezeichnung: String
    let onBezeichnungSaved: () -> Void
    init(foto: HausFoto, onBezeichnungSaved: @escaping () -> Void) {
        self.foto = foto
        self._bildbezeichnung = State(initialValue: foto.bildbezeichnung)
        self.onBezeichnungSaved = onBezeichnungSaved
    }
    var body: some View {
        VStack(spacing: 0) {
            TextField("Bildbezeichnung", text: $bildbezeichnung, prompt: Text("Bezeichnung eingeben"))
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .onSubmit {
                    _ = DatabaseManager.shared.updateHausFotoBezeichnung(id: foto.id, bildbezeichnung: bildbezeichnung)
                    onBezeichnungSaved()
                }
            let url = DatabaseManager.shared.hausFotoFullURL(imagePath: foto.imagePath)
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

/// Eine Zelle im Bild-Grid: Thumbnail + Bezeichnung
private struct HausFotoZelleView: View {
    let foto: HausFoto
    let key: String
    let istGesperrt: Bool
    let onDelete: () -> Void
    let onTapToView: () -> Void
    let onReload: () -> Void
    @State private var bezeichnung: String
    init(foto: HausFoto, key: String, istGesperrt: Bool, onDelete: @escaping () -> Void, onTapToView: @escaping () -> Void, onReload: @escaping () -> Void) {
        self.foto = foto
        self.key = key
        self.istGesperrt = istGesperrt
        self.onDelete = onDelete
        self.onTapToView = onTapToView
        self.onReload = onReload
        self._bezeichnung = State(initialValue: foto.bildbezeichnung)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HausFotoThumbnailView(imagePath: foto.imagePath)
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
                        _ = DatabaseManager.shared.updateHausFotoBezeichnung(id: foto.id, bildbezeichnung: bezeichnung)
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

/// Zeilen-View für die Abrechnungsliste – Löschen eines Jahres ist in System-Funktionen.
private struct AbrechnungListRowView: View {
    let abrechnung: HausAbrechnung
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "house.fill")
                .font(.title2)
                .foregroundStyle(Color.appBlue)
                .frame(width: 28, alignment: .center)
            VStack(alignment: .leading, spacing: 6) {
                #if os(macOS)
                HStack(spacing: 4) {
                    Text("Straße mit Hausnummer:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(abrechnung.hausBezeichnung.isEmpty ? "(Keine Angabe)" : abrechnung.hausBezeichnung)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                #else
                Text(abrechnung.hausBezeichnung.isEmpty ? "(Keine Angabe)" : abrechnung.hausBezeichnung)
                    .font(.headline)
                    .foregroundColor(.primary)
                #endif
                #if os(macOS)
                HStack(spacing: 4) {
                    Text("Abrechnungsjahr:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(abrechnung.abrechnungsJahr))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                #else
                Text(String(abrechnung.abrechnungsJahr))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                #endif
                // PLZ und Ort anzeigen
                if let plz = abrechnung.postleitzahl, !plz.isEmpty,
                   let ort = abrechnung.ort, !ort.isEmpty {
                    Text("\(plz) \(ort)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if let plz = abrechnung.postleitzahl, !plz.isEmpty {
                    Text(plz)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if let ort = abrechnung.ort, !ort.isEmpty {
                    Text(ort)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            HStack(spacing: 8) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
                Menu {
                    Button(action: onEdit) {
                        Label("Bearbeiten", systemImage: "pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        #if os(iOS)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(action: onEdit) {
                Label("Bearbeiten", systemImage: "pencil")
            }
            .tint(.blue)
        }
        #endif
    }
}

struct StartView: View {
    @State private var hausAbrechnungen: [HausAbrechnung] = []
    @State private var selectedAbrechnung: HausAbrechnung?
    @State private var showAddDialog = false
    @State private var showEditDialog = false
    @State private var editingAbrechnung: HausAbrechnung?
    @State private var newHausBezeichnung = ""
    @State private var newAbrechnungsJahr = Calendar.current.component(.year, from: Date()) - 1
    @State private var newPostleitzahl = ""
    @State private var newOrt = ""
    @State private var newGesamtflaeche: Int?
    @State private var newAnzahlWohnungen: Int?
    @State private var newLeerstandspruefung: Leerstandspruefung?
    @State private var newVerwalterName = ""
    @State private var newVerwalterStrasse = ""
    @State private var newVerwalterPLZOrt = ""
    @State private var newVerwalterEmail = ""
    @State private var newVerwalterTelefon = ""
    @State private var newVerwalterInEmailVorbelegen = false
    @State private var navigationPath = NavigationPath()
    @State private var showAbrechnungAlert = false
    @State private var qmPruefungsFehler: String? = nil
    @State private var showQmPruefungsFehler = false
    @State private var qmPruefungsErfolg: String? = nil
    @State private var showQmPruefungsErfolg = false
    @State private var showAbrechnungsForm = false
    @State private var showEinzelnachweisErfassung = false
    @State private var showOnlyCurrentYears = false
    @State private var showEinstellungen = false
    @State private var showUpgrade = false
    @State private var showStartUpgradeHint = false
    @State private var limitErrorMessage: String?
    @State private var showLimitError = false
    @ObservedObject private var purchaseManager = PurchaseManager.shared
    
    var body: some View {
        mainNavigationContent
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "building.2")
                .font(.system(size: 60))
                .foregroundStyle(Color.appBlue)
            Text("Keine Abrechnungen vorhanden")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Erstellen Sie eine neue Abrechnung")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button(action: { showAddDialog = true }) {
                Label("Haus hinzufügen", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
            Button(action: { showEinstellungen = true }) {
                Text("Muster-Haus über Einstellungen möglich")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var addAbrechnungSheetContent: some View {
        AddAbrechnungView(
            hausBezeichnung: $newHausBezeichnung,
            abrechnungsJahr: $newAbrechnungsJahr,
            postleitzahl: $newPostleitzahl,
            ort: $newOrt,
            gesamtflaeche: $newGesamtflaeche,
            anzahlWohnungen: $newAnzahlWohnungen,
            leerstandspruefung: $newLeerstandspruefung,
            verwalterName: $newVerwalterName,
            verwalterStrasse: $newVerwalterStrasse,
            verwalterPLZOrt: $newVerwalterPLZOrt,
            verwalterEmail: $newVerwalterEmail,
            verwalterTelefon: $newVerwalterTelefon,
            verwalterInEmailVorbelegen: $newVerwalterInEmailVorbelegen,
            title: "Haus Anlage/Pflege",
            onSave: {
                // Prüfe Limits vor dem Speichern
                let limitCheck = LimitManager.shared.canCreateHaus(
                    strasse: newHausBezeichnung,
                    ort: newOrt.isEmpty ? nil : newOrt
                )
                if !limitCheck.allowed {
                    limitErrorMessage = limitCheck.message
                    showLimitError = true
                    return
                }
                
                let hausAbrechnung = HausAbrechnung(
                    hausBezeichnung: newHausBezeichnung,
                    abrechnungsJahr: newAbrechnungsJahr,
                    postleitzahl: newPostleitzahl.isEmpty ? nil : newPostleitzahl,
                    ort: newOrt.isEmpty ? nil : newOrt,
                    gesamtflaeche: newGesamtflaeche,
                    anzahlWohnungen: newAnzahlWohnungen,
                    leerstandspruefung: newLeerstandspruefung,
                    verwalterName: newVerwalterName.isEmpty ? nil : newVerwalterName,
                    verwalterStrasse: newVerwalterStrasse.isEmpty ? nil : newVerwalterStrasse,
                    verwalterPLZOrt: newVerwalterPLZOrt.isEmpty ? nil : newVerwalterPLZOrt,
                    verwalterEmail: newVerwalterEmail.isEmpty ? nil : newVerwalterEmail,
                    verwalterTelefon: newVerwalterTelefon.isEmpty ? nil : newVerwalterTelefon,
                    verwalterInEmailVorbelegen: newVerwalterInEmailVorbelegen
                )
                let success = DatabaseManager.shared.insert(hausAbrechnung: hausAbrechnung)
                newHausBezeichnung = ""
                newAbrechnungsJahr = Calendar.current.component(.year, from: Date()) - 1
                newPostleitzahl = ""
                newOrt = ""
                newGesamtflaeche = nil
                newAnzahlWohnungen = nil
                newLeerstandspruefung = nil
                newVerwalterName = ""
                newVerwalterStrasse = ""
                newVerwalterPLZOrt = ""
                newVerwalterEmail = ""
                newVerwalterTelefon = ""
                newVerwalterInEmailVorbelegen = false
                if success { hausAbrechnungen = DatabaseManager.shared.getAll() }
            },
            onCancel: {
                newHausBezeichnung = ""
                newAbrechnungsJahr = Calendar.current.component(.year, from: Date()) - 1
                newPostleitzahl = ""
                newOrt = ""
                newGesamtflaeche = nil
                newAnzahlWohnungen = nil
                newLeerstandspruefung = nil
                newVerwalterName = ""
                newVerwalterStrasse = ""
                newVerwalterPLZOrt = ""
                newVerwalterEmail = ""
                newVerwalterTelefon = ""
                newVerwalterInEmailVorbelegen = false
            }
        )
    }
    
    @ViewBuilder
    private var editAbrechnungSheetContent: some View {
        if let editing = editingAbrechnung {
            let istGesperrt = DatabaseManager.shared.istJahrGesperrt(hausBezeichnung: editing.hausBezeichnung, jahr: editing.abrechnungsJahr)
            AddAbrechnungView(
                hausBezeichnung: $newHausBezeichnung,
                abrechnungsJahr: $newAbrechnungsJahr,
                postleitzahl: $newPostleitzahl,
                ort: $newOrt,
                gesamtflaeche: $newGesamtflaeche,
                anzahlWohnungen: $newAnzahlWohnungen,
                leerstandspruefung: $newLeerstandspruefung,
                verwalterName: $newVerwalterName,
                verwalterStrasse: $newVerwalterStrasse,
                verwalterPLZOrt: $newVerwalterPLZOrt,
                verwalterEmail: $newVerwalterEmail,
                verwalterTelefon: $newVerwalterTelefon,
                verwalterInEmailVorbelegen: $newVerwalterInEmailVorbelegen,
                title: "Abrechnung bearbeiten",
                onSave: {
                    if let editing = editingAbrechnung,
                       !DatabaseManager.shared.istJahrGesperrt(hausBezeichnung: editing.hausBezeichnung, jahr: editing.abrechnungsJahr) {
                        if newHausBezeichnung != editing.hausBezeichnung {
                            DatabaseManager.shared.updateHausFotoHausBezeichnung(from: editing.hausBezeichnung, to: newHausBezeichnung)
                        }
                        let updatedAbrechnung = HausAbrechnung(
                            id: editing.id,
                            hausBezeichnung: newHausBezeichnung,
                            abrechnungsJahr: editing.abrechnungsJahr,
                            postleitzahl: newPostleitzahl.isEmpty ? nil : newPostleitzahl,
                            ort: newOrt.isEmpty ? nil : newOrt,
                            gesamtflaeche: newGesamtflaeche,
                            anzahlWohnungen: newAnzahlWohnungen,
                            leerstandspruefung: newLeerstandspruefung,
                            verwalterName: newVerwalterName.isEmpty ? nil : newVerwalterName,
                            verwalterStrasse: newVerwalterStrasse.isEmpty ? nil : newVerwalterStrasse,
                            verwalterPLZOrt: newVerwalterPLZOrt.isEmpty ? nil : newVerwalterPLZOrt,
                            verwalterEmail: newVerwalterEmail.isEmpty ? nil : newVerwalterEmail,
                            verwalterTelefon: newVerwalterTelefon.isEmpty ? nil : newVerwalterTelefon,
                            verwalterInEmailVorbelegen: newVerwalterInEmailVorbelegen
                        )
                        let success = DatabaseManager.shared.update(hausAbrechnung: updatedAbrechnung)
                        let editedId = editing.id
                        editingAbrechnung = nil
                        newHausBezeichnung = ""
                        newAbrechnungsJahr = Calendar.current.component(.year, from: Date()) - 1
                        newPostleitzahl = ""
                        newOrt = ""
                        newGesamtflaeche = nil
                        newAnzahlWohnungen = nil
                        newLeerstandspruefung = nil
                        newVerwalterName = ""
                        newVerwalterStrasse = ""
                        newVerwalterPLZOrt = ""
                        newVerwalterEmail = ""
                        newVerwalterTelefon = ""
                        newVerwalterInEmailVorbelegen = false
                        if success {
                            hausAbrechnungen = DatabaseManager.shared.getAll()
                            // Ausgewähltes Haus aktualisieren, damit WohnungenView die neuen Daten (z. B. anzahlWohnungen) erhält
                            if selectedAbrechnung?.id == editedId,
                               let aktualisiert = hausAbrechnungen.first(where: { $0.id == editedId }) {
                                selectedAbrechnung = aktualisiert
                            }
                        }
                    }
                },
                onCancel: {
                    editingAbrechnung = nil
                    newHausBezeichnung = ""
                    newAbrechnungsJahr = Calendar.current.component(.year, from: Date()) - 1
                    newPostleitzahl = ""
                    newOrt = ""
                    newGesamtflaeche = nil
                    newAnzahlWohnungen = nil
                    newLeerstandspruefung = nil
                    newVerwalterName = ""
                    newVerwalterStrasse = ""
                    newVerwalterPLZOrt = ""
                    newVerwalterEmail = ""
                    newVerwalterTelefon = ""
                    newVerwalterInEmailVorbelegen = false
                },
                isEditMode: true,
                istGesperrt: istGesperrt,
                hausBezeichnungForFotos: editing.hausBezeichnung
            )
        }
    }
    
    @ViewBuilder
    private var mainNavigationContent: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 20) {
                if hausAbrechnungen.isEmpty {
                    emptyStateView
                } else {
                    abrechnungListContent
                        .listStyle(.insetGrouped)
                }
                actionButtonsSection
                    .padding(.vertical, 8)
                    #if os(iOS)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    #else
                    .background(Color(nsColor: .windowBackgroundColor))
                    #endif
            }
            .navigationTitle("Nebenkostenabrechnung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 12) {
                        NavigationLink(destination: SystemFunktionenView(selectedAbrechnung: selectedAbrechnung, onAbrechnungDeleted: {
                            hausAbrechnungen = DatabaseManager.shared.getAll()
                            if selectedAbrechnung != nil { selectedAbrechnung = nil }
                            navigationPath = NavigationPath()
                        }, onJahreswechselErfolgreich: {
                            hausAbrechnungen = DatabaseManager.shared.getAll()
                        }, onDatabaseReset: {
                            hausAbrechnungen = DatabaseManager.shared.getAll()
                            selectedAbrechnung = nil
                            navigationPath = NavigationPath()
                        }, onImportSuccess: {
                            hausAbrechnungen = DatabaseManager.shared.getAll()
                        })) {
                            Label("System", systemImage: "gearshape.2")
                        }
                        Button(action: {
                            showEinstellungen = true
                        }) {
                            Label("Einstellungen", systemImage: "gearshape.fill")
                        }
                    }
                }
                ToolbarItem(placement: .principal) {
                    Toggle(isOn: $showOnlyCurrentYears) {
                        Text("Nur aktuelle Jahre")
                            .font(.caption)
                    }
                    .toggleStyle(.switch)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
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
                        Button(action: {
                            showAddDialog = true
                        }) {
                            Label("Haus hinzufügen", systemImage: "plus.circle.fill")
                        }
                    }
                }
            }
        }
        .navigationDestination(for: HausAbrechnung.self) { abrechnung in
            WohnungenView(abrechnung: abrechnung)
        }
        .navigationDestination(for: Wohnung.self) { wohnung in
            if let abrechnung = hausAbrechnungen.first(where: { $0.id == wohnung.hausAbrechnungId }) {
                ZaehlerstaendeView(wohnung: wohnung, haus: abrechnung)
            }
        }
        .onAppear {
            hausAbrechnungen = DatabaseManager.shared.getAll()
            // Falls noch kein Haus markiert: ersten angezeigten Satz markieren
            if selectedAbrechnung == nil, let first = displayedAbrechnungen().first {
                selectedAbrechnung = first
            }
            Task {
                await purchaseManager.checkPurchaseStatus()
            }
        }
        .onChange(of: hausAbrechnungen) { _, _ in
            if selectedAbrechnung == nil, let first = displayedAbrechnungen().first {
                selectedAbrechnung = first
            }
        }
        .onChange(of: showOnlyCurrentYears) { _, _ in
            if selectedAbrechnung == nil, let first = displayedAbrechnungen().first {
                selectedAbrechnung = first
            }
        }
        .onChange(of: showAddDialog) { oldValue, newValue in
            if !newValue && oldValue {
                hausAbrechnungen = DatabaseManager.shared.getAll()
            }
        }
        .onChange(of: showEditDialog) { oldValue, newValue in
            if !newValue && oldValue {
                hausAbrechnungen = DatabaseManager.shared.getAll()
            }
        }
        .onChange(of: showQmPruefungsErfolg) { oldValue, newValue in
            if !newValue && oldValue && selectedAbrechnung != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showEinzelnachweisErfassung = true
                }
            }
        }
        .onChange(of: showEinzelnachweisErfassung) { oldValue, newValue in
            if !newValue && oldValue && selectedAbrechnung != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showAbrechnungsForm = true
                }
            }
        }
        .fullScreenCover(isPresented: $showAddDialog) {
            addAbrechnungSheetContent
        }
        .fullScreenCover(isPresented: $showEditDialog) {
            editAbrechnungSheetContent
        }
        .alert("Kein Haus ausgewählt", isPresented: $showAbrechnungAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Bitte wählen Sie zuerst ein Haus aus, bevor Sie auf Wohnungen oder Abrechnung zugreifen (Strasse anklicken). Es darf nur ein Haus markiert werden.")
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
        .fullScreenCover(isPresented: $showEinzelnachweisErfassung) {
            if let haus = selectedAbrechnung {
                EinzelnachweisErfassungView(abrechnung: haus)
            }
        }
        .fullScreenCover(isPresented: $showAbrechnungsForm) {
            if let haus = selectedAbrechnung {
                NavigationStack {
                    AbrechnungsFormView(abrechnung: haus)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Schließen") {
                                    showAbrechnungsForm = false
                                }
                            }
                        }
                }
            }
        }
        .fullScreenCover(isPresented: $showEinstellungen) {
            EinstellungenView(onMusterhausCreated: {
                hausAbrechnungen = DatabaseManager.shared.getAll()
                let jahr = Calendar.current.component(.year, from: Date()) - 1
                if let muster = hausAbrechnungen.first(where: { $0.hausBezeichnung == "Musterstraße 1" && $0.ort == "Musterstadt" && $0.abrechnungsJahr == jahr }) {
                    selectedAbrechnung = muster
                }
                showEinstellungen = false
            })
        }
        .fullScreenCover(isPresented: $showUpgrade) {
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
        .alert("Upgrade zur Vollversion", isPresented: $showStartUpgradeHint) {
            Button("Später", role: .cancel) { }
            Button("Jetzt upgraden") {
                showUpgrade = true
            }
        } message: {
            if let message = LimitManager.shared.hasReachedLimits().message {
                Text("\(message)\n\nKosten: 29,99 € einmalig")
            }
        }
    }
    
    /// Angezeigte Abrechnungen (je nach „Nur aktuelle Jahre“ gefiltert)
    private func displayedAbrechnungen() -> [HausAbrechnung] {
        if showOnlyCurrentYears {
            let groupedByHaus = Dictionary(grouping: hausAbrechnungen) { $0.hausBezeichnung }
            return groupedByHaus.values.compactMap { $0.max(by: { $0.abrechnungsJahr < $1.abrechnungsJahr }) }
        }
        return hausAbrechnungen
    }
    
    private var abrechnungListContent: some View {
        let filteredAbrechnungen = displayedAbrechnungen()
        
        return List {
            Section {
                ForEach(Array(filteredAbrechnungen), id: \.id) { abrechnung in
                    AbrechnungListRowView(
                        abrechnung: abrechnung,
                        isSelected: selectedAbrechnung?.id == abrechnung.id,
                        onSelect: { selectedAbrechnung = abrechnung },
                        onEdit: { fillFormAndShowEdit(abrechnung) }
                    )
                }
            } header: {
                Text("Hausübersicht")
                    .font(.headline)
            }
        }
        .scrollIndicators(.visible)
    }
    
    private func fillFormAndShowEdit(_ abrechnung: HausAbrechnung) {
        // Auch bei gesperrten Jahren öffnen, damit Daten angezeigt werden können (Speichern bleibt deaktiviert).
        editingAbrechnung = abrechnung
        newHausBezeichnung = abrechnung.hausBezeichnung
        newAbrechnungsJahr = abrechnung.abrechnungsJahr
        newPostleitzahl = abrechnung.postleitzahl ?? ""
        newOrt = abrechnung.ort ?? ""
        newGesamtflaeche = abrechnung.gesamtflaeche
        newAnzahlWohnungen = abrechnung.anzahlWohnungen
        newLeerstandspruefung = abrechnung.leerstandspruefung
        newVerwalterName = abrechnung.verwalterName ?? ""
        newVerwalterStrasse = abrechnung.verwalterStrasse ?? ""
        newVerwalterPLZOrt = abrechnung.verwalterPLZOrt ?? ""
        newVerwalterEmail = abrechnung.verwalterEmail ?? ""
        newVerwalterTelefon = abrechnung.verwalterTelefon ?? ""
        newVerwalterInEmailVorbelegen = abrechnung.verwalterInEmailVorbelegen ?? false
        showEditDialog = true
    }
    
    private var actionButtonsSection: some View {
        HStack(spacing: 12) {
            Spacer()
            if let haus = selectedAbrechnung {
                NavigationLink(destination: WohnungenView(abrechnung: haus)) {
                    VStack(spacing: 4) {
                        AppSymbol(systemName: "door.left.hand.open", backgroundColor: .appBlue)
                        Text("Whng.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Button(action: { showAbrechnungAlert = true }) {
                    VStack(spacing: 4) {
                        AppSymbol(systemName: "door.left.hand.open", backgroundColor: .appBlue.opacity(0.5))
                        Text("Whng.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if let haus = selectedAbrechnung {
                NavigationLink(destination: ZaehlerdatenErfassungView(abrechnung: haus)) {
                    VStack(spacing: 4) {
                        AppSymbol(systemName: "gauge.with.dots.needle.67percent", backgroundColor: .appBlue.opacity(0.85))
                        Text("Zähler")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Button(action: { showAbrechnungAlert = true }) {
                    VStack(spacing: 4) {
                        AppSymbol(systemName: "gauge.with.dots.needle.67percent", backgroundColor: .appBlue.opacity(0.5))
                        Text("Zähler")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if let haus = selectedAbrechnung {
                NavigationLink(destination: KostenView(abrechnung: haus)) {
                    VStack(spacing: 4) {
                        AppSymbol(systemName: "eurosign.circle", backgroundColor: .appOrange)
                        Text("Kosten")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Button(action: { showAbrechnungAlert = true }) {
                    VStack(spacing: 4) {
                        AppSymbol(systemName: "eurosign.circle", backgroundColor: .appOrange.opacity(0.5))
                        Text("Kosten")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Button(action: {
                if selectedAbrechnung == nil {
                    showAbrechnungAlert = true
                } else {
                    if let haus = selectedAbrechnung {
                        let validierung = DatabaseManager.shared.pruefeWohnungenValidierung(hausId: haus.id)
                        if !validierung.erfolgreich {
                            qmPruefungsFehler = validierung.fehlermeldung ?? "Validierungsfehler aufgetreten."
                            showQmPruefungsFehler = true
                        } else if let erfolg = validierung.erfolgsmeldung {
                            qmPruefungsErfolg = erfolg + "\n\nEinzelnachweis-Erfassung wird geöffnet..."
                            showQmPruefungsErfolg = true
                        } else {
                            qmPruefungsErfolg = "Keine Prüfungen durchgeführt.\n\nBitte geben Sie im Haus 'Anzahl Wohnungen' oder 'Gesamtfläche' an, um Prüfungen durchzuführen."
                            showQmPruefungsErfolg = true
                        }
                    }
                }
            }) {
                VStack(spacing: 4) {
                    AppSymbol(systemName: "doc.text.fill", backgroundColor: .appGreen)
                    Text("Abrechng.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.bottom)
    }
}

struct AddAbrechnungView: View {
    @Binding var hausBezeichnung: String
    @Binding var abrechnungsJahr: Int
    @Binding var postleitzahl: String
    @Binding var ort: String
    @Binding var gesamtflaeche: Int?
    @Binding var anzahlWohnungen: Int?
    @Binding var leerstandspruefung: Leerstandspruefung?
    @Binding var verwalterName: String
    @Binding var verwalterStrasse: String
    @Binding var verwalterPLZOrt: String
    @Binding var verwalterEmail: String
    @Binding var verwalterTelefon: String
    @Binding var verwalterInEmailVorbelegen: Bool
    let title: String
    let onSave: () -> Void
    let onCancel: () -> Void
    let isEditMode: Bool
    let istGesperrt: Bool
    /// Bei Bearbeiten: Hausbezeichnung, unter der Fotos geladen/gespeichert werden (unabhängig vom Jahr)
    let hausBezeichnungForFotos: String?
    
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isHausFocused: Bool
    @State private var gesamtflaecheText = ""
    @State private var anzahlWohnungenText = ""
    @State private var hausFotos: [HausFoto] = []
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var fotoZumAnzeigen: HausFoto?
    
    init(
        hausBezeichnung: Binding<String>,
        abrechnungsJahr: Binding<Int>,
        postleitzahl: Binding<String>,
        ort: Binding<String>,
        gesamtflaeche: Binding<Int?>,
        anzahlWohnungen: Binding<Int?>,
        leerstandspruefung: Binding<Leerstandspruefung?>,
        verwalterName: Binding<String>,
        verwalterStrasse: Binding<String>,
        verwalterPLZOrt: Binding<String>,
        verwalterEmail: Binding<String>,
        verwalterTelefon: Binding<String>,
        verwalterInEmailVorbelegen: Binding<Bool>,
        title: String,
        onSave: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        isEditMode: Bool = false,
        istGesperrt: Bool = false,
        hausBezeichnungForFotos: String? = nil
    ) {
        self._hausBezeichnung = hausBezeichnung
        self._abrechnungsJahr = abrechnungsJahr
        self._postleitzahl = postleitzahl
        self._ort = ort
        self._gesamtflaeche = gesamtflaeche
        self._anzahlWohnungen = anzahlWohnungen
        self._leerstandspruefung = leerstandspruefung
        self._verwalterName = verwalterName
        self._verwalterStrasse = verwalterStrasse
        self._verwalterPLZOrt = verwalterPLZOrt
        self._verwalterEmail = verwalterEmail
        self._verwalterTelefon = verwalterTelefon
        self._verwalterInEmailVorbelegen = verwalterInEmailVorbelegen
        self.title = title
        self.onSave = onSave
        self.onCancel = onCancel
        self.isEditMode = isEditMode
        self.istGesperrt = istGesperrt
        self.hausBezeichnungForFotos = hausBezeichnungForFotos
    }
    
    var body: some View {
        NavigationStack {
            Form {
                if istGesperrt {
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
                
                Section(header: Text("Straße mit Hausnummer")
                    .frame(maxWidth: .infinity, alignment: .leading)) {
                    TextField("z.B. Musterstraße 1", text: $hausBezeichnung)
                        .focused($isHausFocused)
                        .multilineTextAlignment(.leading)
                        .disabled(istGesperrt)
                        #if os(macOS)
                        .textFieldStyle(.roundedBorder)
                        #endif
                }
                
                Section(header: Text("Abrechnungsjahr")
                    .frame(maxWidth: .infinity, alignment: .leading)) {
                    HStack {
                        TextField("Jahr", value: $abrechnungsJahr, format: .number.grouping(.never))
                            .multilineTextAlignment(.leading)
                            .disabled(isEditMode)
                            .onChange(of: abrechnungsJahr) { oldValue, newValue in
                                if !isEditMode {
                                    if newValue < 1900 {
                                        abrechnungsJahr = 1900
                                    } else if newValue > 2099 {
                                        abrechnungsJahr = 2099
                                    }
                                }
                            }
                        Stepper("", value: $abrechnungsJahr, in: 1900...2099)
                            .disabled(isEditMode)
                    }
                    if isEditMode {
                        Text("Das Abrechnungsjahr kann nach der Anlage nicht mehr geändert werden.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Adresse")
                    .frame(maxWidth: .infinity, alignment: .leading)) {
                    TextField("Postleitzahl", text: $postleitzahl)
                        .keyboardType(.numberPad)
                        .disabled(istGesperrt)
                        #if os(macOS)
                        .textFieldStyle(.roundedBorder)
                        #endif
                    TextField("Ort", text: $ort)
                        .disabled(istGesperrt)
                        #if os(macOS)
                        .textFieldStyle(.roundedBorder)
                        #endif
                }
                
                Section(header: Text("Hausdaten")
                    .frame(maxWidth: .infinity, alignment: .leading)) {
                    HStack {
                        TextField("Gesamtfläche (m²)", text: $gesamtflaecheText)
                            .keyboardType(.numberPad)
                            .disabled(istGesperrt)
                            .onChange(of: gesamtflaecheText) { oldValue, newValue in
                                if newValue.isEmpty {
                                    gesamtflaeche = nil
                                } else {
                                    gesamtflaeche = Int(newValue)
                                }
                            }
                            .onChange(of: gesamtflaeche) { oldValue, newValue in
                                if let value = newValue {
                                    let str = String(value)
                                    if gesamtflaecheText != str { gesamtflaecheText = str }
                                } else if !gesamtflaecheText.isEmpty {
                                    gesamtflaecheText = ""
                                }
                            }
                            #if os(macOS)
                            .textFieldStyle(.roundedBorder)
                            #endif
                    }
                    HStack {
                        TextField("Anzahl Wohnungen", text: $anzahlWohnungenText)
                            .keyboardType(.numberPad)
                            .disabled(istGesperrt)
                            .onChange(of: anzahlWohnungenText) { oldValue, newValue in
                                if newValue.isEmpty {
                                    anzahlWohnungen = nil
                                } else if let intValue = Int(newValue) {
                                    anzahlWohnungen = intValue
                                }
                            }
                            .onChange(of: anzahlWohnungen) { oldValue, newValue in
                                if let value = newValue {
                                    let str = String(value)
                                    if anzahlWohnungenText != str { anzahlWohnungenText = str }
                                } else if !anzahlWohnungenText.isEmpty {
                                    anzahlWohnungenText = ""
                                }
                            }
                            #if os(macOS)
                            .textFieldStyle(.roundedBorder)
                            #endif
                    }
                    Picker("Leerstandsprüfung", selection: $leerstandspruefung) {
                        Text("Keine Auswahl").tag(Optional<Leerstandspruefung>(nil))
                        ForEach(Leerstandspruefung.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(Optional(option))
                        }
                    }
                    .disabled(istGesperrt)
                }
                
                Section(header: Text("Verwalter")
                    .frame(maxWidth: .infinity, alignment: .leading)) {
                    TextField("Name", text: $verwalterName)
                        .disabled(istGesperrt)
                        #if os(macOS)
                        .textFieldStyle(.roundedBorder)
                        #endif
                    TextField("Straße", text: $verwalterStrasse)
                        .disabled(istGesperrt)
                        #if os(macOS)
                        .textFieldStyle(.roundedBorder)
                        #endif
                    TextField("PLZ/Ort", text: $verwalterPLZOrt)
                        .disabled(istGesperrt)
                        #if os(macOS)
                        .textFieldStyle(.roundedBorder)
                        #endif
                    TextField("E-Mail", text: $verwalterEmail)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disabled(istGesperrt)
                        #if os(macOS)
                        .textFieldStyle(.roundedBorder)
                        #endif
                    TextField("Telefon", text: $verwalterTelefon)
                        .keyboardType(.phonePad)
                        .disabled(istGesperrt)
                        #if os(macOS)
                        .textFieldStyle(.roundedBorder)
                        #endif
                    Toggle("Verwalter in E-Mail vorbelegen", isOn: $verwalterInEmailVorbelegen)
                        .disabled(istGesperrt)
                }
                
                #if os(iOS)
                if isEditMode, let key = hausBezeichnungForFotos, !key.isEmpty {
                    Section {
                        if !hausFotos.isEmpty {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                                ForEach(hausFotos) { foto in
                                    HausFotoZelleView(
                                        foto: foto,
                                        key: key,
                                        istGesperrt: istGesperrt,
                                        onDelete: {
                                            let furl = DatabaseManager.shared.hausFotoFullURL(imagePath: foto.imagePath)
                                            if FileManager.default.fileExists(atPath: furl.path) {
                                                try? FileManager.default.removeItem(at: furl)
                                            }
                                            _ = DatabaseManager.shared.deleteHausFoto(id: foto.id)
                                            hausFotos = DatabaseManager.shared.getHausFotos(byHausBezeichnung: key)
                                        },
                                        onTapToView: { fotoZumAnzeigen = foto },
                                        onReload: { hausFotos = DatabaseManager.shared.getHausFotos(byHausBezeichnung: key) }
                                    )
                                }
                            }
                            .padding(.vertical, 4)
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
                                guard let key = hausBezeichnungForFotos, !items.isEmpty else { return }
                                Task {
                                    let db = DatabaseManager.shared
                                    let ordnerURL = db.hausFotoOrdnerURL(hausBezeichnung: key)
                                    let nextOrder = db.getHausFotos(byHausBezeichnung: key).count
                                    for (idx, item) in items.enumerated() {
                                        if let data = try? await item.loadTransferable(type: Data.self), !data.isEmpty {
                                            let filename = "img_\(UUID().uuidString).jpg"
                                            let fileURL = ordnerURL.appendingPathComponent(filename)
                                            try? data.write(to: fileURL)
                                            let relPath = "\(ordnerURL.lastPathComponent)/\(filename)"
                                            _ = db.insertHausFoto(hausBezeichnung: key, imagePath: relPath, sortOrder: nextOrder + idx)
                                        }
                                    }
                                    await MainActor.run {
                                        selectedPhotoItems = []
                                        hausFotos = DatabaseManager.shared.getHausFotos(byHausBezeichnung: key)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Bilder")
                    } footer: {
                        Text("Fotos dem Haus zuordnen (unabhängig vom Abrechnungsjahr).")
                    }
                }
                #endif
            }
            .formStyle(.grouped)
            .navigationTitle(title)
            .sheet(item: $fotoZumAnzeigen) { foto in
                NavigationStack {
                    HausFotoFullScreenView(foto: foto, onBezeichnungSaved: {
                        if let k = hausBezeichnungForFotos, !k.isEmpty {
                            hausFotos = DatabaseManager.shared.getHausFotos(byHausBezeichnung: k)
                        }
                    })
                    .ignoresSafeArea(edges: .bottom)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Schließen") {
                                fotoZumAnzeigen = nil
                            }
                        }
                    }
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
                        if !hausBezeichnung.isEmpty {
                            onSave()
                            dismiss()
                        }
                    }
                    .disabled(hausBezeichnung.isEmpty || istGesperrt)
                }
            }
            .onAppear {
                if let flaeche = gesamtflaeche {
                    gesamtflaecheText = String(flaeche)
                } else {
                    gesamtflaecheText = ""
                }
                if let anzahl = anzahlWohnungen {
                    anzahlWohnungenText = String(anzahl)
                } else {
                    anzahlWohnungenText = ""
                }
                if let key = hausBezeichnungForFotos, !key.isEmpty {
                    Task {
                        let fotos = DatabaseManager.shared.getHausFotos(byHausBezeichnung: key)
                        await MainActor.run { hausFotos = fotos }
                    }
                }
                // Fokus verzögern, damit Form zuerst rendert – reduziert Trägheit beim ersten Tippen
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    isHausFocused = true
                }
            }
        }
    }
}

struct SystemFunktionenView: View {
    /// Das auf der Startseite markierte Haus – wird für Backup, Jahreswechsel und Jahr löschen verwendet.
    var selectedAbrechnung: HausAbrechnung? = nil
    /// Wird nach dem Löschen einer Abrechnung aufgerufen (z. B. Liste aktualisieren, zurücknavigieren).
    var onAbrechnungDeleted: (() -> Void)? = nil
    /// Wird nach erfolgreichem Jahreswechsel aufgerufen, damit die Übersicht das neue Jahr anzeigt.
    var onJahreswechselErfolgreich: (() -> Void)? = nil
    /// Wird nach erfolgreichem Datenbank-Zurücksetzen aufgerufen (Liste aktualisieren, zurücknavigieren).
    var onDatabaseReset: (() -> Void)? = nil
    /// Wird nach erfolgreichem Import aufgerufen (Liste aktualisieren, damit importierte Häuser angezeigt werden).
    var onImportSuccess: (() -> Void)? = nil
    
    @State private var showCleanupAlert = false
    @State private var showDeleteJahrAlert = false
    @State private var showBackupAlert = false
    @State private var backupMessage = ""
    @State private var backupFileName = ""
    @State private var isBackingUp = false
    @State private var showShareSheet = false
    @State private var backupFileURL: URL?
    @State private var showImportAlert = false
    @State private var importMessage = ""
    @State private var isImporting = false
    @State private var showDocumentPicker = false
    @State private var showJahreswechselAlert = false
    @State private var jahreswechselMessage = ""
    @State private var isJahreswechselActive = false
    @State private var neuesJahr: Int? = nil
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Form {
            Section(header: Text("iCloud Backup")) {
                HStack {
                    Text("Haus")
                    Spacer()
                    if let haus = selectedAbrechnung {
                        Text("\(haus.hausBezeichnung) (\(haus.abrechnungsJahr))")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Bitte auf der Startseite ein Haus markieren (Strasse anklicken)")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Button {
                    backupToiCloud()
                } label: {
                    HStack {
                        if isBackingUp {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "icloud.and.arrow.up")
                        }
                        Text(isBackingUp ? "Backup wird erstellt..." : "In iCloud sichern")
                    }
                }
                .disabled(selectedAbrechnung == nil || isBackingUp)
                
                if !backupFileName.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Letzte Sicherung:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(backupFileName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                        
                        if let url = backupFileURL {
                            Button {
                                showShareSheet = true
                            } label: {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Datei teilen/speichern")
                                }
                                .font(.caption)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.top, 8)
                }
            }
            
            Section(header: Text("Daten wiederherstellen")) {
                Button {
                    showDocumentPicker = true
                } label: {
                    HStack {
                        if isImporting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "icloud.and.arrow.down")
                        }
                        Text(isImporting ? "Daten werden importiert..." : "Backup wiederherstellen")
                    }
                }
                .disabled(isImporting)
            }
            
            Section(header: Text("Jahreswechsel")) {
                    HStack {
                        Text("Haus")
                        Spacer()
                        if let haus = selectedAbrechnung {
                            Text("\(haus.hausBezeichnung) (\(haus.abrechnungsJahr))")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Bitte auf der Startseite ein Haus markieren (Strasse anklicken)")
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    
                    HStack {
                        Text("Neues Jahr:")
                        Spacer()
                        if let haus = selectedAbrechnung {
                            TextField("Jahr", value: Binding(
                                get: { neuesJahr ?? (haus.abrechnungsJahr + 1) },
                                set: { neuesJahr = $0 }
                            ), format: .number.grouping(.never))
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                        } else {
                            TextField("Jahr", value: Binding(
                                get: { neuesJahr ?? Calendar.current.component(.year, from: Date()) },
                                set: { neuesJahr = $0 }
                            ), format: .number.grouping(.never))
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                                .disabled(true)
                        }
                    }
                    
                    Button {
                        jahreswechselDurchfuehren()
                    } label: {
                        HStack {
                            if isJahreswechselActive {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "calendar.badge.plus")
                            }
                            Text(isJahreswechselActive ? "Jahreswechsel wird durchgeführt..." : "Jahreswechsel durchführen")
                        }
                    }
                    .disabled(selectedAbrechnung == nil || isJahreswechselActive)
                }
            
            Section {
                HStack {
                    Text("Haus")
                    Spacer()
                    if let haus = selectedAbrechnung {
                        Text("\(haus.hausBezeichnung) (\(haus.abrechnungsJahr))")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Bitte auf der Startseite ein Haus markieren (Strasse anklicken)")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Button(role: .destructive) {
                    showDeleteJahrAlert = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Dieses Jahr löschen")
                    }
                }
                .disabled(selectedAbrechnung == nil)
            } header: {
                Text("Jahr löschen")
            } footer: {
                Text("Löscht die Abrechnung für das markierte Jahr inklusive aller Wohnungen, Mietzeiträume, Zählerstände und Kosten. Nicht wiederherstellbar.")
            }
            
            Section {
                Button(role: .destructive, action: {
                    showCleanupAlert = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Datenbank zurücksetzen")
                    }
                }
            } header: {
                Text("Datenbank")
            } footer: {
                Text("Setzt die Datenbank zurück und baut sie neu auf. Alle Daten werden gelöscht.")
            }
        }
        .navigationTitle("System-Funktionen")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let h = selectedAbrechnung {
                neuesJahr = h.abrechnungsJahr + 1
            }
        }
        .alert("Jahr löschen?", isPresented: $showDeleteJahrAlert) {
            Button("Abbrechen", role: .cancel) { }
            Button("Löschen", role: .destructive) {
                if let haus = selectedAbrechnung {
                    let success = DatabaseManager.shared.delete(id: haus.id)
                    if success {
                        onAbrechnungDeleted?()
                        dismiss()
                    }
                }
            }
        } message: {
            if let haus = selectedAbrechnung {
                Text("Die Abrechnung für '\(haus.hausBezeichnung)' (Jahr \(haus.abrechnungsJahr)) und alle zugehörigen Daten (Wohnungen, Mietzeiträume, Zählerstände, Kosten) unwiderruflich löschen?")
            } else {
                Text("Bitte auf der Startseite ein Haus markieren (Strasse anklicken).")
            }
        }
        .alert("Datenbank zurücksetzen", isPresented: $showCleanupAlert) {
            Button("Abbrechen", role: .cancel) { }
            Button("Zurücksetzen", role: .destructive) {
                let success = DatabaseManager.shared.resetDatabase()
                if success {
                    onDatabaseReset?()
                    dismiss()
                }
            }
        } message: {
            Text("Möchten Sie die Datenbank wirklich zurücksetzen? Alle Daten werden gelöscht und die Datenbank wird neu aufgebaut.")
        }
        .alert("Backup", isPresented: $showBackupAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            VStack(alignment: .leading, spacing: 8) {
                Text(backupMessage)
                if !backupFileName.isEmpty {
                    Divider()
                    Text("Dateiname:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(backupFileName)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = backupFileURL {
                ShareSheet(items: [url])
            }
        }
        .fileImporter(
            isPresented: $showDocumentPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importiereBackup(from: url)
                }
            case .failure(let error):
                importMessage = "Fehler beim Auswählen der Datei: \(error.localizedDescription)"
                showImportAlert = true
            }
        }
        .alert("Import", isPresented: $showImportAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(importMessage)
        }
        .alert("Jahreswechsel", isPresented: $showJahreswechselAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(jahreswechselMessage)
        }
    }
    
    private func backupToiCloud() {
        guard let haus = selectedAbrechnung else {
            backupMessage = "Bitte auf der Startseite ein Haus markieren (Strasse anklicken)."
            showBackupAlert = true
            return
        }
        
        isBackingUp = true
        
        // Sammle alle Daten für das Haus
        let alleDaten = sammleAlleDaten(hausId: haus.id)
        
        // Erstelle JSON-Datei
        guard let jsonData = erstelleJSON(alleDaten: alleDaten) else {
            isBackingUp = false
            backupMessage = "Fehler beim Erstellen der Backup-Datei"
            showBackupAlert = true
            return
        }
        
        // Speichere in iCloud
        speichereIniCloud(jsonData: jsonData, haus: haus) { success, message in
            DispatchQueue.main.async {
                isBackingUp = false
                if success {
                    // Öffne automatisch das Share Sheet
                    if self.backupFileURL != nil {
                        self.showShareSheet = true
                    }
                } else {
                    backupMessage = message
                    showBackupAlert = true
                }
            }
        }
    }
    
    private func sammleAlleDaten(hausId: Int64) -> HausBackupDaten {
        let wohnungen = DatabaseManager.shared.getWohnungen(byHausAbrechnungId: hausId)
        
        var mietzeitraeume: [Mietzeitraum] = []
        var mitmieter: [Mitmieter] = []
        var zaehlerstaende: [Zaehlerstand] = []
        var kosten: [Kosten] = []
        var einzelnachweisWohnungen: [EinzelnachweisWohnung] = []
        
        for wohnung in wohnungen {
            // Mietzeiträume
            let mietzeitraeumeFuerWohnung = DatabaseManager.shared.getMietzeitraeume(byWohnungId: wohnung.id)
            mietzeitraeume.append(contentsOf: mietzeitraeumeFuerWohnung)
            
            // Mitmieter für jeden Mietzeitraum
            for mietzeitraum in mietzeitraeumeFuerWohnung {
                let mitmieterFuerMietzeitraum = DatabaseManager.shared.getMitmieter(byMietzeitraumId: mietzeitraum.id)
                mitmieter.append(contentsOf: mitmieterFuerMietzeitraum)
            }
            
            // Zählerstände
            let zaehlerstaendeFuerWohnung = DatabaseManager.shared.getZaehlerstaende(byWohnungId: wohnung.id)
            zaehlerstaende.append(contentsOf: zaehlerstaendeFuerWohnung)
        }
        
        // Kosten
        kosten = DatabaseManager.shared.getKosten(byHausAbrechnungId: hausId)
        
        // EinzelnachweisWohnungen für alle Kosten
        for kostenItem in kosten {
            let einzelnachweisFuerKosten = DatabaseManager.shared.getEinzelnachweisWohnungen(byKostenId: kostenItem.id)
            einzelnachweisWohnungen.append(contentsOf: einzelnachweisFuerKosten)
        }
        
        return HausBackupDaten(
            haus: DatabaseManager.shared.getHausAbrechnung(by: hausId)!,
            wohnungen: wohnungen,
            mietzeitraeume: mietzeitraeume,
            mitmieter: mitmieter,
            zaehlerstaende: zaehlerstaende,
            kosten: kosten,
            einzelnachweisWohnungen: einzelnachweisWohnungen
        )
    }
    
    private func erstelleJSON(alleDaten: HausBackupDaten) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        do {
            return try encoder.encode(alleDaten)
        } catch {
            print("Fehler beim Erstellen des JSON: \(error)")
            return nil
        }
    }
    
    private func speichereIniCloud(jsonData: Data, haus: HausAbrechnung, completion: @escaping (Bool, String) -> Void) {
        // Erstelle Dateiname
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let fileName = "Nebenkosten_Backup_\(haus.hausBezeichnung.replacingOccurrences(of: " ", with: "_"))_\(haus.abrechnungsJahr)_\(timestamp).json"
        
        // Speichere temporär
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try jsonData.write(to: tempURL)
            
            // Versuche iCloud Drive zu verwenden
            if let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
                let documentsURL = iCloudURL.appendingPathComponent("Documents")
                
                // Erstelle Documents-Verzeichnis falls nicht vorhanden
                if !FileManager.default.fileExists(atPath: documentsURL.path) {
                    try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
                }
                
                let destinationURL = documentsURL.appendingPathComponent(fileName)
                
                // Kopiere Datei nach iCloud
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                try FileManager.default.copyItem(at: tempURL, to: destinationURL)
                
                // Entferne temporäre Datei
                try? FileManager.default.removeItem(at: tempURL)
                
                // Speichere Dateinamen für Anzeige
                DispatchQueue.main.async {
                    self.backupFileName = fileName
                    self.backupFileURL = destinationURL
                }
                
                completion(true, "Backup erfolgreich erstellt")
            } else {
                // Fallback: Speichere temporär für Share Sheet
                DispatchQueue.main.async {
                    self.backupFileName = fileName
                    self.backupFileURL = tempURL
                    completion(true, "Backup erfolgreich erstellt")
                }
            }
        } catch {
            completion(false, "Fehler beim Speichern: \(error.localizedDescription)")
        }
    }
    
    private func importiereBackup(from url: URL) {
        isImporting = true
        
        // Starte Zugriff auf die Datei
        _ = url.startAccessingSecurityScopedResource()
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            // Lese JSON-Datei
            let jsonData = try Data(contentsOf: url)
            
            // Parse JSON
            let decoder = JSONDecoder()
            let backupDaten = try decoder.decode(HausBackupDaten.self, from: jsonData)
            
            // Importiere Daten in die Datenbank
            importiereDaten(backupDaten: backupDaten) { success, message in
                DispatchQueue.main.async {
                    isImporting = false
                    importMessage = message
                    showImportAlert = true
                    if success {
                        onImportSuccess?()
                    }
                }
            }
        } catch {
            isImporting = false
            importMessage = "Fehler beim Lesen der Datei: \(error.localizedDescription)"
            showImportAlert = true
        }
    }
    
    private func importiereDaten(backupDaten: HausBackupDaten, completion: @escaping (Bool, String) -> Void) {
        // ID-Mapping für neue IDs
        var hausIdMapping: [Int64: Int64] = [:]
        var wohnungIdMapping: [Int64: Int64] = [:]
        var mietzeitraumIdMapping: [Int64: Int64] = [:]
        var kostenIdMapping: [Int64: Int64] = [:]
        
        // 1. Importiere Haus
        let altesHausId = backupDaten.haus.id
        let neuesHaus = HausAbrechnung(
            id: 0, // Neue ID wird generiert
            hausBezeichnung: backupDaten.haus.hausBezeichnung,
            abrechnungsJahr: backupDaten.haus.abrechnungsJahr,
            postleitzahl: backupDaten.haus.postleitzahl,
            ort: backupDaten.haus.ort,
            gesamtflaeche: backupDaten.haus.gesamtflaeche,
            anzahlWohnungen: backupDaten.haus.anzahlWohnungen,
            leerstandspruefung: backupDaten.haus.leerstandspruefung,
            verwalterName: backupDaten.haus.verwalterName,
            verwalterStrasse: backupDaten.haus.verwalterStrasse,
            verwalterPLZOrt: backupDaten.haus.verwalterPLZOrt,
            verwalterEmail: backupDaten.haus.verwalterEmail,
            verwalterTelefon: backupDaten.haus.verwalterTelefon,
            verwalterInEmailVorbelegen: backupDaten.haus.verwalterInEmailVorbelegen
        )
        
        if DatabaseManager.shared.insert(hausAbrechnung: neuesHaus) {
            // Hole neue Haus-ID
            if let neuesHausAusDB = DatabaseManager.shared.getAll().first(where: {
                $0.hausBezeichnung == neuesHaus.hausBezeichnung &&
                $0.abrechnungsJahr == neuesHaus.abrechnungsJahr
            }) {
                hausIdMapping[altesHausId] = neuesHausAusDB.id
                let neuesHausId = neuesHausAusDB.id
                
                // 2. Importiere Wohnungen
                for wohnung in backupDaten.wohnungen {
                    let altesWohnungId = wohnung.id
                    let neueWohnung = Wohnung(
                        id: 0,
                        hausAbrechnungId: neuesHausId,
                        wohnungsnummer: wohnung.wohnungsnummer,
                        bezeichnung: wohnung.bezeichnung,
                        qm: wohnung.qm,
                        name: wohnung.name,
                        strasse: wohnung.strasse,
                        plz: wohnung.plz,
                        ort: wohnung.ort,
                        email: wohnung.email,
                        telefon: wohnung.telefon
                    )
                    
                    if let neueWohnungId = DatabaseManager.shared.insertWohnung(neueWohnung) {
                        wohnungIdMapping[altesWohnungId] = neueWohnungId
                    }
                }
                
                // 3. Importiere Mietzeiträume
                for mietzeitraum in backupDaten.mietzeitraeume {
                    if let neueWohnungId = wohnungIdMapping[mietzeitraum.wohnungId] {
                        let altesMietzeitraumId = mietzeitraum.id
                        let neuerMietzeitraum = Mietzeitraum(
                            id: 0,
                            wohnungId: neueWohnungId,
                            jahr: mietzeitraum.jahr,
                            hauptmieterName: mietzeitraum.hauptmieterName,
                            vonDatum: mietzeitraum.vonDatum,
                            bisDatum: mietzeitraum.bisDatum,
                            anzahlPersonen: mietzeitraum.anzahlPersonen,
                            mietendeOption: mietzeitraum.mietendeOption
                        )
                        
                        if DatabaseManager.shared.insertMietzeitraum(neuerMietzeitraum) {
                            // Hole neue Mietzeitraum-ID (letzte für diese Wohnung)
                            let mietzeitraeumeFuerWohnung = DatabaseManager.shared.getMietzeitraeume(byWohnungId: neueWohnungId)
                            if let neuerMietzeitraumAusDB = mietzeitraeumeFuerWohnung.last(where: {
                                $0.hauptmieterName == neuerMietzeitraum.hauptmieterName &&
                                $0.vonDatum == neuerMietzeitraum.vonDatum &&
                                $0.bisDatum == neuerMietzeitraum.bisDatum
                            }) {
                                mietzeitraumIdMapping[altesMietzeitraumId] = neuerMietzeitraumAusDB.id
                            }
                        }
                    }
                }
                
                // 4. Importiere Mitmieter
                for mitmieter in backupDaten.mitmieter {
                    if let neuerMietzeitraumId = mietzeitraumIdMapping[mitmieter.mietzeitraumId] {
                        let neuerMitmieter = Mitmieter(
                            id: 0,
                            mietzeitraumId: neuerMietzeitraumId,
                            name: mitmieter.name,
                            vonDatum: mitmieter.vonDatum,
                            bisDatum: mitmieter.bisDatum
                        )
                        _ = DatabaseManager.shared.insertMitmieter(neuerMitmieter)
                    }
                }
                
                // 5. Importiere Zählerstände
                for zaehlerstand in backupDaten.zaehlerstaende {
                    if let neueWohnungId = wohnungIdMapping[zaehlerstand.wohnungId] {
                        let neuerZaehlerstand = Zaehlerstand(
                            id: 0,
                            wohnungId: neueWohnungId,
                            zaehlerTyp: zaehlerstand.zaehlerTyp,
                            zaehlerNummer: zaehlerstand.zaehlerNummer,
                            zaehlerStart: zaehlerstand.zaehlerStart,
                            zaehlerEnde: zaehlerstand.zaehlerEnde,
                            auchAbwasser: zaehlerstand.auchAbwasser
                        )
                        _ = DatabaseManager.shared.insertZaehlerstand(neuerZaehlerstand)
                    }
                }
                
                // 6. Importiere Kosten
                for kosten in backupDaten.kosten {
                    let altesKostenId = kosten.id
                    let neueKosten = Kosten(
                        id: 0,
                        hausAbrechnungId: neuesHausId,
                        kostenart: kosten.kostenart,
                        betrag: kosten.betrag,
                        bezeichnung: kosten.bezeichnung,
                        verteilungsart: kosten.verteilungsart
                    )
                    
                    if DatabaseManager.shared.insertKosten(neueKosten) {
                        // Hole neue Kosten-ID (letzte für dieses Haus mit gleichen Eigenschaften)
                        let kostenFuerHaus = DatabaseManager.shared.getKosten(byHausAbrechnungId: neuesHausId)
                        if let neueKostenAusDB = kostenFuerHaus.last(where: {
                            $0.kostenart == neueKosten.kostenart &&
                            abs($0.betrag - neueKosten.betrag) < 0.01 &&
                            $0.verteilungsart == neueKosten.verteilungsart
                        }) {
                            kostenIdMapping[altesKostenId] = neueKostenAusDB.id
                        }
                    }
                }
                
                // 7. Importiere EinzelnachweisWohnungen
                for einzelnachweis in backupDaten.einzelnachweisWohnungen {
                    if let neueKostenId = kostenIdMapping[einzelnachweis.kostenId],
                       let neueWohnungId = wohnungIdMapping[einzelnachweis.wohnungId] {
                        let neuerEinzelnachweis = EinzelnachweisWohnung(
                            id: 0,
                            kostenId: neueKostenId,
                            wohnungId: neueWohnungId,
                            von: einzelnachweis.von,
                            betrag: einzelnachweis.betrag
                        )
                        _ = DatabaseManager.shared.insertEinzelnachweisWohnung(neuerEinzelnachweis)
                    }
                }
                
                completion(true, "Daten erfolgreich importiert!\n\nHaus: \(backupDaten.haus.hausBezeichnung) (\(backupDaten.haus.abrechnungsJahr))\nWohnungen: \(backupDaten.wohnungen.count)\nMietzeiträume: \(backupDaten.mietzeitraeume.count)\nKosten: \(backupDaten.kosten.count)")
            } else {
                completion(false, "Fehler: Neues Haus konnte nicht gefunden werden")
            }
        } else {
            completion(false, "Fehler beim Importieren des Hauses")
        }
    }
    
    private func jahreswechselDurchfuehren() {
        guard let haus = selectedAbrechnung else {
            jahreswechselMessage = "Bitte auf der Startseite ein Haus markieren (Strasse anklicken)."
            showJahreswechselAlert = true
            return
        }
        
        let jahrFuerWechsel = neuesJahr ?? (haus.abrechnungsJahr + 1)
        
        guard jahrFuerWechsel > haus.abrechnungsJahr else {
            jahreswechselMessage = "Das neue Jahr muss größer als das aktuelle Jahr (\(haus.abrechnungsJahr)) sein"
            showJahreswechselAlert = true
            return
        }
        
        isJahreswechselActive = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let ergebnis = DatabaseManager.shared.jahreswechsel(vonHausId: haus.id, neuesJahr: jahrFuerWechsel)
            
            DispatchQueue.main.async {
                isJahreswechselActive = false
                
                if ergebnis.erfolgreich {
                    jahreswechselMessage = "Jahreswechsel erfolgreich durchgeführt!\n\nNeues Jahr: \(jahrFuerWechsel)\nHaus: \(haus.hausBezeichnung)\n\nNur Mieter mit End-Datum 31.12. \(haus.abrechnungsJahr) sowie ihre Zähler wurden übernommen.\nKosten-Positionen wurden übernommen (ohne Wert)."
                    neuesJahr = nil
                    onJahreswechselErfolgreich?()
                } else {
                    jahreswechselMessage = ergebnis.fehlermeldung ?? "Fehler beim Jahreswechsel"
                }
                showJahreswechselAlert = true
            }
        }
    }
}

// Struktur für alle Daten eines Hauses
struct HausBackupDaten: Codable {
    let haus: HausAbrechnung
    let wohnungen: [Wohnung]
    let mietzeitraeume: [Mietzeitraum]
    let mitmieter: [Mitmieter]
    let zaehlerstaende: [Zaehlerstand]
    let kosten: [Kosten]
    let einzelnachweisWohnungen: [EinzelnachweisWohnung]
}

struct StartView_Previews: PreviewProvider {
    static var previews: some View {
        StartView()
    }
}
