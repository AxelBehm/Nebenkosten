//
//  MailComposeView.swift
//  Nebenkosten
//
//  Created by Axel Behm on 22.01.26.
//

import SwiftUI
import MessageUI

struct MailComposeView: UIViewControllerRepresentable {
    let pdfData: Data
    let fileName: String
    let recipientEmail: String?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        
        // Setze Empfänger, falls vorhanden
        if let email = recipientEmail, !email.isEmpty {
            composer.setToRecipients([email])
        }
        
        // Setze Betreff
        let subject = fileName.replacingOccurrences(of: ".pdf", with: "")
        composer.setSubject(subject)
        
        // Füge PDF als Anhang hinzu
        composer.addAttachmentData(pdfData, mimeType: "application/pdf", fileName: fileName)
        
        return composer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
        // Nichts zu aktualisieren
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposeView
        
        init(_ parent: MailComposeView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            if let error = error {
                print("Mail Fehler: \(error.localizedDescription)")
            }
            parent.dismiss()
        }
    }
}
