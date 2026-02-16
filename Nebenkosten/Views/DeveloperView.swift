//
//  DeveloperView.swift
//  Nebenkosten
//
//  Created by Axel Behm on 28.01.26.
//

import SwiftUI
#if os(iOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct DeveloperView: View {
    @ObservedObject private var purchaseManager = PurchaseManager.shared
    @State private var databasePath: String = ""
    @State private var hausCount: Int = 0
    @State private var wohnungCount: Int = 0
    @State private var kostenCount: Int = 0
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Build-Konfiguration")
                    Spacer()
                    Text(DeveloperHelper.buildConfiguration)
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Version")
                    Spacer()
                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                        Text(version)
                            .foregroundStyle(.secondary)
                    }
                }
                
                HStack {
                    Text("Build")
                    Spacer()
                    if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                        Text(build)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("App-Informationen")
            }
            
            Section {
                HStack {
                    Text("Datenbank-Pfad")
                    Spacer()
                    Text(databasePath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }
                
                #if os(iOS)
                Button(action: {
                    UIPasteboard.general.string = databasePath
                }) {
                    Label("Pfad kopieren", systemImage: "doc.on.doc")
                }
                #elseif os(macOS)
                Button(action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(databasePath, forType: .string)
                }) {
                    Label("Pfad kopieren", systemImage: "doc.on.doc")
                }
                #endif
            } header: {
                Text("Datenbank")
            }
            
            Section {
                HStack {
                    Text("Sätze in Haus")
                    Spacer()
                    Text("\(hausCount)")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Sätze in Mieter")
                    Spacer()
                    Text("\(wohnungCount)")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Sätze in Kosten")
                    Spacer()
                    Text("\(kostenCount)")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Datenbank-Statistik")
            }
            
            Section {
                Toggle(isOn: Binding(
                    get: { purchaseManager.isPremium },
                    set: { newValue in
                        purchaseManager.isPremium = newValue
                    }
                )) {
                    HStack {
                        Image(systemName: purchaseManager.isPremium ? "star.fill" : "star")
                            .foregroundStyle(purchaseManager.isPremium ? .yellow : .gray)
                        Text("Premium aktivieren (Test)")
                    }
                }
                
                Button(role: .destructive, action: {
                    // Optional: Entwickler-Funktionen hier hinzufügen
                }) {
                    Label("Datenbank zurücksetzen", systemImage: "trash")
                }
            } header: {
                Text("Entwickler-Funktionen")
            } footer: {
                Text("Mit dem Schalter können Sie Premium für Tests aktivieren/deaktivieren.")
            }
        }
        .navigationTitle("Developer")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            loadDatabaseInfo()
        }
    }
    
    private func loadDatabaseInfo() {
        // Datenbank-Pfad
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("nebenkosten.db")
        databasePath = fileURL.path
        
        // Statistiken
        let haeuser = DatabaseManager.shared.getAll()
        hausCount = haeuser.count
        
        var wohnungenTotal = 0
        var kostenTotal = 0
        for haus in haeuser {
            wohnungenTotal += DatabaseManager.shared.getWohnungen(byHausAbrechnungId: haus.id).count
            kostenTotal += DatabaseManager.shared.getKosten(byHausAbrechnungId: haus.id).count
        }
        wohnungCount = wohnungenTotal
        kostenCount = kostenTotal
    }
}

#Preview {
    NavigationStack {
        DeveloperView()
    }
}
