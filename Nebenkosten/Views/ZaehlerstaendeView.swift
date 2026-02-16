//
//  ZaehlerstaendeView.swift
//  Nebenkosten
//
//  Created by Axel Behm on 22.01.26.
//

import SwiftUI
#if os(iOS)
import PhotosUI
#endif

// Verfügbare Zählertypen
private let zaehlerTypen = ["Frischwasser", "Warmwasser", "Strom", "Gas", "Sonstiges"]

// Prüft ob ein Jahr gesperrt ist (wenn ein neueres Jahr existiert)
private func istJahrGesperrt(abrechnung: HausAbrechnung) -> Bool {
    return DatabaseManager.shared.istJahrGesperrt(hausBezeichnung: abrechnung.hausBezeichnung, jahr: abrechnung.abrechnungsJahr)
}

struct ZaehlerstaendeView: View {
    let wohnung: Wohnung
    let haus: HausAbrechnung
    @State private var zaehlerstaende: [Zaehlerstand] = []
    @State private var showAddZaehlerstand = false
    @State private var editingZaehlerstand: Zaehlerstand?
    @State private var showDeleteAlert = false
    @State private var deletingZaehlerstand: Zaehlerstand?
    @State private var istGesperrt: Bool = false
    
    @State private var zaehlerTyp = ""
    @State private var zaehlerNummerText = ""
    @State private var zaehlerStartText = ""
    @State private var zaehlerEndeText = ""
    @State private var beschreibungText = ""
    @State private var auchAbwasser = true
    
