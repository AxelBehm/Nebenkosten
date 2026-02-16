//
//  UpgradeView.swift
//  Nebenkosten
//
//  Created by Axel Behm on 28.01.26.
//

import SwiftUI
import StoreKit

struct UpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var purchaseManager = PurchaseManager.shared
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var restoreSuccessMessage: String?
    @State private var showRestoreMessage = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.yellow)
                        Text("Vollversion")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Upgrade für unbegrenzte Nutzung")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)
                    
                    Divider()
                    
                    // Features
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Vollversion beinhaltet:")
                            .font(.headline)
                        
                        FeatureRow(icon: "building.2.fill", text: "Unbegrenzte Häuser", color: .blue)
                        FeatureRow(icon: "person.3.fill", text: "Unbegrenzte Wohnungen/Mieter", color: .green)
                        FeatureRow(icon: "calendar.badge.plus", text: "Unbegrenzte Jahre", color: .orange)
                        FeatureRow(icon: "checkmark.seal.fill", text: "Alle Funktionen freigeschaltet", color: .purple)
                        FeatureRow(icon: "arrow.clockwise", text: "Lifetime-Lizenz", color: .blue)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Preis
                    VStack(spacing: 8) {
                        Text("29,99 €")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(.blue)
                        Text("Einmalig")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    
                    // Hinweis in Test-Version (ohne Vollversion)
                    if !purchaseManager.isPremium {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text("Achtung")
                                    .font(.headline)
                            }
                            Text("In der Test-Version wird die PDF-Ausgabe mit einem Muster-Text versehen.")
                                .font(.subheadline)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // Kauf-Button
                    if purchaseManager.isPremium {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.green)
                            Text("Vollversion aktiv")
                                .font(.headline)
                            Text("Sie haben bereits die Vollversion erworben.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            #if DEBUG
                            Button("Test: Zurücksetzen") {
                                purchaseManager.isPremium = false
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            #else
                            if DeveloperHelper.isTestFlightOrSandbox {
                                Button("Test: Zurücksetzen") {
                                    purchaseManager.isPremium = false
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            #endif
                        }
                        .padding()
                    } else {
                        Button(action: {
                            Task {
                                await purchasePremium()
                            }
                        }) {
                            HStack {
                                if purchaseManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "star.fill")
                                        .font(.title3)
                                    Text("Vollversion kaufen - 29,99 €")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundColor(.white)
                            .background(
                                LinearGradient(colors: [Color(red: 0.2, green: 0.5, blue: 0.9), Color(red: 0.1, green: 0.35, blue: 0.75)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                        }
                        .disabled(purchaseManager.isLoading)
                        
                        Button(action: {
                            Task {
                                await restorePurchases()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .font(.subheadline)
                                Text("Käufe wiederherstellen")
                                    .font(.subheadline)
                            }
                            .foregroundStyle(Color(red: 0.2, green: 0.5, blue: 0.9))
                        }
                        .disabled(purchaseManager.isLoading)
                        
                        Text("„Käufe wiederherstellen“ nutzen Sie, wenn Sie die Vollversion bereits auf einem anderen Gerät gekauft haben.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                        
                        #if DEBUG
                        Text("Test: Premium kann unter Einstellungen > Developer manuell aktiviert werden.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 2)
                        #endif
                    }
                }
                .padding()
            }
            .navigationTitle("Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") {
                        dismiss()
                    }
                }
            }
            .alert("Fehler", isPresented: $showError) {
                Button("OK", role: .cancel) { }
                if let err = errorMessage {
                    Button("Details kopieren") {
                        #if os(iOS)
                        UIPasteboard.general.string = err
                        #endif
                    }
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
            .alert("Käufe wiederherstellen", isPresented: $showRestoreMessage) {
                Button("OK", role: .cancel) { }
            } message: {
                if let msg = restoreSuccessMessage {
                    Text(msg)
                }
            }
            .onAppear {
                // Sandbox-Konto früh anmelden, damit „Vollversion kaufen“ direkt funktioniert
                Task {
                    try? await AppStore.sync()
                    await purchaseManager.checkPurchaseStatus()
                }
            }
        }
    }
    
    private func purchasePremium() async {
        // Kurz warten, damit die Sheet-Ansicht fertig ist – sonst kann die System-Tastatur (Apple-ID/Passwort) blockiert bleiben
        try? await Task.sleep(nanoseconds: 300_000_000) // 0,3 s
        do {
            try await purchaseManager.purchasePremium()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func restorePurchases() async {
        do {
            let found = try await purchaseManager.restorePurchases()
            if found {
                restoreSuccessMessage = "Käufe erfolgreich wiederhergestellt. Vollversion ist aktiv."
            } else {
                restoreSuccessMessage = "Keine Käufe zum Wiederherstellen gefunden. Haben Sie die Vollversion bereits auf diesem Gerät oder mit diesem Apple-Konto gekauft?"
            }
            showRestoreMessage = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let text: String
    var color: Color = .blue
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(text)
            Spacer()
        }
    }
}

#Preview {
    UpgradeView()
}
