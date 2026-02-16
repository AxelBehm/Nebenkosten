//
//  AppButtonStyles.swift
//  Nebenkosten
//
//  Einheitliches Button- und Symbol-Set für die App.
//
//  Buttons:
//    Button("Speichern") { ... }.buttonStyle(.appProminent)
//    Button("Abbrechen") { ... }.buttonStyle(.appSecondary)
//
//  Symbole mit Hintergrund (z. B. in Listen oder Toolbars):
//    AppSymbol(systemName: "envelope.fill", backgroundColor: .appBlue)
//    AppSymbol(systemName: "doc.fill", size: .large, backgroundColor: .appGreen, shape: .roundedRect)
//
//  Nur Symbol stylen (ohne Kasten):
//    Image(systemName: "star.fill").appSymbolStyle(size: .medium, color: .appBlue)
//

import SwiftUI

// MARK: - Primär (hervorgehoben, z. B. Speichern, Kaufen)
struct AppProminentButtonStyle: ButtonStyle {
    var tint: Color = Color(red: 0.2, green: 0.5, blue: 0.9)
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(
                LinearGradient(
                    colors: [
                        tint,
                        tint.opacity(0.85)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: configuration.isPressed ? 1 : 3, x: 0, y: configuration.isPressed ? 0 : 2)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Sekundär (Rahmen, z. B. Abbrechen, Teilen)
struct AppSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.medium)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color(.systemGray4), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Grün (z. B. Bestätigen, Erfolg)
struct AppSuccessButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.2, green: 0.65, blue: 0.4),
                        Color(red: 0.1, green: 0.5, blue: 0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: configuration.isPressed ? 1 : 3, x: 0, y: configuration.isPressed ? 0 : 2)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Destruktiv (z. B. Löschen)
struct AppDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.red.opacity(configuration.isPressed ? 0.9 : 1))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Extension für einfache Nutzung
extension ButtonStyle where Self == AppProminentButtonStyle {
    static var appProminent: AppProminentButtonStyle { AppProminentButtonStyle() }
    static func appProminent(tint: Color) -> AppProminentButtonStyle { AppProminentButtonStyle(tint: tint) }
}

extension ButtonStyle where Self == AppSecondaryButtonStyle {
    static var appSecondary: AppSecondaryButtonStyle { AppSecondaryButtonStyle() }
}

extension ButtonStyle where Self == AppSuccessButtonStyle {
    static var appSuccess: AppSuccessButtonStyle { AppSuccessButtonStyle() }
}

extension ButtonStyle where Self == AppDestructiveButtonStyle {
    static var appDestructive: AppDestructiveButtonStyle { AppDestructiveButtonStyle() }
}

// MARK: - Symbol-/Icon-Styles (SF Symbols einheitlich)

/// Größe für App-Symbole
enum AppSymbolSize {
    case small, medium, large
    var font: Font {
        switch self {
        case .small: return .body
        case .medium: return .title3
        case .large: return .title2
        }
    }
    var size: CGFloat {
        switch self {
        case .small: return 20
        case .medium: return 28
        case .large: return 36
        }
    }
    var padding: CGFloat {
        switch self {
        case .small: return 6
        case .medium: return 10
        case .large: return 14
        }
    }
}

/// App-Farben für Symbole (passend zu den Buttons)
extension Color {
    static let appBlue = Color(red: 0.2, green: 0.5, blue: 0.9)
    static let appGreen = Color(red: 0.2, green: 0.65, blue: 0.4)
    static let appOrange = Color(red: 0.95, green: 0.5, blue: 0.1)
    static let appGray = Color(red: 0.45, green: 0.48, blue: 0.55)
}

/// Symbol mit Hintergrund (Kreis oder abgerundetes Rechteck) – passt zu den Buttons
struct AppSymbol: View {
    let systemName: String
    var size: AppSymbolSize = .medium
    var color: Color = .white
    var backgroundColor: Color? = nil
    var shape: AppSymbolShape = .circle
    
    enum AppSymbolShape {
        case circle
        case roundedRect
    }
    
    var body: some View {
        Image(systemName: systemName)
            .font(size.font)
            .fontWeight(.medium)
            .foregroundStyle(color)
            .frame(width: size.size + size.padding * 2, height: size.size + size.padding * 2)
            .background(backgroundView)
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        if let bg = backgroundColor {
            Group {
                switch shape {
                case .circle:
                    Circle().fill(bg)
                case .roundedRect:
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(bg)
                }
            }
            .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
        }
    }
}

/// Modifier: Bild (Symbol) einheitlich stylen – z. B. für Listen oder Labels
struct AppSymbolStyle: ViewModifier {
    var size: AppSymbolSize = .medium
    var color: Color = .accentColor
    
    func body(content: Content) -> some View {
        content
            .font(size.font)
            .fontWeight(.medium)
            .foregroundStyle(color)
            .symbolRenderingMode(.hierarchical)
    }
}

extension View {
    /// Symbol einheitlich darstellen (Größe + Farbe)
    func appSymbolStyle(size: AppSymbolSize = .medium, color: Color = .accentColor) -> some View {
        modifier(AppSymbolStyle(size: size, color: color))
    }
}
