//
//  ShareSheet.swift
//  Nebenkosten
//
//  Created by Axel Behm on 22.01.26.
//

import SwiftUI
import UIKit

// Wrapper für PDF-Daten, damit sie als Share-Item verwendet werden können
class PDFShareItem: NSObject, UIActivityItemSource {
    let pdfData: Data
    let fileName: String
    let emailAddress: String?
    
    init(pdfData: Data, fileName: String = "Nebenkostenabrechnung.pdf", emailAddress: String? = nil) {
        self.pdfData = pdfData
        self.fileName = fileName
        self.emailAddress = emailAddress
        super.init()
    }
    
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return pdfData
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        // Für bestimmte Aktivitäten die Daten direkt zurückgeben
        if activityType == .mail || activityType == .message || activityType == .print {
            return pdfData
        }
        
        // Für andere Aktivitäten: Speichere in temporäre Datei
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try pdfData.write(to: tempURL)
            return tempURL
        } catch {
            print("Fehler beim Speichern: \(error)")
            return pdfData
        }
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return fileName.replacingOccurrences(of: ".pdf", with: "")
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        return "com.adobe.pdf"
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let emailAddress: String?
    @Environment(\.dismiss) var dismiss
    
    init(items: [Any], emailAddress: String? = nil) {
        self.items = items
        self.emailAddress = emailAddress
    }
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        // Konvertiere PDF-Daten zu PDFShareItem
        var shareItems: [Any] = []
        
        for item in items {
            if let pdfData = item as? Data {
                let shareItem = PDFShareItem(pdfData: pdfData, emailAddress: emailAddress)
                shareItems.append(shareItem)
            } else {
                shareItems.append(item)
            }
        }
        
        // Wenn E-Mail-Adresse vorhanden ist, füge sie als Text-Item hinzu
        // (UIActivityViewController unterstützt das direkte Setzen von E-Mail-Empfängern nicht,
        // aber die E-Mail-Adresse wird im Text angezeigt und kann kopiert werden)
        if let email = emailAddress, !email.isEmpty {
            shareItems.append("E-Mail-Adresse: \(email)")
        }
        
        let controller = UIActivityViewController(
            activityItems: shareItems,
            applicationActivities: nil
        )
        
        // Completion Handler
        controller.completionWithItemsHandler = { activityType, completed, returnedItems, error in
            if let error = error {
                print("Share Sheet Fehler: \(error.localizedDescription)")
            }
            dismiss()
        }
        
        // Für iPad: Popover konfigurieren
        if let popover = controller.popoverPresentationController {
            popover.sourceView = UIView()
            popover.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // Nichts zu aktualisieren
    }
}
