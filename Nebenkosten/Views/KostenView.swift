//
//  KostenView.swift
//  Nebenkosten
//
//  Created by Axel Behm on 22.01.26.
//

import SwiftUI
import PhotosUI

// Prüft ob ein Jahr gesperrt ist (wenn ein neueres Jahr existiert)
private func istJahrGesperrt(abrechnung: HausAbrechnung) -> Bool {
    return DatabaseManager.shared.istJahrGesperrt(hausBezeichnung: abrechnung.hausBezeichnung, jahr: abrechnung.abrechnungsJahr)
}

struct KostenView: View {
    let abrechnung: HausAbrechnung
    @State private var kosten: [Kosten] = []
    @State private var showAddKosten = false
    @State private var editingKosten: Kosten?
    @State private var showDeleteAlert = false
    @State private var deletingKosten: Kosten?
    @State private var istGesperrt: Bool = false
    
    @State private var selectedKostenart: Kostenart = .abfall
    @State private var selectedVerteilungsart: Verteilungsart = .nachPersonen  // Abfall-Default: nach Personen
    @State private var betragText = ""
    @State private var bezeichnungText = ""
    
    var body: some View {
        List {
            kostenSection
        }
        .scrollIndicators(.visible)
        .navigationTitle("Kosten")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadKosten()
            istGesperrt = istJahrGesperrt(abrechnung: abrechnung)
        }
        .onChange(of: showAddKosten) { old, new in
            if !new && old {
                loadKosten()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                addKostenButton
            }
        }
        .fullScreenCover(isPresented: $showAddKosten) {
            AddKostenSheet(
                abrechnung: abrechnung,
                istGesperrt: istGesperrt,
                kosten: editingKosten,
                kostenart: $selectedKostenart,
                verteilungsart: $selectedVerteilungsart,
                betragText: $betragText,
                bezeichnungText: $bezeichnungText,
                isEdit: editingKosten != nil,
                onSave: {
                    loadKosten()
                    showAddKosten = false
                    editingKosten = nil
                },
                onCancel: {
                    showAddKosten = false
                    editingKosten = nil
                }
            )
        }
        .alert("Kosten löschen?", isPresented: $showDeleteAlert) {
            Button("Abbrechen", role: .cancel) { deletingKosten = nil }
            Button("Löschen", role: .destructive) {
                if let k = deletingKosten {
                    if istGesperrt {
                        return
                    }
                    _ = DatabaseManager.shared.deleteKosten(id: k.id)
                    loadKosten()
                    deletingKosten = nil
                }
            }
        } message: {
            if let k = deletingKosten {
                Text("Kosten \"\(k.kostenart.rawValue)\" (\(String(format: "%.2f", k.betrag)) €) löschen?")
            }
        }
    }
    
    private var kostenSection: some View {
        Section {
            ForEach(kosten) { k in
                kostenRow(k)
            }
            if kosten.isEmpty {
                Text("Keine Kosten erfasst")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Kosten \(String(abrechnung.abrechnungsJahr))")
        }
    }
    
    @ViewBuilder
    private func kostenRow(_ k: Kosten) -> some View {
        HStack(spacing: 12) {
            Image(systemName: k.kostenart.symbolName)
                .font(.title2)
                .foregroundStyle(Color.appBlue)
                .frame(width: 28, alignment: .center)
            VStack(alignment: .leading, spacing: 4) {
                Text(k.kostenart.rawValue)
                    .font(.headline)
                if let bezeichnung = k.bezeichnung, !bezeichnung.isEmpty {
                    Text(bezeichnung)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("\(String(format: "%.2f", k.betrag)) €")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                    Text("• \(k.verteilungsart.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            kostenMenu(k, istGesperrt: istGesperrt)
        }
    }
    
    @ViewBuilder
    private func kostenMenu(_ k: Kosten, istGesperrt: Bool) -> some View {
        Menu {
            Button {
                editingKosten = k
                selectedKostenart = k.kostenart
                selectedVerteilungsart = k.verteilungsart
                betragText = String(format: "%.2f", k.betrag)
                bezeichnungText = k.bezeichnung ?? ""
                showAddKosten = true
            } label: {
                Label("Bearbeiten", systemImage: "pencil")
            }
            Button(role: .destructive) {
                deletingKosten = k
                showDeleteAlert = true
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
    
    private var addKostenButton: some View {
        Button {
            editingKosten = nil
            selectedKostenart = .abfall
            selectedVerteilungsart = getDefaultVerteilungsart(for: selectedKostenart)
            betragText = ""
            bezeichnungText = ""
            showAddKosten = true
        } label: {
            Label("Kosten hinzufügen", systemImage: "plus.circle")
        }
        .disabled(istGesperrt)
    }
    
    private func loadKosten() {
        kosten = DatabaseManager.shared.getKosten(byHausAbrechnungId: abrechnung.id)
    }
}

// Funktion zur Bestimmung der Standard-Verteilungsart basierend auf Kostenart
fileprivate func getDefaultVerteilungsart(for art: Kostenart) -> Verteilungsart {
    switch art {
    case .abfall:
        return .nachPersonen
    case .kabel:
        return .nachWohneinheiten
    case .frischwasser:
        return .nachVerbrauch
    case .warmwasser:
        return .nachVerbrauch
    case .abwasser:
        return .nachVerbrauch
    case .gas:
        return .nachVerbrauch
    case .strom:
        return .nachVerbrauch
    case .niederschlagswasser:
        return .nachQm
    case .schornsteinfeger:
        return .nachEinzelnachweis
    case .sachHaftpflichtVersicherung:
        return .nachQm
    case .grundsteuer:
        return .nachQm
    case .hausstrom:
        return .nachPersonen
    case .strassenreinigung:
        return .nachQm
    case .heizungswartung:
        return .nachQm  // Standard, nicht spezifiziert
    case .vorauszahlung:
        return .nachEinzelnachweis
    case .sonstiges:
        return .nachQm  // Standard, nicht spezifiziert
    }
}

private struct AddKostenSheet: View {
    let abrechnung: HausAbrechnung
    let istGesperrt: Bool
    let kosten: Kosten?
    @Binding var kostenart: Kostenart
    @Binding var verteilungsart: Verteilungsart
    @Binding var betragText: String
    @Binding var bezeichnungText: String
    let isEdit: Bool
    let onSave: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    #if os(iOS)
    @State private var kostenFotos: [KostenFoto] = []
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var fotoZumAnzeigen: KostenFoto?
    #endif
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Kostenart", selection: $kostenart) {
                        ForEach(Kostenart.allCases, id: \.self) { art in
                            Label(art.rawValue, systemImage: art.symbolName).tag(art)
                        }
                    }
                    .disabled(istGesperrt)
                    .onChange(of: kostenart) { oldValue, newValue in
                        if !istGesperrt {
                            verteilungsart = getDefaultVerteilungsart(for: newValue)
                        }
                    }
                    Picker("Verteilung", selection: $verteilungsart) {
                        ForEach(Verteilungsart.allCases, id: \.self) { art in
                            Text(art.rawValue).tag(art)
                        }
                    }
                    .disabled(istGesperrt)
                    TextField("Betrag (€)", text: $betragText)
                        .keyboardType(.decimalPad)
                        .disabled(istGesperrt)
                    if kostenart == .sonstiges {
                        TextField("Bezeichnung", text: $bezeichnungText)
                            .disabled(istGesperrt)
                    }
                } header: {
                    Text("Kosten")
                } footer: {
                    if kostenart == .sonstiges {
                        Text("Bitte geben Sie eine Bezeichnung für die sonstige Kostenart an.")
                    }
                }
                #if os(iOS)
                if isEdit, let k = kosten {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            if !kostenFotos.isEmpty {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                                    ForEach(kostenFotos) { foto in
                                        KostenFotoZelleView(
                                            foto: foto,
                                            kostenId: k.id,
                                            istGesperrt: istGesperrt,
                                            onDelete: {
                                                let furl = DatabaseManager.shared.kostenFotoFullURL(imagePath: foto.imagePath)
                                                if FileManager.default.fileExists(atPath: furl.path) {
                                                    try? FileManager.default.removeItem(at: furl)
                                                }
                                                _ = DatabaseManager.shared.deleteKostenFoto(id: foto.id)
                                                kostenFotos = DatabaseManager.shared.getKostenFotos(byKostenId: k.id)
                                            },
                                            onTapToView: { fotoZumAnzeigen = foto },
                                            onReload: { kostenFotos = DatabaseManager.shared.getKostenFotos(byKostenId: k.id) }
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
                                    Label("Rechnungen / Anhänge auswählen", systemImage: "photo.on.rectangle.angled")
                                }
                                .onChange(of: selectedPhotoItems) { _, items in
                                    guard !items.isEmpty else { return }
                                    Task {
                                        let db = DatabaseManager.shared
                                        let ordnerURL = db.kostenFotoOrdnerURL(kostenId: k.id)
                                        let nextOrder = db.getKostenFotos(byKostenId: k.id).count
                                        for (idx, item) in items.enumerated() {
                                            if let data = try? await item.loadTransferable(type: Data.self), !data.isEmpty {
                                                let filename = "img_\(UUID().uuidString).jpg"
                                                let fileURL = ordnerURL.appendingPathComponent(filename)
                                                try? data.write(to: fileURL)
                                                let relPath = "\(k.id)/\(filename)"
                                                _ = db.insertKostenFoto(kostenId: k.id, imagePath: relPath, sortOrder: nextOrder + idx, bildbezeichnung: "")
                                            }
                                        }
                                        await MainActor.run {
                                            selectedPhotoItems = []
                                            kostenFotos = DatabaseManager.shared.getKostenFotos(byKostenId: k.id)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    } header: {
                        Text("Gemeinde / Kreis Rechnungen")
                    } footer: {
                        Text("Rechnungen oder Belege (z. B. von Gemeinde/Kreis) zu dieser Kostenposition hinzufügen.")
                    }
                }
                #endif
            }
            .navigationTitle(isEdit ? "Kosten bearbeiten" : "Neue Kosten")
            .onAppear {
                #if os(iOS)
                if let k = kosten {
                    kostenFotos = DatabaseManager.shared.getKostenFotos(byKostenId: k.id)
                }
                #endif
            }
            #if os(iOS)
            .sheet(item: $fotoZumAnzeigen) { foto in
                NavigationStack {
                    KostenFotoFullScreenView(foto: foto, onBezeichnungSaved: {
                        if let k = kosten {
                            kostenFotos = DatabaseManager.shared.getKostenFotos(byKostenId: k.id)
                        }
                    })
                    .ignoresSafeArea(edges: .bottom)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Schließen") { fotoZumAnzeigen = nil }
                        }
                    }
                }
            }
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        guard let betrag = Double(betragText.replacingOccurrences(of: ",", with: ".")) else {
                            return
                        }
                        
                        // Bei Vorauszahlung: Wenn Wert negativ ist, mit -1 multiplizieren
                        let finalBetrag = (kostenart == .vorauszahlung && betrag < 0) ? betrag * -1 : betrag
                        
                        let bezeichnung = (kostenart == .sonstiges && !bezeichnungText.isEmpty) ? bezeichnungText : nil
                        
                        if let e = kosten {
                            _ = DatabaseManager.shared.updateKosten(Kosten(
                                id: e.id,
                                hausAbrechnungId: abrechnung.id,
                                kostenart: kostenart,
                                betrag: finalBetrag,
                                bezeichnung: bezeichnung,
                                verteilungsart: verteilungsart
                            ))
                        } else {
                            _ = DatabaseManager.shared.insertKosten(Kosten(
                                hausAbrechnungId: abrechnung.id,
                                kostenart: kostenart,
                                betrag: finalBetrag,
                                bezeichnung: bezeichnung,
                                verteilungsart: verteilungsart
                            ))
                        }
                        onSave()
                        dismiss()
                    }
                    .disabled(
                        istGesperrt ||
                        betragText.isEmpty ||
                        Double(betragText.replacingOccurrences(of: ",", with: ".")) == nil ||
                        (kostenart == .sonstiges && bezeichnungText.isEmpty)
                    )
                }
            }
        }
    }
}

