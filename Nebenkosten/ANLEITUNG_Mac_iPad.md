# Nebenkosten-App: Mac & iPad aktivieren

Diese Anleitung beschreibt, wie du die App für **iPad** und **Mac (Designed for iPad)** aktivierst. Danach läuft die App auf iPhone, iPad und MacBook M3.

---

## Voraussetzung

- Xcode geöffnet mit dem Projekt **Nebenkosten**
- Projekt muss erfolgreich bauen

---

## Schritt 1: Projekt öffnen

1. Xcode starten
2. **File → Open** (oder Cmd+O)
3. Ordner `Nebenkosten` auswählen und **Nebenkosten.xcodeproj** öffnen

---

## Schritt 2: Target auswählen

1. In der linken Seitenleiste auf das **blaue Projekt-Icon** (ganz oben) klicken
2. Unter **TARGETS** den Eintrag **Nebenkosten** auswählen

---

## Schritt 3: Supported Destinations hinzufügen

1. Tab **General** öffnen (falls nicht schon aktiv)
2. Zum Bereich **Deployment Info** scrollen
3. Bei **Supported Destinations** (oder **Deployment Target** / **Destinations**) auf das **+** klicken
4. Folgende Ziele hinzufügen (falls noch nicht vorhanden):
   - **iPad**
   - **Mac (Designed for iPad)**

> **Hinweis:** Wenn "Mac (Designed for iPad)" nicht angezeigt wird, kann alternativ **Mac Catalyst** gewählt werden. Die App läuft dann ebenfalls auf dem Mac.

---

## Schritt 4: Geräte-Familie prüfen

1. Im gleichen Bereich **Deployment Info** prüfen:
2. **Devices** sollte auf **Universal** (iPhone + iPad) stehen
3. Falls nur "iPhone" eingestellt ist: auf **Universal** umstellen

---

## Schritt 5: Build & Test

1. **Product → Build** (Cmd+B)
2. Oben in der Toolbar das **Zielgerät** auswählen:
   - **iPhone 16** (Simulator)
   - **iPad** (Simulator)
   - **My Mac (Designed for iPad)** – für MacBook M3

3. **Product → Run** (Cmd+R) zum Testen

---

## Übersicht der Einstellungen

| Einstellung | Wert |
|-------------|------|
| Devices | Universal (iPhone + iPad) |
| Supported Destinations | iPhone, iPad, Mac (Designed for iPad) |
| iOS Deployment Target | z.B. 17.0 (je nach Bedarf) |

---

## Bei Problemen

- **"Mac (Designed for iPad)" fehlt:** Xcode-Version prüfen (mind. Xcode 14). Alternativ **Mac Catalyst** verwenden.
- **Build-Fehler:** Prüfen, ob alle Abhängigkeiten (z.B. StoreKit, PDFKit) für die gewählten Plattformen verfügbar sind.
- **App startet nicht auf Mac:** Sicherstellen, dass ein **Apple Silicon Mac** (M1/M2/M3) verwendet wird.
