# StoreKit-Konfiguration für In-App-Käufe

## Lokales Testen (Simulator/Xcode)

1. **StoreKit-Konfiguration aktivieren**
   - Xcode: **Product > Scheme > Edit Scheme…** (oder ⌘<)
   - Tab **Run** → **Options**
   - Bei **StoreKit Configuration** die Datei `Nebenkosten.storekit` auswählen

2. **App starten** – Käufe werden lokal simuliert, kein App Store Connect nötig.

## App Store Connect (Produktion / TestFlight)

Für echte Käufe (30 €) muss in App Store Connect ein In-App-Kauf angelegt werden:

1. **App Store Connect** → Ihre App → **Features** → **In-App Purchases**
2. **+** → **Non-Consumable**
3. **Produkt-ID (exakt):** `com.christinebehm.Nebenkosten.Premium`
4. **Preis:** 30,00 €
5. **Referenzname:** Premium
6. **Anzeigename:** Vollversion
7. Speichern und für Review einreichen

## Testen mit Sandbox

- Gerät: **Einstellungen > App Store > Sandbox-Konto** mit Test-Account anmelden
- Test-Account in App Store Connect unter **Users and Access > Sandbox > Testers** anlegen

## Developer-Toggle (nur Debug)

Im **System**-Menü unter **Developer** kann Premium manuell aktiviert werden – für Tests ohne Kauf.
