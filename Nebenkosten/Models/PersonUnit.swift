//
//  PersonUnit.swift
//  Nebenkosten
//
//  Personen-Einheiten für die Berechnung des Personenanteils (z. B. 2,3 Personen)
//

import Foundation

/// Typ des Faktors für eine Personen-Einheit
enum PersonUnitFactorType: String, Codable {
    case fixed           // Fester Faktor (z. B. 1.0, 0.5)
    case customNumber    // Frei wählbar 0.0–1.0
    case customDaysPerWeek  // Tage/Woche, Faktor = Tage/7
}

/// Eine Personen-Einheit (Bewohner vollzeit, Kind Wechselmodell, etc.)
struct PersonUnit: Identifiable {
    let id: String
    let label: String
    let hint: String
    let defaultFactor: Double?
    let factorType: PersonUnitFactorType
    let customMin: Double?
    let customMax: Double?
    let customStep: Double?
    let daysMin: Int?
    let daysMax: Int?
}

/// Alle verfügbaren Personen-Einheiten
enum PersonUnits {
    static let all: [PersonUnit] = [
        PersonUnit(id: "full_time_adult", label: "Bewohner (vollzeit)", hint: "dauerhaft im Haushalt",
                   defaultFactor: 1.0, factorType: .fixed, customMin: nil, customMax: nil, customStep: nil, daysMin: nil, daysMax: nil),
        PersonUnit(id: "full_time_child", label: "Kind (vollzeit)", hint: "dauerhaft im Haushalt",
                   defaultFactor: 1.0, factorType: .fixed, customMin: nil, customMax: nil, customStep: nil, daysMin: nil, daysMax: nil),
        PersonUnit(id: "shared_custody_child", label: "Kind im Wechselmodell (ca. 50%)", hint: "etwa jede zweite Woche / 50:50",
                   defaultFactor: 0.5, factorType: .fixed, customMin: nil, customMax: nil, customStep: nil, daysMin: nil, daysMax: nil),
        PersonUnit(id: "part_time_resident", label: "Teilzeitbewohner (ca. 3–4 Tage/Woche)", hint: "z. B. Pendler, Zweitwohnsitz",
                   defaultFactor: 0.5, factorType: .fixed, customMin: nil, customMax: nil, customStep: nil, daysMin: nil, daysMax: nil),
        PersonUnit(id: "weekend_resident", label: "Wochenendbewohner (ca. 2 Tage/Woche)", hint: "z. B. Partner nur am Wochenende",
                   defaultFactor: 0.3, factorType: .fixed, customMin: nil, customMax: nil, customStep: nil, daysMin: nil, daysMax: nil),
        PersonUnit(id: "regular_visitor", label: "Regelmäßiger Besucher (z. B. 1–2×/Woche)", hint: "wiederkehrend, aber kein Mitbewohner",
                   defaultFactor: 0.2, factorType: .fixed, customMin: nil, customMax: nil, customStep: nil, daysMin: nil, daysMax: nil),
        PersonUnit(id: "seasonal_stay", label: "Saison-/Ferienaufenthalt", hint: "z. B. Ferienkind, Enkel in den Ferien",
                   defaultFactor: 0.25, factorType: .fixed, customMin: nil, customMax: nil, customStep: nil, daysMin: nil, daysMax: nil),
        PersonUnit(id: "caregiver_hours", label: "Pflege-/Betreuungsperson (stundenweise regelmäßig)", hint: "regelmäßig, aber nicht wohnend",
                   defaultFactor: 0.1, factorType: .fixed, customMin: nil, customMax: nil, customStep: nil, daysMin: nil, daysMax: nil),
        PersonUnit(id: "custom_factor", label: "Individueller Anteil (frei)", hint: "wenn nichts passt; bitte begründen",
                   defaultFactor: nil, factorType: .customNumber, customMin: 0.0, customMax: 1.0, customStep: 0.1, daysMin: nil, daysMax: nil),
        PersonUnit(id: "custom_days_per_week", label: "Individueller Anteil nach Tagen/Woche", hint: "Programm rechnet: Tage/7",
                   defaultFactor: nil, factorType: .customDaysPerWeek, customMin: nil, customMax: nil, customStep: nil, daysMin: 0, daysMax: 7)
    ]
}