    var body: some View {
        List {
            Section {
                ForEach(zaehlerstaende) { z in
                    HStack(spacing: 12) {
                        Image(systemName: Zaehlerstand.symbolName(for: z.zaehlerTyp))
                            .font(.title2)
                            .foregroundStyle(Color.appBlue)
                            .frame(width: 28, alignment: .center)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(z.zaehlerTyp)
                                    .font(.headline)
                                if let nummer = z.zaehlerNummer, !nummer.isEmpty {
                                    Text("(Nr. \(nummer))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            HStack {
                                Text("Start: \(String(format: "%.2f", z.zaehlerStart))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("Ende: \(String(format: "%.2f", z.zaehlerEnde))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            HStack {
                                Text("Differenz: \(String(format: "%.2f", z.differenz)) cbm/kwh")
                                    .font(.subheadline)
                                    .foregroundStyle(.blue)
                                if z.zaehlerTyp == "Frischwasser", let auchAbwasser = z.auchAbwasser, auchAbwasser {
                                    Text("(auch Abwasser)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if let beschreibung = z.beschreibung, !beschreibung.isEmpty {
                                Text(beschreibung)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Menu {
                            Button {
                                editingZaehlerstand = z
                                zaehlerTyp = z.zaehlerTyp
                                zaehlerNummerText = z.zaehlerNummer ?? ""
                                zaehlerStartText = String(format: "%.2f", z.zaehlerStart)
                                zaehlerEndeText = String(format: "%.2f", z.zaehlerEnde)
                                beschreibungText = z.beschreibung ?? ""
                                auchAbwasser = z.auchAbwasser ?? true
                                showAddZaehlerstand = true
                            } label: {
                                Label("Bearbeiten", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                deletingZaehlerstand = z
                                showDeleteAlert = true
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                            .disabled(istGesperrt)
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(.blue)
                        }
                        .fixedSize()
                    }
                }
                if zaehlerstaende.isEmpty {
                    Text("Keine Zählerstände erfasst")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Zählerstände")
            } footer: {
                Text("Der Start-Wert wird automatisch vom Vormieter übernommen, falls vorhanden.")
            }
        }
        .navigationTitle("Zählerstände")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadZaehlerstaende()
            istGesperrt = istJahrGesperrt(abrechnung: haus)
        }
        .onChange(of: showAddZaehlerstand) { old, new in
            if !new && old {
                loadZaehlerstaende()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editingZaehlerstand = nil
                    zaehlerTyp = ""
                    zaehlerNummerText = ""
                    zaehlerStartText = ""
                    zaehlerEndeText = ""
                    beschreibungText = ""
                    auchAbwasser = true
                    showAddZaehlerstand = true
                } label: {
                    Label("Zählerstand hinzufügen", systemImage: "plus.circle")
                }
                .disabled(istGesperrt)
            }
        }
        .sheet(isPresented: $showAddZaehlerstand) {
            AddZaehlerstandSheet(
                wohnung: wohnung,
                editingZaehlerstand: editingZaehlerstand,
                istGesperrt: istGesperrt,
                zaehlerTyp: $zaehlerTyp,
                zaehlerNummerText: $zaehlerNummerText,
                zaehlerStartText: $zaehlerStartText,
                zaehlerEndeText: $zaehlerEndeText,
                beschreibungText: $beschreibungText,
                auchAbwasser: $auchAbwasser,
                isEdit: editingZaehlerstand != nil,
                onSave: {
                    guard let start = Double(zaehlerStartText.replacingOccurrences(of: ",", with: ".")),
                          let ende = Double(zaehlerEndeText.replacingOccurrences(of: ",", with: ".")),
                          start >= 0, ende >= start else {
                        return
                    }
                    
                    let zaehlerNummer = zaehlerNummerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : zaehlerNummerText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let auchAbwasserValue = zaehlerTyp == "Frischwasser" ? auchAbwasser : nil
                    let beschreibung = beschreibungText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : beschreibungText.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if let e = editingZaehlerstand {
                        _ = DatabaseManager.shared.updateZaehlerstand(Zaehlerstand(
                            id: e.id,
                            wohnungId: wohnung.id,
                            zaehlerTyp: zaehlerTyp,
                            zaehlerNummer: zaehlerNummer,
                            zaehlerStart: start,
                            zaehlerEnde: ende,
                            auchAbwasser: auchAbwasserValue,
                            beschreibung: beschreibung
                        ))
                    } else {
                        _ = DatabaseManager.shared.insertZaehlerstand(Zaehlerstand(
                            wohnungId: wohnung.id,
                            zaehlerTyp: zaehlerTyp,
                            zaehlerNummer: zaehlerNummer,
                            zaehlerStart: start,
                            zaehlerEnde: ende,
                            auchAbwasser: auchAbwasserValue,
                            beschreibung: beschreibung
                        ))
                    }
                    loadZaehlerstaende()
                    showAddZaehlerstand = false
                    editingZaehlerstand = nil
                },
                onCancel: {
                    showAddZaehlerstand = false
                    editingZaehlerstand = nil
                }
            )
        }
        .alert("Zählerstand löschen?", isPresented: $showDeleteAlert) {
            Button("Abbrechen", role: .cancel) { deletingZaehlerstand = nil }
            Button("Löschen", role: .destructive) {
                if let z = deletingZaehlerstand {
                    if istGesperrt {
                        return
                    }
                    _ = DatabaseManager.shared.deleteZaehlerstand(id: z.id)
                    loadZaehlerstaende()
                    deletingZaehlerstand = nil
                }
            }
        } message: {
            if let z = deletingZaehlerstand {
                Text("Zählerstand \"\(z.zaehlerTyp)\" (Start: \(String(format: "%.2f", z.zaehlerStart)), Ende: \(String(format: "%.2f", z.zaehlerEnde))) löschen?")
            }
        }
    }
    
    private func loadZaehlerstaende() {
        zaehlerstaende = DatabaseManager.shared.getZaehlerstaende(byWohnungId: wohnung.id)
    }
}

private struct AddZaehlerstandSheet: View {
    let wohnung: Wohnung
    let editingZaehlerstand: Zaehlerstand?
    let istGesperrt: Bool
    @Binding var zaehlerTyp: String
    @Binding var zaehlerNummerText: String
    @Binding var zaehlerStartText: String
    @Binding var zaehlerEndeText: String
    @Binding var beschreibungText: String
    @Binding var auchAbwasser: Bool
    let isEdit: Bool
    let onSave: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    #if os(iOS)
    @State private var zaehlerstandFotos: [ZaehlerstandFoto] = []
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var fotoZumAnzeigen: ZaehlerstandFoto?
    #endif
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Zähler-Typ", selection: $zaehlerTyp) {
                        Text("Bitte auswählen").tag("")
                        ForEach(zaehlerTypen, id: \.self) { typ in
                            Label(typ, systemImage: Zaehlerstand.symbolName(for: typ)).tag(typ)
                        }
                    }
                    .disabled(istGesperrt)
                    TextField("Zähler-Nummer (optional)", text: $zaehlerNummerText)
                        .disabled(istGesperrt)
                    TextField("Beschreibung (optional)", text: $beschreibungText)
                        .disabled(istGesperrt)
                    TextField("Zähler Start", text: $zaehlerStartText)
                        .keyboardType(.decimalPad)
                        .disabled(istGesperrt)
                    TextField("Zähler Ende", text: $zaehlerEndeText)
                        .keyboardType(.decimalPad)
                        .disabled(istGesperrt)
                    if let start = Double(zaehlerStartText.replacingOccurrences(of: ",", with: ".")),
                       let ende = Double(zaehlerEndeText.replacingOccurrences(of: ",", with: ".")),
                       ende >= start {
                        LabeledContent("Differenz") {
                            Text("\(String(format: "%.2f", ende - start)) cbm/kwh")
                                .foregroundStyle(.blue)
                        }
                    }
                    if zaehlerTyp == "Frischwasser" {
                        Toggle("auch Abwasser", isOn: $auchAbwasser)
                            .disabled(istGesperrt)
                    }
                } header: {
                    Text("Zählerstand")
                } footer: {
                    Text("Der Start-Wert wird automatisch vom Vormieter übernommen, falls ein Zählerstand mit gleichem Typ und gleicher Nummer vorhanden ist.")
                }
                #if os(iOS)
                if isEdit, let z = editingZaehlerstand {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            if !zaehlerstandFotos.isEmpty {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                                    ForEach(zaehlerstandFotos) { foto in
                                        ZaehlerstandFotoZelleView(
                                            foto: foto,
                                            zaehlerstandId: z.id,
                                            istGesperrt: istGesperrt,
                                            onDelete: {
                                                let furl = DatabaseManager.shared.zaehlerstandFotoFullURL(imagePath: foto.imagePath)
                                                if FileManager.default.fileExists(atPath: furl.path) {
                                                    try? FileManager.default.removeItem(at: furl)
                                                }
                                                _ = DatabaseManager.shared.deleteZaehlerstandFoto(id: foto.id)
                                                zaehlerstandFotos = DatabaseManager.shared.getZaehlerstandFotos(byZaehlerstandId: z.id)
                                            },
                                            onTapToView: { fotoZumAnzeigen = foto },
                                            onReload: { zaehlerstandFotos = DatabaseManager.shared.getZaehlerstandFotos(byZaehlerstandId: z.id) }
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
                                    Label("Foto vom Zähler auswählen", systemImage: "camera.fill")
                                }
                                .onChange(of: selectedPhotoItems) { _, items in
                                    guard !items.isEmpty else { return }
                                    Task {
                                        let db = DatabaseManager.shared
                                        let ordnerURL = db.zaehlerstandFotoOrdnerURL(zaehlerstandId: z.id)
                                        let nextOrder = db.getZaehlerstandFotos(byZaehlerstandId: z.id).count
                                        for (idx, item) in items.enumerated() {
                                            if let data = try? await item.loadTransferable(type: Data.self), !data.isEmpty {
                                                let filename = "img_\(UUID().uuidString).jpg"
                                                let fileURL = ordnerURL.appendingPathComponent(filename)
                                                try? data.write(to: fileURL)
                                                let relPath = "\(z.id)/\(filename)"
                                                _ = db.insertZaehlerstandFoto(zaehlerstandId: z.id, imagePath: relPath, sortOrder: nextOrder + idx, bildbezeichnung: "")
                                            }
                                        }
                                        await MainActor.run {
                                            selectedPhotoItems = []
                                            zaehlerstandFotos = DatabaseManager.shared.getZaehlerstandFotos(byZaehlerstandId: z.id)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    } header: {
                        Text("Foto vom Zähler")
                    } footer: {
                        Text("Fotos des Zählers (z. B. Zählerstand-Anzeige) hinzufügen.")
                    }
                }
                #endif
            }
            .navigationTitle(isEdit ? "Zählerstand bearbeiten" : "Neuer Zählerstand")
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
                    .disabled(
                        istGesperrt ||
                        zaehlerTyp.isEmpty ||
                        zaehlerStartText.isEmpty ||
                        zaehlerEndeText.isEmpty ||
                        Double(zaehlerStartText.replacingOccurrences(of: ",", with: ".")) == nil ||
                        Double(zaehlerEndeText.replacingOccurrences(of: ",", with: ".")) == nil ||
                        (Double(zaehlerStartText.replacingOccurrences(of: ",", with: ".")) ?? 0) < 0 ||
                        (Double(zaehlerEndeText.replacingOccurrences(of: ",", with: ".")) ?? 0) < (Double(zaehlerStartText.replacingOccurrences(of: ",", with: ".")) ?? 0)
                    )
                }
            }
            .onAppear {
                #if os(iOS)
                if let z = editingZaehlerstand {
                    zaehlerstandFotos = DatabaseManager.shared.getZaehlerstandFotos(byZaehlerstandId: z.id)
                }
                #endif
                // Wenn ein neuer Zählerstand angelegt wird, versuche Start-Wert vom Vormieter zu holen
                // Nur wenn noch keine Zählerstände für diese Wohnung existieren (d.h. nur beim ersten Zählerstand)
                if !isEdit && zaehlerStartText.isEmpty {
                    // Prüfe, ob bereits Zählerstände für diese Wohnung existieren
                    let alleZaehlerstaende = DatabaseManager.shared.getZaehlerstaende(byWohnungId: wohnung.id)
                    
                    // Nur wenn noch keine Zählerstände existieren, versuche Startwert vom Vormieter zu holen
                    if alleZaehlerstaende.isEmpty {
                        let nummer = zaehlerNummerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : zaehlerNummerText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let letzterZaehlerstand = DatabaseManager.shared.getLetzterZaehlerstand(
                            wohnungId: wohnung.id,
                            zaehlerTyp: zaehlerTyp,
                            zaehlerNummer: nummer
                        ) {
                            zaehlerStartText = String(format: "%.2f", letzterZaehlerstand.zaehlerEnde)
                        }
                    }
                }
            }
            .onChange(of: zaehlerTyp) { oldValue, newValue in
                // Wenn der Typ geändert wird, versuche Start-Wert vom Vormieter zu holen
                // Nur wenn noch keine Zählerstände für diese Wohnung existieren
                if !isEdit && !newValue.isEmpty {
                    let alleZaehlerstaende = DatabaseManager.shared.getZaehlerstaende(byWohnungId: wohnung.id)
                    
                    if alleZaehlerstaende.isEmpty {
                        let nummer = zaehlerNummerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : zaehlerNummerText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let letzterZaehlerstand = DatabaseManager.shared.getLetzterZaehlerstand(
                            wohnungId: wohnung.id,
                            zaehlerTyp: newValue,
                            zaehlerNummer: nummer
                        ) {
                            zaehlerStartText = String(format: "%.2f", letzterZaehlerstand.zaehlerEnde)
                        } else {
                            zaehlerStartText = ""
                        }
                    } else {
                        zaehlerStartText = ""
                    }
                }
            }
            .onChange(of: zaehlerNummerText) { oldValue, newValue in
                // Wenn die Nummer geändert wird, versuche Start-Wert vom Vormieter zu holen
                // Nur wenn noch keine Zählerstände für diese Wohnung existieren
                if !isEdit && !zaehlerTyp.isEmpty {
                    let alleZaehlerstaende = DatabaseManager.shared.getZaehlerstaende(byWohnungId: wohnung.id)
                    
                    if alleZaehlerstaende.isEmpty {
                        let nummer = newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let letzterZaehlerstand = DatabaseManager.shared.getLetzterZaehlerstand(
                            wohnungId: wohnung.id,
                            zaehlerTyp: zaehlerTyp,
                            zaehlerNummer: nummer
                        ) {
                            zaehlerStartText = String(format: "%.2f", letzterZaehlerstand.zaehlerEnde)
                        } else {
                            zaehlerStartText = ""
                        }
                    } else {
                        zaehlerStartText = ""
                    }
                }
            }
            #if os(iOS)
            .sheet(item: $fotoZumAnzeigen) { foto in
                NavigationStack {
                    ZaehlerstandFotoFullScreenView(foto: foto, onBezeichnungSaved: {
                        if let z = editingZaehlerstand {
                            zaehlerstandFotos = DatabaseManager.shared.getZaehlerstandFotos(byZaehlerstandId: z.id)
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
        }
    }
}

#if os(iOS)
private struct ZaehlerstandFotoThumbnailView: View {
    let imagePath: String
    var body: some View {
        let url = DatabaseManager.shared.zaehlerstandFotoFullURL(imagePath: imagePath)
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

private struct ZaehlerstandFotoFullScreenView: View {
    let foto: ZaehlerstandFoto
    @State private var bildbezeichnung: String
    let onBezeichnungSaved: () -> Void
    init(foto: ZaehlerstandFoto, onBezeichnungSaved: @escaping () -> Void) {
        self.foto = foto
        self._bildbezeichnung = State(initialValue: foto.bildbezeichnung)
        self.onBezeichnungSaved = onBezeichnungSaved
    }
    var body: some View {
        VStack(spacing: 0) {
            TextField("Bezeichnung", text: $bildbezeichnung, prompt: Text("z. B. Zählerstand Ablesung"))
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .onSubmit {
                    _ = DatabaseManager.shared.updateZaehlerstandFotoBezeichnung(id: foto.id, bildbezeichnung: bildbezeichnung)
                    onBezeichnungSaved()
                }
            let url = DatabaseManager.shared.zaehlerstandFotoFullURL(imagePath: foto.imagePath)
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

private struct ZaehlerstandFotoZelleView: View {
    let foto: ZaehlerstandFoto
    let zaehlerstandId: Int64
    let istGesperrt: Bool
    let onDelete: () -> Void
    let onTapToView: () -> Void
    let onReload: () -> Void
    @State private var bezeichnung: String
    init(foto: ZaehlerstandFoto, zaehlerstandId: Int64, istGesperrt: Bool, onDelete: @escaping () -> Void, onTapToView: @escaping () -> Void, onReload: @escaping () -> Void) {
        self.foto = foto
        self.zaehlerstandId = zaehlerstandId
        self.istGesperrt = istGesperrt
        self.onDelete = onDelete
        self.onTapToView = onTapToView
        self.onReload = onReload
        self._bezeichnung = State(initialValue: foto.bildbezeichnung)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZaehlerstandFotoThumbnailView(imagePath: foto.imagePath)
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
                TextField("Bezeichnung", text: $bezeichnung, prompt: Text("z. B. Zählerstand"))
                    .font(.caption)
                    .lineLimit(1)
                    .onSubmit {
                        _ = DatabaseManager.shared.updateZaehlerstandFotoBezeichnung(id: foto.id, bildbezeichnung: bezeichnung)
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