// MARK: - Kosten-Fotos (Rechnungen / Anhänge, z. B. Gemeinde / Kreis)

#if os(iOS)
private struct KostenFotoThumbnailView: View {
    let imagePath: String
    var body: some View {
        let url = DatabaseManager.shared.kostenFotoFullURL(imagePath: imagePath)
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

private struct KostenFotoFullScreenView: View {
    let foto: KostenFoto
    @State private var bildbezeichnung: String
    let onBezeichnungSaved: () -> Void
    init(foto: KostenFoto, onBezeichnungSaved: @escaping () -> Void) {
        self.foto = foto
        self._bildbezeichnung = State(initialValue: foto.bildbezeichnung)
        self.onBezeichnungSaved = onBezeichnungSaved
    }
    var body: some View {
        VStack(spacing: 0) {
            TextField("Bezeichnung", text: $bildbezeichnung, prompt: Text("z. B. Rechnung"))
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .onSubmit {
                    _ = DatabaseManager.shared.updateKostenFotoBezeichnung(id: foto.id, bildbezeichnung: bildbezeichnung)
                    onBezeichnungSaved()
                }
            let url = DatabaseManager.shared.kostenFotoFullURL(imagePath: foto.imagePath)
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

private struct KostenFotoZelleView: View {
    let foto: KostenFoto
    let kostenId: Int64
    let istGesperrt: Bool
    let onDelete: () -> Void
    let onTapToView: () -> Void
    let onReload: () -> Void
    @State private var bezeichnung: String
    init(foto: KostenFoto, kostenId: Int64, istGesperrt: Bool, onDelete: @escaping () -> Void, onTapToView: @escaping () -> Void, onReload: @escaping () -> Void) {
        self.foto = foto
        self.kostenId = kostenId
        self.istGesperrt = istGesperrt
        self.onDelete = onDelete
        self.onTapToView = onTapToView
        self.onReload = onReload
        self._bezeichnung = State(initialValue: foto.bildbezeichnung)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            KostenFotoThumbnailView(imagePath: foto.imagePath)
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
                TextField("Bezeichnung", text: $bezeichnung, prompt: Text("z. B. Rechnung"))
                    .font(.caption)
                    .lineLimit(1)
                    .onSubmit {
                        _ = DatabaseManager.shared.updateKostenFotoBezeichnung(id: foto.id, bildbezeichnung: bezeichnung)
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
#endif
