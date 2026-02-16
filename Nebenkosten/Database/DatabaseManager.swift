//
//  DatabaseManager.swift
//  Nebenkosten
//
//  Created by Axel Behm on 22.01.26.
//

import Foundation
import SQLite3

class DatabaseManager {
    static let shared = DatabaseManager()
    
    private var db: OpaquePointer?
    private let dbName = "nebenkosten.db"
    
    private init() {
        openDatabase()
        createTable()
    }
    
    deinit {
        closeDatabase()
    }
    
    private func openDatabase() {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent(dbName)
        
        print("Datenbank-Pfad: \(fileURL.path)")
        
        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            print("Fehler beim Öffnen der Datenbank: \(String(cString: sqlite3_errmsg(db)))")
        } else {
            print("Datenbank erfolgreich geöffnet")
        }
    }
    
    private func closeDatabase() {
        if let connection = db {
            sqlite3_close(connection)
            db = nil
        }
    }
    
    private func createTable() {
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS HausAbrechnung (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                hausBezeichnung TEXT NOT NULL,
                abrechnungsJahr INTEGER NOT NULL,
                postleitzahl TEXT,
                ort TEXT,
                gesamtflaeche INTEGER,
                anzahlWohnungen INTEGER,
                leerstandspruefung TEXT,
                verwalterName TEXT,
                verwalterStrasse TEXT,
                verwalterPLZOrt TEXT,
                verwalterEmail TEXT,
                verwalterTelefon TEXT,
                verwalterInEmailVorbelegen INTEGER,
                UNIQUE(hausBezeichnung, abrechnungsJahr)
            );
        """
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, createTableSQL, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_DONE {
                print("Tabelle erfolgreich erstellt")
            } else {
                print("Fehler beim Erstellen der Tabelle")
            }
        }
        sqlite3_finalize(statement)
        
        // Migration: Neue Spalten hinzufügen falls sie noch nicht existieren
        migrateTable()
        
        createWohnungTable()
        createMietzeitraumTable()
        createMitmieterTable()
        createZaehlerstandTable()
        createKostenTable()
        createEinzelnachweisWohnungTable()
        createHausFotoTable()
        createMietzeitraumFotoTable()
        createKostenFotoTable()
        createZaehlerstandFotoTable()
    }
    
    private func createZaehlerstandFotoTable() {
        runSQL("""
            CREATE TABLE IF NOT EXISTS ZaehlerstandFoto (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                zaehlerstandId INTEGER NOT NULL,
                imagePath TEXT NOT NULL,
                sortOrder INTEGER NOT NULL DEFAULT 0,
                bildbezeichnung TEXT
            );
            """)
        runSQL("CREATE INDEX IF NOT EXISTS idx_zaehlerstandfoto_z ON ZaehlerstandFoto(zaehlerstandId);")
    }
    
    private func createKostenFotoTable() {
        runSQL("""
            CREATE TABLE IF NOT EXISTS KostenFoto (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                kostenId INTEGER NOT NULL,
                imagePath TEXT NOT NULL,
                sortOrder INTEGER NOT NULL DEFAULT 0,
                bildbezeichnung TEXT
            );
            """)
        runSQL("CREATE INDEX IF NOT EXISTS idx_kostenfoto_k ON KostenFoto(kostenId);")
    }
    
    private func createMietzeitraumFotoTable() {
        runSQL("""
            CREATE TABLE IF NOT EXISTS MietzeitraumFoto (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                mietzeitraumId INTEGER NOT NULL,
                imagePath TEXT NOT NULL,
                sortOrder INTEGER NOT NULL DEFAULT 0
            );
            """)
        runSQL("CREATE INDEX IF NOT EXISTS idx_mietzeitraumfoto_mz ON MietzeitraumFoto(mietzeitraumId);")
        migrateMietzeitraumFotoTable()
    }
    
    private func migrateMietzeitraumFotoTable() {
        let alterSQL = "ALTER TABLE MietzeitraumFoto ADD COLUMN bildbezeichnung TEXT;"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, alterSQL, -1, &statement, nil) == SQLITE_OK {
            let result = sqlite3_step(statement)
            if result == SQLITE_ERROR {
                let err = String(cString: sqlite3_errmsg(db))
                if !err.contains("duplicate column") { print("MietzeitraumFoto Migration: \(err)") }
            }
        }
        sqlite3_finalize(statement)
    }
    
    private func createHausFotoTable() {
        runSQL("""
            CREATE TABLE IF NOT EXISTS HausFoto (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                hausBezeichnung TEXT NOT NULL,
                imagePath TEXT NOT NULL,
                sortOrder INTEGER NOT NULL DEFAULT 0
            );
            """)
        runSQL("CREATE INDEX IF NOT EXISTS idx_hausfoto_haus ON HausFoto(hausBezeichnung);")
        migrateHausFotoTable()
    }
    
    private func migrateHausFotoTable() {
        let alterSQL = "ALTER TABLE HausFoto ADD COLUMN bildbezeichnung TEXT;"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, alterSQL, -1, &statement, nil) == SQLITE_OK {
            let result = sqlite3_step(statement)
            if result == SQLITE_ERROR {
                let err = String(cString: sqlite3_errmsg(db))
                if !err.contains("duplicate column") { print("HausFoto Migration: \(err)") }
            }
        }
        sqlite3_finalize(statement)
    }
    
    private func createEinzelnachweisWohnungTable() {
        runSQL("""
            CREATE TABLE IF NOT EXISTS EinzelnachweisWohnung (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                kostenId INTEGER NOT NULL,
                wohnungId INTEGER NOT NULL,
                von TEXT,
                betrag REAL,
                FOREIGN KEY (kostenId) REFERENCES Kosten(id) ON DELETE CASCADE,
                FOREIGN KEY (wohnungId) REFERENCES Wohnung(id) ON DELETE CASCADE,
                UNIQUE(kostenId, wohnungId)
            );
        """)
        runSQL("CREATE INDEX IF NOT EXISTS idx_einzelnachweis_kosten ON EinzelnachweisWohnung(kostenId);")
        runSQL("CREATE INDEX IF NOT EXISTS idx_einzelnachweis_wohnung ON EinzelnachweisWohnung(wohnungId);")
    }
    
    private func createWohnungTable() {
        runSQL("""
            CREATE TABLE IF NOT EXISTS Wohnung (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                hausAbrechnungId INTEGER NOT NULL,
                wohnungsnummer TEXT,
                bezeichnung TEXT NOT NULL,
                qm INTEGER NOT NULL,
                name TEXT,
                strasse TEXT,
                plz TEXT,
                ort TEXT,
                email TEXT,
                telefon TEXT,
                FOREIGN KEY (hausAbrechnungId) REFERENCES HausAbrechnung(id) ON DELETE CASCADE
            );
        """)
        runSQL("CREATE INDEX IF NOT EXISTS idx_wohnung_haus ON Wohnung(hausAbrechnungId);")
        migrateWohnungTable()
    }
    
    private func migrateWohnungTable() {
        let columnsToAdd = [
            ("wohnungsnummer", "TEXT"),
            ("name", "TEXT"),
            ("strasse", "TEXT"),
            ("plz", "TEXT"),
            ("ort", "TEXT"),
            ("email", "TEXT"),
            ("telefon", "TEXT")
        ]
        
        for (columnName, columnType) in columnsToAdd {
            let alterSQL = "ALTER TABLE Wohnung ADD COLUMN \(columnName) \(columnType);"
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, alterSQL, -1, &statement, nil) == SQLITE_OK {
                let result = sqlite3_step(statement)
                if result == SQLITE_DONE {
                    print("Spalte \(columnName) erfolgreich hinzugefügt")
                } else if result == SQLITE_ERROR {
                    let errorMsg = String(cString: sqlite3_errmsg(db))
                    if !errorMsg.contains("duplicate column") {
                        print("Fehler beim Hinzufügen der Spalte \(columnName): \(errorMsg)")
                    }
                }
            }
            sqlite3_finalize(statement)
        }
    }
    
    private func createMietzeitraumTable() {
        runSQL("""
            CREATE TABLE IF NOT EXISTS Mietzeitraum (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                wohnungId INTEGER NOT NULL,
                jahr INTEGER NOT NULL,
                hauptmieterName TEXT NOT NULL,
                vonDatum TEXT NOT NULL,
                bisDatum TEXT NOT NULL,
                anzahlPersonen INTEGER,
                FOREIGN KEY (wohnungId) REFERENCES Wohnung(id) ON DELETE CASCADE
            );
        """)
        runSQL("CREATE INDEX IF NOT EXISTS idx_mietzeitraum_wohnung ON Mietzeitraum(wohnungId);")
        migrateMietzeitraumTable()
    }
    
    private func migrateMietzeitraumTable() {
        let columnsToAdd = [
            ("jahr", "INTEGER"),
            ("anzahlPersonen", "INTEGER"),
            ("mietendeOption", "TEXT")
        ]
        
        for (columnName, columnType) in columnsToAdd {
            let alterSQL = "ALTER TABLE Mietzeitraum ADD COLUMN \(columnName) \(columnType);"
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, alterSQL, -1, &statement, nil) == SQLITE_OK {
                let result = sqlite3_step(statement)
                if result == SQLITE_DONE {
                    print("Spalte \(columnName) erfolgreich hinzugefügt")
                } else if result == SQLITE_ERROR {
                    let errorMsg = String(cString: sqlite3_errmsg(db))
                    if !errorMsg.contains("duplicate column") {
                        print("Fehler beim Hinzufügen der Spalte \(columnName): \(errorMsg)")
                    }
                }
            }
            sqlite3_finalize(statement)
        }
        
        // Für bestehende Datensätze: Jahr aus vonDatum extrahieren
        let updateSQL = "UPDATE Mietzeitraum SET jahr = CAST(substr(vonDatum, 1, 4) AS INTEGER) WHERE jahr IS NULL OR jahr = 0;"
        runSQL(updateSQL)
        
        // Für bestehende Datensätze: Anzahl Personen auf 1 setzen, falls NULL
        let updateAnzahlSQL = "UPDATE Mietzeitraum SET anzahlPersonen = 1 WHERE anzahlPersonen IS NULL;"
        runSQL(updateAnzahlSQL)
        
        // Für bestehende Datensätze: mietendeOption auf mietendeOffen setzen, falls NULL
        let updateMietendeSQL = "UPDATE Mietzeitraum SET mietendeOption = 'mietendeOffen' WHERE mietendeOption IS NULL OR mietendeOption = '';"
        runSQL(updateMietendeSQL)
    }
    
    private func createMitmieterTable() {
        runSQL("""
            CREATE TABLE IF NOT EXISTS Mitmieter (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                mietzeitraumId INTEGER NOT NULL,
                name TEXT NOT NULL,
                vonDatum TEXT NOT NULL,
                bisDatum TEXT NOT NULL,
                FOREIGN KEY (mietzeitraumId) REFERENCES Mietzeitraum(id) ON DELETE CASCADE
            );
        """)
        runSQL("CREATE INDEX IF NOT EXISTS idx_mitmieter_mietzeitraum ON Mitmieter(mietzeitraumId);")
    }
    
    private func createZaehlerstandTable() {
        runSQL("""
            CREATE TABLE IF NOT EXISTS Zaehlerstand (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                wohnungId INTEGER NOT NULL,
                zaehlerTyp TEXT NOT NULL,
                zaehlerNummer TEXT,
                zaehlerStart REAL NOT NULL,
                zaehlerEnde REAL NOT NULL,
                differenz REAL NOT NULL,
                auchAbwasser INTEGER,
                FOREIGN KEY (wohnungId) REFERENCES Wohnung(id) ON DELETE CASCADE
            );
        """)
        runSQL("CREATE INDEX IF NOT EXISTS idx_zaehlerstand_wohnung ON Zaehlerstand(wohnungId);")
        runSQL("CREATE INDEX IF NOT EXISTS idx_zaehlerstand_typ ON Zaehlerstand(zaehlerTyp);")
        migrateZaehlerstandTable()
    }
    
    private func migrateZaehlerstandTable() {
        let columnsToAdd = [
            ("zaehlerNummer", "TEXT"),
            ("auchAbwasser", "INTEGER"),
            ("beschreibung", "TEXT")
        ]
        
        for (columnName, columnType) in columnsToAdd {
            let alterSQL = "ALTER TABLE Zaehlerstand ADD COLUMN \(columnName) \(columnType);"
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, alterSQL, -1, &statement, nil) == SQLITE_OK {
                let result = sqlite3_step(statement)
                if result == SQLITE_DONE {
                    print("Spalte \(columnName) erfolgreich hinzugefügt")
                } else if result == SQLITE_ERROR {
                    let errorMsg = String(cString: sqlite3_errmsg(db))
                    if !errorMsg.contains("duplicate column") {
                        print("Fehler beim Hinzufügen der Spalte \(columnName): \(errorMsg)")
                    }
                }
            }
            sqlite3_finalize(statement)
        }
    }
    
    private func createKostenTable() {
        runSQL("""
            CREATE TABLE IF NOT EXISTS Kosten (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                hausAbrechnungId INTEGER NOT NULL,
                kostenart TEXT NOT NULL,
                betrag REAL NOT NULL,
                bezeichnung TEXT,
                verteilungsart TEXT,
                FOREIGN KEY (hausAbrechnungId) REFERENCES HausAbrechnung(id) ON DELETE CASCADE
            );
        """)
        runSQL("CREATE INDEX IF NOT EXISTS idx_kosten_haus ON Kosten(hausAbrechnungId);")
        migrateKostenTable()
    }
    
    private func migrateKostenTable() {
        let columnsToAdd = [
            ("verteilungsart", "TEXT"),
            ("von", "TEXT")
        ]
        
        for (columnName, columnType) in columnsToAdd {
            let alterSQL = "ALTER TABLE Kosten ADD COLUMN \(columnName) \(columnType);"
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, alterSQL, -1, &statement, nil) == SQLITE_OK {
                let result = sqlite3_step(statement)
                if result == SQLITE_DONE {
                    print("Spalte \(columnName) erfolgreich hinzugefügt")
                } else if result == SQLITE_ERROR {
                    let errorMsg = String(cString: sqlite3_errmsg(db))
                    if !errorMsg.contains("duplicate column") {
                        print("Fehler beim Hinzufügen der Spalte \(columnName): \(errorMsg)")
                    }
                }
            }
            sqlite3_finalize(statement)
        }
        
        // Für bestehende Datensätze: Standard-Verteilungsart setzen
        let updateSQL = "UPDATE Kosten SET verteilungsart = 'nach Qm' WHERE verteilungsart IS NULL;"
        runSQL(updateSQL)
    }
    
    private func runSQL(_ sql: String) {
        var s: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &s, nil) == SQLITE_OK {
            if sqlite3_step(s) != SQLITE_DONE {
                print("SQL Fehler: \(String(cString: sqlite3_errmsg(db)))")
            }
        }
        sqlite3_finalize(s)
    }
    
    private func migrateTable() {
        let columnsToAdd = [
            ("postleitzahl", "TEXT"),
            ("ort", "TEXT"),
            ("gesamtflaeche", "INTEGER"),
            ("anzahlWohnungen", "INTEGER"),
            ("leerstandspruefung", "TEXT"),
            ("verwalterName", "TEXT"),
            ("verwalterStrasse", "TEXT"),
            ("verwalterPLZOrt", "TEXT"),
            ("verwalterEmail", "TEXT"),
            ("verwalterTelefon", "TEXT"),
            ("verwalterInEmailVorbelegen", "INTEGER")
        ]
        
        for (columnName, columnType) in columnsToAdd {
            let alterSQL = "ALTER TABLE HausAbrechnung ADD COLUMN \(columnName) \(columnType);"
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, alterSQL, -1, &statement, nil) == SQLITE_OK {
                let result = sqlite3_step(statement)
                if result == SQLITE_DONE {
                    print("Spalte \(columnName) erfolgreich hinzugefügt")
                } else if result == SQLITE_ERROR {
                    let errorMsg = String(cString: sqlite3_errmsg(db))
                    // Ignoriere Fehler wenn Spalte bereits existiert
                    if !errorMsg.contains("duplicate column") {
                        print("Fehler beim Hinzufügen der Spalte \(columnName): \(errorMsg)")
                    }
                }
            }
            sqlite3_finalize(statement)
        }
    }
    
    private func commit() -> Bool {
        let commitSQL = "COMMIT;"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, commitSQL, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_DONE {
                sqlite3_finalize(statement)
                return true
            }
        }
        sqlite3_finalize(statement)
        return false
    }
    
    private func beginTransaction() -> Bool {
        let beginSQL = "BEGIN TRANSACTION;"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, beginSQL, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_DONE {
                sqlite3_finalize(statement)
                return true
            }
        }
        sqlite3_finalize(statement)
        return false
    }
    
    func insert(hausAbrechnung: HausAbrechnung) -> Bool {
        print("Einfügen: Haus='\(hausAbrechnung.hausBezeichnung)' (Länge: \(hausAbrechnung.hausBezeichnung.count)), Jahr=\(hausAbrechnung.abrechnungsJahr)")
        beginTransaction()
        
        let insertSQL = """
            INSERT INTO HausAbrechnung (
                hausBezeichnung, abrechnungsJahr, postleitzahl, ort, gesamtflaeche,
                anzahlWohnungen, leerstandspruefung, verwalterName, verwalterStrasse,
                verwalterPLZOrt, verwalterEmail, verwalterTelefon, verwalterInEmailVorbelegen
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        var success = false
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            var paramIndex: Int32 = 1
            
            // hausBezeichnung
            let hausBezeichnungString = (hausAbrechnung.hausBezeichnung as NSString).utf8String
            sqlite3_bind_text(statement, paramIndex, hausBezeichnungString, -1, nil)
            paramIndex += 1
            
            // abrechnungsJahr
            sqlite3_bind_int(statement, paramIndex, Int32(hausAbrechnung.abrechnungsJahr))
            paramIndex += 1
            
            // postleitzahl
            if let plz = hausAbrechnung.postleitzahl, !plz.isEmpty {
                sqlite3_bind_text(statement, paramIndex, (plz as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(statement, paramIndex)
            }
            paramIndex += 1
            
            // ort
            if let ort = hausAbrechnung.ort, !ort.isEmpty {
                sqlite3_bind_text(statement, paramIndex, (ort as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(statement, paramIndex)
            }
            paramIndex += 1
            
            // gesamtflaeche
            if let flaeche = hausAbrechnung.gesamtflaeche {
                sqlite3_bind_int(statement, paramIndex, Int32(flaeche))
            } else {
                sqlite3_bind_null(statement, paramIndex)
            }
            paramIndex += 1
            
            // anzahlWohnungen
            if let anzahl = hausAbrechnung.anzahlWohnungen {
                sqlite3_bind_int(statement, paramIndex, Int32(anzahl))
            } else {
                sqlite3_bind_null(statement, paramIndex)
            }
            paramIndex += 1
            
            // leerstandspruefung
            if let pruefung = hausAbrechnung.leerstandspruefung {
                sqlite3_bind_text(statement, paramIndex, (pruefung.rawValue as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(statement, paramIndex)
            }
            paramIndex += 1
            
            // verwalterName
            if let name = hausAbrechnung.verwalterName, !name.isEmpty {
                sqlite3_bind_text(statement, paramIndex, (name as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(statement, paramIndex)
            }
            paramIndex += 1
            
            // verwalterStrasse
            if let strasse = hausAbrechnung.verwalterStrasse, !strasse.isEmpty {
                sqlite3_bind_text(statement, paramIndex, (strasse as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(statement, paramIndex)
            }
            paramIndex += 1
            
            // verwalterPLZOrt
            if let plzOrt = hausAbrechnung.verwalterPLZOrt, !plzOrt.isEmpty {
                sqlite3_bind_text(statement, paramIndex, (plzOrt as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(statement, paramIndex)
            }
            paramIndex += 1
            
            // verwalterEmail
            if let email = hausAbrechnung.verwalterEmail, !email.isEmpty {
                sqlite3_bind_text(statement, paramIndex, (email as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(statement, paramIndex)
            }
            paramIndex += 1
            
            // verwalterTelefon
            if let telefon = hausAbrechnung.verwalterTelefon, !telefon.isEmpty {
                sqlite3_bind_text(statement, paramIndex, (telefon as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(statement, paramIndex)
            }
            paramIndex += 1
            
            // verwalterInEmailVorbelegen
            if let vorbelegen = hausAbrechnung.verwalterInEmailVorbelegen {
                sqlite3_bind_int(statement, paramIndex, vorbelegen ? 1 : 0)
            } else {
                sqlite3_bind_null(statement, paramIndex)
            }
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("INSERT erfolgreich ausgeführt")
                success = true
            } else {
                print("Fehler beim Einfügen: \(String(cString: sqlite3_errmsg(db)))")
            }
        } else {
            print("Fehler beim Vorbereiten: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
        
        if success {
            if commit() {
                print("Commit erfolgreich")
                return true
            } else {
                print("Fehler beim Commit")
                return false
            }
        }
        return false
    }
    
    func getAll() -> [HausAbrechnung] {
        let querySQL = """
            SELECT id, hausBezeichnung, abrechnungsJahr, postleitzahl, ort, gesamtflaeche,
                   anzahlWohnungen, leerstandspruefung, verwalterName, verwalterStrasse,
                   verwalterPLZOrt, verwalterEmail, verwalterTelefon, verwalterInEmailVorbelegen
            FROM HausAbrechnung
            ORDER BY hausBezeichnung, abrechnungsJahr DESC;
        """
        var statement: OpaquePointer?
        var hausAbrechnungen: [HausAbrechnung] = []
        
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = sqlite3_column_int64(statement, 0)
                
                let hausBezeichnungText = sqlite3_column_text(statement, 1)
                let hausBezeichnung = hausBezeichnungText != nil ? String(cString: hausBezeichnungText!) : ""
                
                let abrechnungsJahr = Int(sqlite3_column_int(statement, 2))
                
                // Optionale Felder
                let postleitzahl = sqlite3_column_text(statement, 3) != nil ? String(cString: sqlite3_column_text(statement, 3)!) : nil
                let ort = sqlite3_column_text(statement, 4) != nil ? String(cString: sqlite3_column_text(statement, 4)!) : nil
                let gesamtflaeche = sqlite3_column_type(statement, 5) != SQLITE_NULL ? Int(sqlite3_column_int(statement, 5)) : nil
                let anzahlWohnungen = sqlite3_column_type(statement, 6) != SQLITE_NULL ? Int(sqlite3_column_int(statement, 6)) : nil
                
                let leerstandspruefungRaw = sqlite3_column_text(statement, 7) != nil ? String(cString: sqlite3_column_text(statement, 7)!) : nil
                let leerstandspruefung = leerstandspruefungRaw != nil ? Leerstandspruefung(rawValue: leerstandspruefungRaw!) : nil
                
                let verwalterName = sqlite3_column_text(statement, 8) != nil ? String(cString: sqlite3_column_text(statement, 8)!) : nil
                let verwalterStrasse = sqlite3_column_text(statement, 9) != nil ? String(cString: sqlite3_column_text(statement, 9)!) : nil
                let verwalterPLZOrt = sqlite3_column_text(statement, 10) != nil ? String(cString: sqlite3_column_text(statement, 10)!) : nil
                let verwalterEmail = sqlite3_column_text(statement, 11) != nil ? String(cString: sqlite3_column_text(statement, 11)!) : nil
                let verwalterTelefon = sqlite3_column_text(statement, 12) != nil ? String(cString: sqlite3_column_text(statement, 12)!) : nil
                let verwalterInEmailVorbelegen = sqlite3_column_type(statement, 13) != SQLITE_NULL ? (sqlite3_column_int(statement, 13) == 1) : nil
                
                print("Geladen: ID=\(id), Haus=\(hausBezeichnung), Jahr=\(abrechnungsJahr)")
                
                hausAbrechnungen.append(HausAbrechnung(
                    id: id,
                    hausBezeichnung: hausBezeichnung,
                    abrechnungsJahr: abrechnungsJahr,
                    postleitzahl: postleitzahl,
                    ort: ort,
                    gesamtflaeche: gesamtflaeche,
                    anzahlWohnungen: anzahlWohnungen,
                    leerstandspruefung: leerstandspruefung,
                    verwalterName: verwalterName,
                    verwalterStrasse: verwalterStrasse,
                    verwalterPLZOrt: verwalterPLZOrt,
                    verwalterEmail: verwalterEmail,
                    verwalterTelefon: verwalterTelefon,
                    verwalterInEmailVorbelegen: verwalterInEmailVorbelegen
                ))
            }
        } else {
            print("Fehler beim Abfragen: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
        return hausAbrechnungen
    }
    
    func update(hausAbrechnung: HausAbrechnung) -> Bool {
        print("Aktualisieren: ID=\(hausAbrechnung.id), Haus='\(hausAbrechnung.hausBezeichnung)' (Länge: \(hausAbrechnung.hausBezeichnung.count)), Jahr=\(hausAbrechnung.abrechnungsJahr)")
        beginTransaction()
        
        let updateSQL = """
            UPDATE HausAbrechnung SET
                hausBezeichnung = ?, abrechnungsJahr = ?, postleitzahl = ?, ort = ?,
                gesamtflaeche = ?, anzahlWohnungen = ?, leerstandspruefung = ?,
                verwalterName = ?, verwalterStrasse = ?, verwalterPLZOrt = ?,
                verwalterEmail = ?, verwalterTelefon = ?, verwalterInEmailVorbelegen = ?
            WHERE id = ?;
        """
        var statement: OpaquePointer?
        var success = false
        
        if sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK {
            var paramIndex: Int32 = 1
            
            // hausBezeichnung
            let hausBezeichnungString = (hausAbrechnung.hausBezeichnung as NSString).utf8String
            sqlite3_bind_text(statement, paramIndex, hausBezeichnungString, -1, nil)
            paramIndex += 1
            
            // abrechnungsJahr
            sqlite3_bind_int(statement, paramIndex, Int32(hausAbrechnung.abrechnungsJahr))
            paramIndex += 1
            
            // postleitzahl
            if let plz = hausAbrechnung.postleitzahl, !plz.isEmpty {
                sqlite3_bind_text(statement, paramIndex, (plz as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(statement, paramIndex)
            }
            paramIndex += 1
            
            // ort
            if let ort = hausAbrechnung.ort, !ort.isEmpty {
                sqlite3_bind_text(statement, paramIndex, (ort as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(statement, paramIndex)
            }
            paramIndex += 1
            
            // gesamtflaeche
            if let flaeche = hausAbrechnung.gesamtflaeche {
                sqlite3_bind_int(statement, paramIndex, Int32(flaeche))
            } else {
                sqlite3_bind_null(statement, paramIndex)
            }
            paramIndex += 1
            
            // anzahlWohnungen
            if let anzahl = hausAbrechnung.anzahlWohnungen {
                sqlite3_bind_int(statement, paramIndex, Int32(anzahl))
            } else {
                sqlite3_bind_null(statement, paramIndex)
            }
            paramIndex += 1
            
            // leerstandspruefung
            if let pruefung = hausAbrechnung.leerstandspruefung {
                sqlite3_bind_text(statement, paramIndex, (pruefung.rawValue as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(statement, paramIndex)
            }
            paramIndex += 1
            
            // verwalterName
            if let name = hausAbrechnung.verwalterName, !name.isEmpty {
                sqlite3_bind_text(statement, paramIndex, (name as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(statement, paramIndex)
            }
            paramIndex += 1
            
            // verwalterStrasse
            if let strasse = hausAbrechnung.verwalterStrasse, !strasse.isEmpty {
                sqlite3_bind_text(statement, paramIndex, (strasse as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(statement, paramIndex)
            }
            paramIndex += 1
            
            // verwalterPLZOrt
            if let plzOrt = hausAbrechnung.verwalterPLZOrt, !plzOrt.isEmpty {
                sqlite3_bind_text(statement, paramIndex, (plzOrt as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(statement, paramIndex)
            }
            paramIndex += 1
            
            // verwalterEmail
            if let email = hausAbrechnung.verwalterEmail, !email.isEmpty {
                sqlite3_bind_text(statement, paramIndex, (email as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(statement, paramIndex)
            }
            paramIndex += 1
            
            // verwalterTelefon
            if let telefon = hausAbrechnung.verwalterTelefon, !telefon.isEmpty {
                sqlite3_bind_text(statement, paramIndex, (telefon as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(statement, paramIndex)
            }
            paramIndex += 1
            
            // verwalterInEmailVorbelegen
            if let vorbelegen = hausAbrechnung.verwalterInEmailVorbelegen {
                sqlite3_bind_int(statement, paramIndex, vorbelegen ? 1 : 0)
            } else {
                sqlite3_bind_null(statement, paramIndex)
            }
            paramIndex += 1
            
            // id (WHERE clause)
            sqlite3_bind_int64(statement, paramIndex, hausAbrechnung.id)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                let changes = sqlite3_changes(db)
                print("UPDATE erfolgreich ausgeführt, \(changes) Zeile(n) betroffen")
                success = true
            } else {
                print("Fehler beim Aktualisieren: \(String(cString: sqlite3_errmsg(db)))")
            }
        } else {
            print("Fehler beim Vorbereiten: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
        
        if success {
            if commit() {
                print("Commit erfolgreich")
                return true
            } else {
                print("Fehler beim Commit")
                return false
            }
        }
        return false
    }
    
    func delete(id: Int64) -> Bool {
        print("Löschen: ID=\(id)")
        beginTransaction()
        
        let deleteSQL = "DELETE FROM HausAbrechnung WHERE id = ?;"
        var statement: OpaquePointer?
        var success = false
        
        if sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int64(statement, 1, id)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                let changes = sqlite3_changes(db)
                print("DELETE erfolgreich ausgeführt, \(changes) Zeile(n) betroffen")
                success = true
            } else {
                print("Fehler beim Löschen: \(String(cString: sqlite3_errmsg(db)))")
            }
        } else {
            print("Fehler beim Vorbereiten: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
        
        if success {
            if commit() {
                print("Commit erfolgreich")
                return true
            } else {
                print("Fehler beim Commit")
                return false
            }
        }
        return false
    }
    
    // MARK: - HausAbrechnung by ID
    
    func getHausAbrechnung(by id: Int64) -> HausAbrechnung? {
        let querySQL = """
            SELECT id, hausBezeichnung, abrechnungsJahr, postleitzahl, ort, gesamtflaeche,
                   anzahlWohnungen, leerstandspruefung, verwalterName, verwalterStrasse,
                   verwalterPLZOrt, verwalterEmail, verwalterTelefon, verwalterInEmailVorbelegen
            FROM HausAbrechnung WHERE id = ?;
        """
        var statement: OpaquePointer?
        var result: HausAbrechnung?
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int64(statement, 1, id)
            if sqlite3_step(statement) == SQLITE_ROW {
                result = parseHausAbrechnungRow(statement)
            }
        }
        sqlite3_finalize(statement)
        return result
    }
    
    private func parseHausAbrechnungRow(_ stmt: OpaquePointer?) -> HausAbrechnung? {
        guard let stmt else { return nil }
        let id = sqlite3_column_int64(stmt, 0)
        let hausBezeichnung = sqlite3_column_text(stmt, 1) != nil ? String(cString: sqlite3_column_text(stmt, 1)!) : ""
        let abrechnungsJahr = Int(sqlite3_column_int(stmt, 2))
        let postleitzahl = sqlite3_column_text(stmt, 3) != nil ? String(cString: sqlite3_column_text(stmt, 3)!) : nil
        let ort = sqlite3_column_text(stmt, 4) != nil ? String(cString: sqlite3_column_text(stmt, 4)!) : nil
        let gesamtflaeche = sqlite3_column_type(stmt, 5) != SQLITE_NULL ? Int(sqlite3_column_int(stmt, 5)) : nil
        let anzahlWohnungen = sqlite3_column_type(stmt, 6) != SQLITE_NULL ? Int(sqlite3_column_int(stmt, 6)) : nil
        let leerstandspruefungRaw = sqlite3_column_text(stmt, 7) != nil ? String(cString: sqlite3_column_text(stmt, 7)!) : nil
        let leerstandspruefung = leerstandspruefungRaw != nil ? Leerstandspruefung(rawValue: leerstandspruefungRaw!) : nil
        let verwalterName = sqlite3_column_text(stmt, 8) != nil ? String(cString: sqlite3_column_text(stmt, 8)!) : nil
        let verwalterStrasse = sqlite3_column_text(stmt, 9) != nil ? String(cString: sqlite3_column_text(stmt, 9)!) : nil
        let verwalterPLZOrt = sqlite3_column_text(stmt, 10) != nil ? String(cString: sqlite3_column_text(stmt, 10)!) : nil
        let verwalterEmail = sqlite3_column_text(stmt, 11) != nil ? String(cString: sqlite3_column_text(stmt, 11)!) : nil
        let verwalterTelefon = sqlite3_column_text(stmt, 12) != nil ? String(cString: sqlite3_column_text(stmt, 12)!) : nil
        let verwalterInEmailVorbelegen = sqlite3_column_type(stmt, 13) != SQLITE_NULL ? (sqlite3_column_int(stmt, 13) == 1) : nil
        return HausAbrechnung(id: id, hausBezeichnung: hausBezeichnung, abrechnungsJahr: abrechnungsJahr,
                             postleitzahl: postleitzahl, ort: ort, gesamtflaeche: gesamtflaeche, anzahlWohnungen: anzahlWohnungen,
                             leerstandspruefung: leerstandspruefung, verwalterName: verwalterName, verwalterStrasse: verwalterStrasse,
                             verwalterPLZOrt: verwalterPLZOrt, verwalterEmail: verwalterEmail, verwalterTelefon: verwalterTelefon,
                             verwalterInEmailVorbelegen: verwalterInEmailVorbelegen)
    }
    
    // MARK: - Wohnung
    
    private func rollback() -> Bool {
        if let db = db {
            let sql = "ROLLBACK;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                if sqlite3_step(stmt) == SQLITE_DONE {
                    sqlite3_finalize(stmt)
                    return true
                }
            }
            sqlite3_finalize(stmt)
        }
        return false
    }
    
    func insertWohnung(_ w: Wohnung) -> Int64? {
        beginTransaction()
        let sql = "INSERT INTO Wohnung (hausAbrechnungId, wohnungsnummer, bezeichnung, qm, name, strasse, plz, ort, email, telefon) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);"
        var stmt: OpaquePointer?
        var insertedId: Int64? = nil
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            var idx: Int32 = 1
            sqlite3_bind_int64(stmt, idx, w.hausAbrechnungId)
            idx += 1
            if let nummer = w.wohnungsnummer, !nummer.isEmpty {
                sqlite3_bind_text(stmt, idx, (nummer as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, idx)
            }
            idx += 1
            sqlite3_bind_text(stmt, idx, (w.bezeichnung as NSString).utf8String, -1, nil)
            idx += 1
            sqlite3_bind_int(stmt, idx, Int32(w.qm))
            idx += 1
            if let name = w.name, !name.isEmpty {
                sqlite3_bind_text(stmt, idx, (name as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, idx)
            }
            idx += 1
            if let strasse = w.strasse, !strasse.isEmpty {
                sqlite3_bind_text(stmt, idx, (strasse as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, idx)
            }
            idx += 1
            if let plz = w.plz, !plz.isEmpty {
                sqlite3_bind_text(stmt, idx, (plz as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, idx)
            }
            idx += 1
            if let ort = w.ort, !ort.isEmpty {
                sqlite3_bind_text(stmt, idx, (ort as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, idx)
            }
            idx += 1
            if let email = w.email, !email.isEmpty {
                sqlite3_bind_text(stmt, idx, (email as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, idx)
            }
            idx += 1
            if let telefon = w.telefon, !telefon.isEmpty {
                sqlite3_bind_text(stmt, idx, (telefon as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, idx)
            }
            if sqlite3_step(stmt) == SQLITE_DONE {
                insertedId = sqlite3_last_insert_rowid(db)
            }
        }
        sqlite3_finalize(stmt)
        if insertedId != nil { _ = commit() } else { _ = rollback() }
        return insertedId
    }
    
    func getWohnungen(byHausAbrechnungId hausId: Int64) -> [Wohnung] {
        let sql = "SELECT id, hausAbrechnungId, wohnungsnummer, bezeichnung, qm, name, strasse, plz, ort, email, telefon FROM Wohnung WHERE hausAbrechnungId = ? ORDER BY COALESCE(wohnungsnummer, ''), bezeichnung;"
        var stmt: OpaquePointer?
        var list: [Wohnung] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, hausId)
            while sqlite3_step(stmt) == SQLITE_ROW {
                list.append(Wohnung(
                    id: sqlite3_column_int64(stmt, 0),
                    hausAbrechnungId: sqlite3_column_int64(stmt, 1),
                    wohnungsnummer: sqlite3_column_text(stmt, 2).map { String(cString: $0) },
                    bezeichnung: sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? "",
                    qm: Int(sqlite3_column_int(stmt, 4)),
                    name: sqlite3_column_text(stmt, 5).map { String(cString: $0) },
                    strasse: sqlite3_column_text(stmt, 6).map { String(cString: $0) },
                    plz: sqlite3_column_text(stmt, 7).map { String(cString: $0) },
                    ort: sqlite3_column_text(stmt, 8).map { String(cString: $0) },
                    email: sqlite3_column_text(stmt, 9).map { String(cString: $0) },
                    telefon: sqlite3_column_text(stmt, 10).map { String(cString: $0) }
                ))
            }
        }
        sqlite3_finalize(stmt)
        return list
    }
    
    /// Findet eine Wohnung anhand der ID
    func getWohnung(byId id: Int64) -> Wohnung? {
        let sql = "SELECT id, hausAbrechnungId, wohnungsnummer, bezeichnung, qm, name, strasse, plz, ort, email, telefon FROM Wohnung WHERE id = ?;"
        var stmt: OpaquePointer?
        var result: Wohnung? = nil
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, id)
            if sqlite3_step(stmt) == SQLITE_ROW {
                result = Wohnung(
                    id: sqlite3_column_int64(stmt, 0),
                    hausAbrechnungId: sqlite3_column_int64(stmt, 1),
                    wohnungsnummer: sqlite3_column_text(stmt, 2).map { String(cString: $0) },
                    bezeichnung: sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? "",
                    qm: Int(sqlite3_column_int(stmt, 4)),
                    name: sqlite3_column_text(stmt, 5).map { String(cString: $0) },
                    strasse: sqlite3_column_text(stmt, 6).map { String(cString: $0) },
                    plz: sqlite3_column_text(stmt, 7).map { String(cString: $0) },
                    ort: sqlite3_column_text(stmt, 8).map { String(cString: $0) },
                    email: sqlite3_column_text(stmt, 9).map { String(cString: $0) },
                    telefon: sqlite3_column_text(stmt, 10).map { String(cString: $0) }
                )
            }
        }
        sqlite3_finalize(stmt)
        return result
    }
    
    /// Alle Wohnungs-IDs derselben logischen Wohnung (gleiches Haus, gleiche Wohnungsnummer) – für Überlappungsprüfung „alle Sätze der Wohnung“
    func getWohnungIdsFuerGleicheWohnung(wohnungId: Int64) -> [Int64] {
        guard let w = getWohnung(byId: wohnungId) else { return [wohnungId] }
        let nummer = w.wohnungsnummer ?? ""
        let sql = "SELECT id FROM Wohnung WHERE hausAbrechnungId = ? AND COALESCE(wohnungsnummer, '') = ? ORDER BY id;"
        var stmt: OpaquePointer?
        var ids: [Int64] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, w.hausAbrechnungId)
            sqlite3_bind_text(stmt, 2, (nummer as NSString).utf8String, -1, nil)
            while sqlite3_step(stmt) == SQLITE_ROW {
                ids.append(sqlite3_column_int64(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        return ids.isEmpty ? [wohnungId] : ids
    }
    
    /// Berechnet die Anzahl der eindeutigen Wohnungen für ein Haus
    /// Berücksichtigt nur die neueste Wohnung (höchste ID) pro Wohnungsnummer
    func getAnzahlWohnungen(byHausAbrechnungId hausId: Int64) -> Int {
        // SQL-Query: Zähle die Anzahl der eindeutigen Wohnungsnummern (nur neueste pro Nummer)
        let sql = """
            SELECT COUNT(DISTINCT COALESCE(wohnungsnummer, ''))
            FROM Wohnung w1
            WHERE w1.hausAbrechnungId = ?
            AND w1.id = (
                SELECT MAX(w2.id)
                FROM Wohnung w2
                WHERE w2.hausAbrechnungId = w1.hausAbrechnungId
                AND COALESCE(w2.wohnungsnummer, '') = COALESCE(w1.wohnungsnummer, '')
            );
        """
        var stmt: OpaquePointer?
        var anzahl: Int = 0
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, hausId)
            if sqlite3_step(stmt) == SQLITE_ROW {
                anzahl = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        return anzahl
    }
    
    /// Berechnet die Summe der QM aller Wohnungen für ein Haus
    /// Berücksichtigt nur die neueste Wohnung (höchste ID) pro Wohnungsnummer
    func getSummeQmWohnungen(byHausAbrechnungId hausId: Int64) -> Int {
        // SQL-Query: Für jede Wohnungsnummer nur die Wohnung mit der höchsten ID nehmen
        // Verwende eine Subquery mit MAX(id) für Kompatibilität mit allen SQLite-Versionen
        let sql = """
            SELECT SUM(qm) 
            FROM Wohnung w1
            WHERE w1.hausAbrechnungId = ?
            AND w1.id = (
                SELECT MAX(w2.id)
                FROM Wohnung w2
                WHERE w2.hausAbrechnungId = w1.hausAbrechnungId
                AND COALESCE(w2.wohnungsnummer, '') = COALESCE(w1.wohnungsnummer, '')
            );
        """
        var stmt: OpaquePointer?
        var summe: Int = 0
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, hausId)
            if sqlite3_step(stmt) == SQLITE_ROW {
                if sqlite3_column_type(stmt, 0) != SQLITE_NULL {
                    summe = Int(sqlite3_column_int(stmt, 0))
                }
            }
        }
        sqlite3_finalize(stmt)
        return summe
    }
    
    /// Prüft, ob die Summe der QM der Wohnungen mit der Gesamtfläche des Hauses übereinstimmt
    func pruefeQmUebereinstimmung(hausId: Int64) -> (uebereinstimmt: Bool, gesamtflaeche: Int?, summeWohnungen: Int) {
        guard let haus = getHausAbrechnung(by: hausId) else {
            return (false, nil, 0)
        }
        let summeWohnungen = getSummeQmWohnungen(byHausAbrechnungId: hausId)
        if let gesamtflaeche = haus.gesamtflaeche {
            return (gesamtflaeche == summeWohnungen, gesamtflaeche, summeWohnungen)
        }
        // Wenn keine Gesamtfläche angegeben ist, gilt es als übereinstimmend
        return (true, nil, summeWohnungen)
    }
    
    /// Prüft beide Validierungen in der richtigen Reihenfolge:
    /// 1. Anzahl der Wohnungen gegen anzahlWohnungen im Haus
    /// 2. Gesamt-QM der Wohnungen gegen gesamtflaeche im Haus
    /// Gibt ein Tupel zurück mit (erfolgreich: Bool, fehlermeldung: String?, erfolgsmeldung: String?)
    func pruefeWohnungenValidierung(hausId: Int64) -> (erfolgreich: Bool, fehlermeldung: String?, erfolgsmeldung: String?) {
        guard let haus = getHausAbrechnung(by: hausId) else {
            return (false, "Haus nicht gefunden.", nil)
        }
        
        var gepruefteFelder: [String] = []
        var erfolgsDetails: [String] = []
        
        // Prüfung 1: Anzahl der Wohnungen
        if let erwarteteAnzahl = haus.anzahlWohnungen {
            let tatsaechlicheAnzahl = getAnzahlWohnungen(byHausAbrechnungId: hausId)
            gepruefteFelder.append("Anzahl Wohnungen")
            if erwarteteAnzahl != tatsaechlicheAnzahl {
                return (false, "Die Anzahl der Wohnungen stimmt nicht überein.\n\nErwartet: \(erwarteteAnzahl)\nTatsächlich: \(tatsaechlicheAnzahl)", nil)
            }
            erfolgsDetails.append("✓ Anzahl Wohnungen: \(erwarteteAnzahl)")
        }
        
        // Prüfung 2: Gesamt-QM
        if let erwarteteFlaeche = haus.gesamtflaeche {
            let tatsaechlicheFlaeche = getSummeQmWohnungen(byHausAbrechnungId: hausId)
            gepruefteFelder.append("Gesamtfläche")
            if erwarteteFlaeche != tatsaechlicheFlaeche {
                return (false, "Die Gesamtfläche stimmt nicht überein.\n\nErwartet: \(erwarteteFlaeche) qm\nTatsächlich: \(tatsaechlicheFlaeche) qm", nil)
            }
            erfolgsDetails.append("✓ Gesamtfläche: \(erwarteteFlaeche) qm")
        }
        
        // Wenn keine Felder zum Prüfen vorhanden sind, keine Meldung
        if gepruefteFelder.isEmpty {
            return (true, nil, nil)
        }
        
        // Alle Prüfungen erfolgreich - Erfolgsmeldung generieren
        let erfolgsmeldung = "Alle Prüfungen erfolgreich:\n\n" + erfolgsDetails.joined(separator: "\n")
        
        return (true, nil, erfolgsmeldung)
    }
    
    /// Prüft, ob eine neue Wohnung mit der angegebenen Nummer angelegt werden darf.
    /// Sofortige Ablehnung, wenn bereits eine Wohnung mit dieser Nummer existiert und deren Mietzeitende (letzter Mietzeitraum) am oder nach dem 31.12. des Abrechnungsjahres liegt.
    func canCreateWohnungWithNummer(wohnungsnummer: String, hausAbrechnungId: Int64, abrechnungsJahr: Int) -> (allowed: Bool, message: String?) {
        let trimmed = wohnungsnummer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (true, nil) }
        guard getWohnung(byWohnungsnummer: trimmed, hausAbrechnungId: hausAbrechnungId) != nil else { return (true, nil) }
        guard let letzter = getLetzterMietzeitraum(byWohnungsnummer: trimmed, hausAbrechnungId: hausAbrechnungId) else { return (true, nil) }
        let jahrEnde = "\(abrechnungsJahr)-12-31"
        if letzter.bisDatum >= jahrEnde {
            return (false, "Es existiert bereits eine Wohnung mit der Nummer „\(trimmed)“.\n\nDeren Mietzeitende (\(letzter.bisDatum)) liegt am oder nach dem 31.12.\(abrechnungsJahr). Anlage nicht möglich.\n\nBitte beim bestehenden Mietzeitraum das Mietende (Auszugsdatum) anpassen, damit eine weitere Wohnung mit dieser Nummer angelegt werden kann.")
        }
        return (true, nil)
    }
    
    /// Findet eine Wohnung anhand der Wohnungsnummer und HausAbrechnungId
    func getWohnung(byWohnungsnummer nummer: String, hausAbrechnungId: Int64) -> Wohnung? {
        guard !nummer.isEmpty else { return nil }
        let sql = "SELECT id, hausAbrechnungId, wohnungsnummer, bezeichnung, qm, name, strasse, plz, ort, email, telefon FROM Wohnung WHERE hausAbrechnungId = ? AND wohnungsnummer = ? LIMIT 1;"
        var stmt: OpaquePointer?
        var result: Wohnung? = nil
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, hausAbrechnungId)
            sqlite3_bind_text(stmt, 2, (nummer as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW {
                result = Wohnung(
                    id: sqlite3_column_int64(stmt, 0),
                    hausAbrechnungId: sqlite3_column_int64(stmt, 1),
                    wohnungsnummer: sqlite3_column_text(stmt, 2).map { String(cString: $0) },
                    bezeichnung: sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? "",
                    qm: Int(sqlite3_column_int(stmt, 4)),
                    name: sqlite3_column_text(stmt, 5).map { String(cString: $0) },
                    strasse: sqlite3_column_text(stmt, 6).map { String(cString: $0) },
                    plz: sqlite3_column_text(stmt, 7).map { String(cString: $0) },
                    ort: sqlite3_column_text(stmt, 8).map { String(cString: $0) },
                    email: sqlite3_column_text(stmt, 9).map { String(cString: $0) },
                    telefon: sqlite3_column_text(stmt, 10).map { String(cString: $0) }
                )
            }
        }
        sqlite3_finalize(stmt)
        return result
    }
    
    /// Findet die neueste Wohnung (Vormieter) mit einer bestimmten Wohnungsnummer, außer der angegebenen ID
    func getVormieterWohnung(wohnungsnummer: String, hausAbrechnungId: Int64, ausschliessenId: Int64) -> Wohnung? {
        guard !wohnungsnummer.isEmpty else { return nil }
        let sql = "SELECT id, hausAbrechnungId, wohnungsnummer, bezeichnung, qm, name, strasse, plz, ort, email, telefon FROM Wohnung WHERE hausAbrechnungId = ? AND wohnungsnummer = ? AND id != ? ORDER BY id DESC LIMIT 1;"
        var stmt: OpaquePointer?
        var result: Wohnung? = nil
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, hausAbrechnungId)
            sqlite3_bind_text(stmt, 2, (wohnungsnummer as NSString).utf8String, -1, nil)
            sqlite3_bind_int64(stmt, 3, ausschliessenId)
            if sqlite3_step(stmt) == SQLITE_ROW {
                result = Wohnung(
                    id: sqlite3_column_int64(stmt, 0),
                    hausAbrechnungId: sqlite3_column_int64(stmt, 1),
                    wohnungsnummer: sqlite3_column_text(stmt, 2).map { String(cString: $0) },
                    bezeichnung: sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? "",
                    qm: Int(sqlite3_column_int(stmt, 4)),
                    name: sqlite3_column_text(stmt, 5).map { String(cString: $0) },
                    strasse: sqlite3_column_text(stmt, 6).map { String(cString: $0) },
                    plz: sqlite3_column_text(stmt, 7).map { String(cString: $0) },
                    ort: sqlite3_column_text(stmt, 8).map { String(cString: $0) },
                    email: sqlite3_column_text(stmt, 9).map { String(cString: $0) },
                    telefon: sqlite3_column_text(stmt, 10).map { String(cString: $0) }
                )
            }
        }
        sqlite3_finalize(stmt)
        return result
    }
    
    func updateWohnung(_ w: Wohnung) -> Bool {
        beginTransaction()
        let sql = "UPDATE Wohnung SET wohnungsnummer = ?, bezeichnung = ?, qm = ?, name = ?, strasse = ?, plz = ?, ort = ?, email = ?, telefon = ? WHERE id = ?;"
        var stmt: OpaquePointer?
        var ok = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            var idx: Int32 = 1
            if let nummer = w.wohnungsnummer, !nummer.isEmpty {
                sqlite3_bind_text(stmt, idx, (nummer as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, idx)
            }
            idx += 1
            sqlite3_bind_text(stmt, idx, (w.bezeichnung as NSString).utf8String, -1, nil)
            idx += 1
            sqlite3_bind_int(stmt, idx, Int32(w.qm))
            idx += 1
            if let name = w.name, !name.isEmpty {
                sqlite3_bind_text(stmt, idx, (name as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, idx)
            }
            idx += 1
            if let strasse = w.strasse, !strasse.isEmpty {
                sqlite3_bind_text(stmt, idx, (strasse as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, idx)
            }
            idx += 1
            if let plz = w.plz, !plz.isEmpty {
                sqlite3_bind_text(stmt, idx, (plz as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, idx)
            }
            idx += 1
            if let ort = w.ort, !ort.isEmpty {
                sqlite3_bind_text(stmt, idx, (ort as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, idx)
            }
            idx += 1
            if let email = w.email, !email.isEmpty {
                sqlite3_bind_text(stmt, idx, (email as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, idx)
            }
            idx += 1
            if let telefon = w.telefon, !telefon.isEmpty {
                sqlite3_bind_text(stmt, idx, (telefon as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, idx)
            }
            idx += 1
            sqlite3_bind_int64(stmt, idx, w.id)
            if sqlite3_step(stmt) == SQLITE_DONE { ok = true }
        }
        sqlite3_finalize(stmt)
        if ok { _ = commit() }
        return ok
    }
    
    func deleteWohnung(id: Int64) -> Bool {
        beginTransaction()
        let sql = "DELETE FROM Wohnung WHERE id = ?;"
        var stmt: OpaquePointer?
        var ok = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, id)
            if sqlite3_step(stmt) == SQLITE_DONE {
                let changes = sqlite3_changes(db)
                print("DELETE Wohnung erfolgreich ausgeführt, \(changes) Zeile(n) betroffen, ID: \(id)")
                ok = true
            } else {
                print("Fehler beim Löschen der Wohnung: \(String(cString: sqlite3_errmsg(db)))")
            }
        } else {
            print("Fehler beim Vorbereiten des DELETE: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(stmt)
        if ok {
            if commit() {
                print("Commit erfolgreich für DELETE Wohnung")
                return true
            } else {
                print("Fehler beim Commit für DELETE Wohnung")
                return false
            }
        } else {
            _ = rollback()
            print("Rollback durchgeführt für DELETE Wohnung")
            return false
        }
    }
    
    // MARK: - Mietzeitraum
    
    private static func mietendeOptionFromDB(_ raw: String?) -> MietendeOption {
        guard let raw = raw, !raw.isEmpty, let opt = MietendeOption(rawValue: raw) else { return .mietendeOffen }
        return opt
    }
    
    func insertMietzeitraum(_ m: Mietzeitraum) -> Bool {
        // Anschlussmieter nur nach Auszug: keine überlappenden Zeiträume in derselben Wohnung
        if getUeberlappendenMietzeitraum(wohnungId: m.wohnungId, vonDatum: m.vonDatum, bisDatum: m.bisDatum, ausschliessenId: nil) != nil {
            return false
        }
        beginTransaction()
        let sql = "INSERT INTO Mietzeitraum (wohnungId, jahr, hauptmieterName, vonDatum, bisDatum, anzahlPersonen, mietendeOption) VALUES (?, ?, ?, ?, ?, ?, ?);"
        var stmt: OpaquePointer?
        var ok = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, m.wohnungId)
            sqlite3_bind_int(stmt, 2, Int32(m.jahr))
            sqlite3_bind_text(stmt, 3, (m.hauptmieterName as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 4, (m.vonDatum as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 5, (m.bisDatum as NSString).utf8String, -1, nil)
            sqlite3_bind_int(stmt, 6, Int32(m.anzahlPersonen))
            sqlite3_bind_text(stmt, 7, (m.mietendeOption.rawValue as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_DONE { ok = true }
        }
        sqlite3_finalize(stmt)
        if ok { _ = commit() }
        return ok
    }
    
    func getMietzeitraeume(byWohnungId wohnungId: Int64) -> [Mietzeitraum] {
        let sql = "SELECT id, wohnungId, jahr, hauptmieterName, vonDatum, bisDatum, anzahlPersonen, mietendeOption FROM Mietzeitraum WHERE wohnungId = ? ORDER BY vonDatum;"
        var stmt: OpaquePointer?
        var list: [Mietzeitraum] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, wohnungId)
            while sqlite3_step(stmt) == SQLITE_ROW {
                list.append(Mietzeitraum(
                    id: sqlite3_column_int64(stmt, 0),
                    wohnungId: sqlite3_column_int64(stmt, 1),
                    jahr: Int(sqlite3_column_int(stmt, 2)),
                    hauptmieterName: sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? "",
                    vonDatum: sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? "",
                    bisDatum: sqlite3_column_text(stmt, 5).map { String(cString: $0) } ?? "",
                    anzahlPersonen: sqlite3_column_type(stmt, 6) == SQLITE_NULL ? 1 : Int(sqlite3_column_int(stmt, 6)),
                    mietendeOption: Self.mietendeOptionFromDB(sqlite3_column_text(stmt, 7).map { String(cString: $0) })
                ))
            }
        }
        sqlite3_finalize(stmt)
        return list
    }
    
    func updateMietzeitraum(_ m: Mietzeitraum) -> Bool {
        // Anschlussmieter nur nach Auszug: keine überlappenden Zeiträume (aktuellen Satz ausnehmen)
        if getUeberlappendenMietzeitraum(wohnungId: m.wohnungId, vonDatum: m.vonDatum, bisDatum: m.bisDatum, ausschliessenId: m.id) != nil {
            return false
        }
        beginTransaction()
        let sql = "UPDATE Mietzeitraum SET jahr = ?, hauptmieterName = ?, vonDatum = ?, bisDatum = ?, anzahlPersonen = ?, mietendeOption = ? WHERE id = ?;"
        var stmt: OpaquePointer?
        var ok = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(m.jahr))
            sqlite3_bind_text(stmt, 2, (m.hauptmieterName as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 3, (m.vonDatum as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 4, (m.bisDatum as NSString).utf8String, -1, nil)
            sqlite3_bind_int(stmt, 5, Int32(m.anzahlPersonen))
            sqlite3_bind_text(stmt, 6, (m.mietendeOption.rawValue as NSString).utf8String, -1, nil)
            sqlite3_bind_int64(stmt, 7, m.id)
            if sqlite3_step(stmt) == SQLITE_DONE { ok = true }
        }
        sqlite3_finalize(stmt)
        if ok { _ = commit() }
        return ok
    }
    
    func deleteMietzeitraum(id: Int64) -> Bool {
        beginTransaction()
        let sql = "DELETE FROM Mietzeitraum WHERE id = ?;"
        var stmt: OpaquePointer?
        var ok = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, id)
            if sqlite3_step(stmt) == SQLITE_DONE { ok = true }
        }
        sqlite3_finalize(stmt)
        if ok { _ = commit() }
        return ok
    }
    
    /// Prüft, ob am neuen Einzugsdatum bereits ein anderer Mietzeitraum die Wohnung belegt (vonDatum <= Datum <= bisDatum).
    /// Einzug des 2. Mieters muss strikt nach dem Auszug des 1. liegen (gleicher Tag z. B. 31.12.–31.12. ist Konflikt).
    /// Bezieht sich auf alle Sätze der Wohnung (gleiches Haus, gleiche Wohnungsnummer).
    /// Gibt den Mietzeitraum zurück, wenn ein Konflikt besteht, sonst nil.
    func getConflictingMietzeitraum(wohnungId: Int64, neuesVonDatum: String, ausschliessenId: Int64? = nil) -> Mietzeitraum? {
        let wohnungIds = getWohnungIdsFuerGleicheWohnung(wohnungId: wohnungId)
        let inPlaceholders = wohnungIds.map { _ in "?" }.joined(separator: ",")
        let sql = "SELECT id, wohnungId, jahr, hauptmieterName, vonDatum, bisDatum, anzahlPersonen, mietendeOption FROM Mietzeitraum WHERE wohnungId IN (\(inPlaceholders)) AND vonDatum <= ? AND bisDatum >= ?"
        var stmt: OpaquePointer?
        var result: Mietzeitraum? = nil
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            for (i, wid) in wohnungIds.enumerated() {
                sqlite3_bind_int64(stmt, Int32(i + 1), wid)
            }
            sqlite3_bind_text(stmt, Int32(wohnungIds.count + 1), (neuesVonDatum as NSString).utf8String, -1, nil)  // vonDatum <= neuesVonDatum
            sqlite3_bind_text(stmt, Int32(wohnungIds.count + 2), (neuesVonDatum as NSString).utf8String, -1, nil)  // bisDatum >= neuesVonDatum
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = sqlite3_column_int64(stmt, 0)
                // Beim Update den aktuellen Datensatz ausschließen
                if let ausschliessen = ausschliessenId, id == ausschliessen {
                    continue
                }
                result = Mietzeitraum(
                    id: id,
                    wohnungId: sqlite3_column_int64(stmt, 1),
                    jahr: Int(sqlite3_column_int(stmt, 2)),
                    hauptmieterName: sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? "",
                    vonDatum: sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? "",
                    bisDatum: sqlite3_column_text(stmt, 5).map { String(cString: $0) } ?? "",
                    anzahlPersonen: sqlite3_column_type(stmt, 6) == SQLITE_NULL ? 1 : Int(sqlite3_column_int(stmt, 6)),
                    mietendeOption: Self.mietendeOptionFromDB(sqlite3_column_text(stmt, 7).map { String(cString: $0) })
                )
                break
            }
        }
        sqlite3_finalize(stmt)
        return result
    }
    
    /// Gibt den Mietzeitraum zurück, der direkt vor dem angegebenen Datum endet (für Anschlussprüfung). Bezieht sich auf alle Sätze der Wohnung.
    func getVorherigenMietzeitraum(wohnungId: Int64, vorDatum: String, ausschliessenId: Int64? = nil) -> Mietzeitraum? {
        let wohnungIds = getWohnungIdsFuerGleicheWohnung(wohnungId: wohnungId)
        let inPlaceholders = wohnungIds.map { _ in "?" }.joined(separator: ",")
        let sql = "SELECT id, wohnungId, jahr, hauptmieterName, vonDatum, bisDatum, anzahlPersonen, mietendeOption FROM Mietzeitraum WHERE wohnungId IN (\(inPlaceholders)) AND bisDatum < ? ORDER BY bisDatum DESC LIMIT 1;"
        var stmt: OpaquePointer?
        var result: Mietzeitraum? = nil
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            for (i, wid) in wohnungIds.enumerated() {
                sqlite3_bind_int64(stmt, Int32(i + 1), wid)
            }
            sqlite3_bind_text(stmt, Int32(wohnungIds.count + 1), (vorDatum as NSString).utf8String, -1, nil)
            
            if sqlite3_step(stmt) == SQLITE_ROW {
                let id = sqlite3_column_int64(stmt, 0)
                // Beim Update den aktuellen Datensatz ausschließen
                if let ausschliessen = ausschliessenId, id == ausschliessen {
                    sqlite3_finalize(stmt)
                    return nil
                }
                result = Mietzeitraum(
                    id: id,
                    wohnungId: sqlite3_column_int64(stmt, 1),
                    jahr: Int(sqlite3_column_int(stmt, 2)),
                    hauptmieterName: sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? "",
                    vonDatum: sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? "",
                    bisDatum: sqlite3_column_text(stmt, 5).map { String(cString: $0) } ?? "",
                    anzahlPersonen: sqlite3_column_type(stmt, 6) == SQLITE_NULL ? 1 : Int(sqlite3_column_int(stmt, 6)),
                    mietendeOption: Self.mietendeOptionFromDB(sqlite3_column_text(stmt, 7).map { String(cString: $0) })
                )
            }
        }
        sqlite3_finalize(stmt)
        return result
    }
    
    /// Gibt den Mietzeitraum zurück, der direkt nach dem angegebenen Datum beginnt (für Anschlussprüfung). Bezieht sich auf alle Sätze der Wohnung.
    func getNaechstenMietzeitraum(wohnungId: Int64, nachDatum: String, ausschliessenId: Int64? = nil) -> Mietzeitraum? {
        let wohnungIds = getWohnungIdsFuerGleicheWohnung(wohnungId: wohnungId)
        let inPlaceholders = wohnungIds.map { _ in "?" }.joined(separator: ",")
        let sql = "SELECT id, wohnungId, jahr, hauptmieterName, vonDatum, bisDatum, anzahlPersonen, mietendeOption FROM Mietzeitraum WHERE wohnungId IN (\(inPlaceholders)) AND vonDatum > ? ORDER BY vonDatum ASC LIMIT 1;"
        var stmt: OpaquePointer?
        var result: Mietzeitraum? = nil
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            for (i, wid) in wohnungIds.enumerated() {
                sqlite3_bind_int64(stmt, Int32(i + 1), wid)
            }
            sqlite3_bind_text(stmt, Int32(wohnungIds.count + 1), (nachDatum as NSString).utf8String, -1, nil)
            
            if sqlite3_step(stmt) == SQLITE_ROW {
                let id = sqlite3_column_int64(stmt, 0)
                // Beim Update den aktuellen Datensatz ausschließen
                if let ausschliessen = ausschliessenId, id == ausschliessen {
                    sqlite3_finalize(stmt)
                    return nil
                }
                result = Mietzeitraum(
                    id: id,
                    wohnungId: sqlite3_column_int64(stmt, 1),
                    jahr: Int(sqlite3_column_int(stmt, 2)),
                    hauptmieterName: sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? "",
                    vonDatum: sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? "",
                    bisDatum: sqlite3_column_text(stmt, 5).map { String(cString: $0) } ?? "",
                    anzahlPersonen: sqlite3_column_type(stmt, 6) == SQLITE_NULL ? 1 : Int(sqlite3_column_int(stmt, 6)),
                    mietendeOption: Self.mietendeOptionFromDB(sqlite3_column_text(stmt, 7).map { String(cString: $0) })
                )
            }
        }
        sqlite3_finalize(stmt)
        return result
    }
    
    /// Gibt den letzten Mietzeitraum für eine Wohnung zurück (mit dem spätesten Auszugsdatum)
    func getLetzterMietzeitraum(wohnungId: Int64) -> Mietzeitraum? {
        let sql = "SELECT id, wohnungId, jahr, hauptmieterName, vonDatum, bisDatum, anzahlPersonen, mietendeOption FROM Mietzeitraum WHERE wohnungId = ? ORDER BY bisDatum DESC LIMIT 1;"
        var stmt: OpaquePointer?
        var result: Mietzeitraum? = nil
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, wohnungId)
            
            if sqlite3_step(stmt) == SQLITE_ROW {
                result = Mietzeitraum(
                    id: sqlite3_column_int64(stmt, 0),
                    wohnungId: sqlite3_column_int64(stmt, 1),
                    jahr: Int(sqlite3_column_int(stmt, 2)),
                    hauptmieterName: sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? "",
                    vonDatum: sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? "",
                    bisDatum: sqlite3_column_text(stmt, 5).map { String(cString: $0) } ?? "",
                    anzahlPersonen: sqlite3_column_type(stmt, 6) == SQLITE_NULL ? 1 : Int(sqlite3_column_int(stmt, 6)),
                    mietendeOption: Self.mietendeOptionFromDB(sqlite3_column_text(stmt, 7).map { String(cString: $0) })
                )
            }
        }
        sqlite3_finalize(stmt)
        return result
    }
    
    /// Findet den letzten Mietzeitraum einer Wohnung anhand der Wohnungsnummer und HausAbrechnungId
    func getLetzterMietzeitraum(byWohnungsnummer nummer: String, hausAbrechnungId: Int64) -> Mietzeitraum? {
        guard !nummer.isEmpty else { return nil }
        let sql = """
            SELECT m.id, m.wohnungId, m.jahr, m.hauptmieterName, m.vonDatum, m.bisDatum, m.anzahlPersonen, m.mietendeOption 
            FROM Mietzeitraum m 
            INNER JOIN Wohnung w ON m.wohnungId = w.id 
            WHERE w.hausAbrechnungId = ? AND w.wohnungsnummer = ? 
            ORDER BY m.bisDatum DESC 
            LIMIT 1;
        """
        var stmt: OpaquePointer?
        var result: Mietzeitraum? = nil
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, hausAbrechnungId)
            sqlite3_bind_text(stmt, 2, (nummer as NSString).utf8String, -1, nil)
            
            if sqlite3_step(stmt) == SQLITE_ROW {
                result = Mietzeitraum(
                    id: sqlite3_column_int64(stmt, 0),
                    wohnungId: sqlite3_column_int64(stmt, 1),
                    jahr: Int(sqlite3_column_int(stmt, 2)),
                    hauptmieterName: sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? "",
                    vonDatum: sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? "",
                    bisDatum: sqlite3_column_text(stmt, 5).map { String(cString: $0) } ?? "",
                    anzahlPersonen: sqlite3_column_type(stmt, 6) == SQLITE_NULL ? 1 : Int(sqlite3_column_int(stmt, 6)),
                    mietendeOption: Self.mietendeOptionFromDB(sqlite3_column_text(stmt, 7).map { String(cString: $0) })
                )
            }
        }
        sqlite3_finalize(stmt)
        return result
    }
    
    /// Prüft, ob ein Mietzeitraum mit einem anderen überlappt (außer dem ausgeschlossenen). Bezieht sich auf alle Sätze der Wohnung.
    func getUeberlappendenMietzeitraum(wohnungId: Int64, vonDatum: String, bisDatum: String, ausschliessenId: Int64? = nil) -> Mietzeitraum? {
        let wohnungIds = getWohnungIdsFuerGleicheWohnung(wohnungId: wohnungId)
        let inPlaceholders = wohnungIds.map { _ in "?" }.joined(separator: ",")
        // Überlappung: vonDatum1 <= bisDatum2 AND bisDatum1 >= vonDatum2
        let sql = "SELECT id, wohnungId, jahr, hauptmieterName, vonDatum, bisDatum, anzahlPersonen, mietendeOption FROM Mietzeitraum WHERE wohnungId IN (\(inPlaceholders)) AND vonDatum <= ? AND bisDatum >= ?"
        var stmt: OpaquePointer?
        var result: Mietzeitraum? = nil
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            for (i, wid) in wohnungIds.enumerated() {
                sqlite3_bind_int64(stmt, Int32(i + 1), wid)
            }
            sqlite3_bind_text(stmt, Int32(wohnungIds.count + 1), (bisDatum as NSString).utf8String, -1, nil)  // vonDatum (bestehend) <= bisDatum (neu)
            sqlite3_bind_text(stmt, Int32(wohnungIds.count + 2), (vonDatum as NSString).utf8String, -1, nil)  // bisDatum (bestehend) >= vonDatum (neu)
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = sqlite3_column_int64(stmt, 0)
                // Beim Update den aktuellen Datensatz ausschließen
                if let ausschliessen = ausschliessenId, id == ausschliessen {
                    continue
                }
                result = Mietzeitraum(
                    id: id,
                    wohnungId: sqlite3_column_int64(stmt, 1),
                    jahr: Int(sqlite3_column_int(stmt, 2)),
                    hauptmieterName: sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? "",
                    vonDatum: sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? "",
                    bisDatum: sqlite3_column_text(stmt, 5).map { String(cString: $0) } ?? "",
                    anzahlPersonen: sqlite3_column_type(stmt, 6) == SQLITE_NULL ? 1 : Int(sqlite3_column_int(stmt, 6)),
                    mietendeOption: Self.mietendeOptionFromDB(sqlite3_column_text(stmt, 7).map { String(cString: $0) })
                )
                break
            }
        }
        sqlite3_finalize(stmt)
        return result
    }
    
    // MARK: - Mitmieter
    
    func insertMitmieter(_ m: Mitmieter) -> Bool {
        beginTransaction()
        let sql = "INSERT INTO Mitmieter (mietzeitraumId, name, vonDatum, bisDatum) VALUES (?, ?, ?, ?);"
        var stmt: OpaquePointer?
        var ok = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, m.mietzeitraumId)
            sqlite3_bind_text(stmt, 2, (m.name as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 3, (m.vonDatum as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 4, (m.bisDatum as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_DONE { ok = true }
        }
        sqlite3_finalize(stmt)
        if ok { _ = commit() }
        return ok
    }
    
    func getMitmieter(byMietzeitraumId mietzeitraumId: Int64) -> [Mitmieter] {
        let sql = "SELECT id, mietzeitraumId, name, vonDatum, bisDatum FROM Mitmieter WHERE mietzeitraumId = ? ORDER BY vonDatum;"
        var stmt: OpaquePointer?
        var list: [Mitmieter] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, mietzeitraumId)
            while sqlite3_step(stmt) == SQLITE_ROW {
                list.append(Mitmieter(
                    id: sqlite3_column_int64(stmt, 0),
                    mietzeitraumId: sqlite3_column_int64(stmt, 1),
                    name: sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? "",
                    vonDatum: sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? "",
                    bisDatum: sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? ""
                ))
            }
        }
        sqlite3_finalize(stmt)
        return list
    }
    
    func updateMitmieter(_ m: Mitmieter) -> Bool {
        beginTransaction()
        let sql = "UPDATE Mitmieter SET name = ?, vonDatum = ?, bisDatum = ? WHERE id = ?;"
        var stmt: OpaquePointer?
        var ok = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (m.name as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (m.vonDatum as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 3, (m.bisDatum as NSString).utf8String, -1, nil)
            sqlite3_bind_int64(stmt, 4, m.id)
            if sqlite3_step(stmt) == SQLITE_DONE { ok = true }
        }
        sqlite3_finalize(stmt)
        if ok { _ = commit() }
        return ok
    }
    
    func deleteMitmieter(id: Int64) -> Bool {
        beginTransaction()
        let sql = "DELETE FROM Mitmieter WHERE id = ?;"
        var stmt: OpaquePointer?
        var ok = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, id)
            if sqlite3_step(stmt) == SQLITE_DONE { ok = true }
        }
        sqlite3_finalize(stmt)
        if ok { _ = commit() }
        return ok
    }
    
    // MARK: - Zählerstand
    
    func insertZaehlerstand(_ z: Zaehlerstand) -> Bool {
        beginTransaction()
        let sql = "INSERT INTO Zaehlerstand (wohnungId, zaehlerTyp, zaehlerNummer, zaehlerStart, zaehlerEnde, differenz, auchAbwasser, beschreibung) VALUES (?, ?, ?, ?, ?, ?, ?, ?);"
        var stmt: OpaquePointer?
        var ok = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, z.wohnungId)
            sqlite3_bind_text(stmt, 2, (z.zaehlerTyp as NSString).utf8String, -1, nil)
            if let nummer = z.zaehlerNummer, !nummer.isEmpty {
                sqlite3_bind_text(stmt, 3, (nummer as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 3)
            }
            sqlite3_bind_double(stmt, 4, z.zaehlerStart)
            sqlite3_bind_double(stmt, 5, z.zaehlerEnde)
            sqlite3_bind_double(stmt, 6, z.differenz)
            if let auchAbwasser = z.auchAbwasser {
                sqlite3_bind_int(stmt, 7, auchAbwasser ? 1 : 0)
            } else {
                sqlite3_bind_null(stmt, 7)
            }
            if let beschreibung = z.beschreibung, !beschreibung.isEmpty {
                sqlite3_bind_text(stmt, 8, (beschreibung as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 8)
            }
            if sqlite3_step(stmt) == SQLITE_DONE { ok = true }
        }
        sqlite3_finalize(stmt)
        if ok { _ = commit() }
        return ok
    }
    
    func getZaehlerstaende(byWohnungId wohnungId: Int64) -> [Zaehlerstand] {
        let sql = "SELECT id, wohnungId, zaehlerTyp, zaehlerNummer, zaehlerStart, zaehlerEnde, differenz, auchAbwasser, beschreibung FROM Zaehlerstand WHERE wohnungId = ? ORDER BY zaehlerTyp, zaehlerNummer;"
        var stmt: OpaquePointer?
        var list: [Zaehlerstand] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, wohnungId)
            while sqlite3_step(stmt) == SQLITE_ROW {
                list.append(Zaehlerstand(
                    id: sqlite3_column_int64(stmt, 0),
                    wohnungId: sqlite3_column_int64(stmt, 1),
                    zaehlerTyp: sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? "",
                    zaehlerNummer: sqlite3_column_text(stmt, 3).map { String(cString: $0) },
                    zaehlerStart: sqlite3_column_double(stmt, 4),
                    zaehlerEnde: sqlite3_column_double(stmt, 5),
                    auchAbwasser: sqlite3_column_type(stmt, 7) == SQLITE_NULL ? nil : (sqlite3_column_int(stmt, 7) == 1),
                    beschreibung: sqlite3_column_text(stmt, 8).map { String(cString: $0) }
                ))
            }
        }
        sqlite3_finalize(stmt)
        return list
    }
    
    func updateZaehlerstand(_ z: Zaehlerstand) -> Bool {
        beginTransaction()
        let sql = "UPDATE Zaehlerstand SET zaehlerTyp = ?, zaehlerNummer = ?, zaehlerStart = ?, zaehlerEnde = ?, differenz = ?, auchAbwasser = ?, beschreibung = ? WHERE id = ?;"
        var stmt: OpaquePointer?
        var ok = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (z.zaehlerTyp as NSString).utf8String, -1, nil)
            if let nummer = z.zaehlerNummer, !nummer.isEmpty {
                sqlite3_bind_text(stmt, 2, (nummer as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 2)
            }
            sqlite3_bind_double(stmt, 3, z.zaehlerStart)
            sqlite3_bind_double(stmt, 4, z.zaehlerEnde)
            sqlite3_bind_double(stmt, 5, z.differenz)
            if let auchAbwasser = z.auchAbwasser {
                sqlite3_bind_int(stmt, 6, auchAbwasser ? 1 : 0)
            } else {
                sqlite3_bind_null(stmt, 6)
            }
            if let beschreibung = z.beschreibung, !beschreibung.isEmpty {
                sqlite3_bind_text(stmt, 7, (beschreibung as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 7)
            }
            sqlite3_bind_int64(stmt, 8, z.id)
            if sqlite3_step(stmt) == SQLITE_DONE { ok = true }
        }
        sqlite3_finalize(stmt)
        if ok { _ = commit() }
        return ok
    }
    
    func deleteZaehlerstand(id: Int64) -> Bool {
        deleteZaehlerstandFotos(byZaehlerstandId: id)
        beginTransaction()
        let sql = "DELETE FROM Zaehlerstand WHERE id = ?;"
        var stmt: OpaquePointer?
        var ok = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, id)
            if sqlite3_step(stmt) == SQLITE_DONE { ok = true }
        }
        sqlite3_finalize(stmt)
        if ok { _ = commit() }
        return ok
    }
    
    /// Findet den letzten Zählerstand eines bestimmten Typs für eine Wohnung (vom Vormieter)
    /// Gibt den Zählerstand zurück, der den höchsten zaehlerEnde-Wert hat
    /// Optional kann auch nach Zähler-Nummer gefiltert werden
    /// WICHTIG: Gibt nur Zählerstände zurück, wenn noch keine Zählerstände für diese Wohnung existieren
    /// (d.h. nur beim ersten Zählerstand wird der Wert vom Vormieter übernommen)
    func getLetzterZaehlerstand(wohnungId: Int64, zaehlerTyp: String, zaehlerNummer: String? = nil) -> Zaehlerstand? {
        // Prüfe zuerst, ob bereits Zählerstände für diese Wohnung existieren
        let alleZaehlerstaende = getZaehlerstaende(byWohnungId: wohnungId)
        
        // Wenn bereits Zählerstände existieren, gib nichts zurück (keine Übernahme vom aktuellen Mieter)
        if !alleZaehlerstaende.isEmpty {
            return nil
        }
        
        // Nur wenn noch keine Zählerstände existieren, suche nach Vormieter-Zählerständen
        var sql = "SELECT id, wohnungId, zaehlerTyp, zaehlerNummer, zaehlerStart, zaehlerEnde, differenz, auchAbwasser, beschreibung FROM Zaehlerstand WHERE wohnungId = ? AND zaehlerTyp = ?"
        if let nummer = zaehlerNummer, !nummer.isEmpty {
            sql += " AND (zaehlerNummer = ? OR zaehlerNummer IS NULL)"
        }
        sql += " ORDER BY zaehlerEnde DESC LIMIT 1;"
        
        var stmt: OpaquePointer?
        var result: Zaehlerstand? = nil
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, wohnungId)
            sqlite3_bind_text(stmt, 2, (zaehlerTyp as NSString).utf8String, -1, nil)
            if let nummer = zaehlerNummer, !nummer.isEmpty {
                sqlite3_bind_text(stmt, 3, (nummer as NSString).utf8String, -1, nil)
            }
            if sqlite3_step(stmt) == SQLITE_ROW {
                result = Zaehlerstand(
                    id: sqlite3_column_int64(stmt, 0),
                    wohnungId: sqlite3_column_int64(stmt, 1),
                    zaehlerTyp: sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? "",
                    zaehlerNummer: sqlite3_column_text(stmt, 3).map { String(cString: $0) },
                    zaehlerStart: sqlite3_column_double(stmt, 4),
                    zaehlerEnde: sqlite3_column_double(stmt, 5),
                    auchAbwasser: sqlite3_column_type(stmt, 7) == SQLITE_NULL ? nil : (sqlite3_column_int(stmt, 7) == 1),
                    beschreibung: sqlite3_column_type(stmt, 8) == SQLITE_NULL ? nil : sqlite3_column_text(stmt, 8).map { String(cString: $0) }
                )
            }
        }
        sqlite3_finalize(stmt)
        return result
    }
    
    func deleteIncompleteRecords() -> Int {
        print("Bereinigen: Lösche Einträge ohne Bezeichnung oder ohne gültiges Jahr")
        beginTransaction()
        
        // Lösche Einträge wo hausBezeichnung leer ist (nach Trim) ODER abrechnungsJahr ungültig ist (< 1900 oder = 0)
        let deleteSQL = """
            DELETE FROM HausAbrechnung 
            WHERE TRIM(hausBezeichnung) = '' OR hausBezeichnung = '' 
               OR abrechnungsJahr < 1900 OR abrechnungsJahr = 0;
        """
        var statement: OpaquePointer?
        var deletedCount = 0
        
        if sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_DONE {
                deletedCount = Int(sqlite3_changes(db))
                print("Bereinigen erfolgreich ausgeführt, \(deletedCount) Zeile(n) gelöscht")
            } else {
                print("Fehler beim Bereinigen: \(String(cString: sqlite3_errmsg(db)))")
            }
        } else {
            print("Fehler beim Vorbereiten: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
        
        if commit() {
            print("Commit erfolgreich")
            return deletedCount
        } else {
            print("Fehler beim Commit")
            return 0
        }
    }
    
    func resetDatabase() -> Bool {
        print("Datenbank zurücksetzen: Lösche alle Daten und baue Tabelle neu auf")
        
        // Datenbank schließen (db = nil setzen, damit die Datei freigegeben wird)
        closeDatabase()
        
        // Datenbankdatei löschen
        let fileURL: URL
        do {
            fileURL = try FileManager.default
                .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent(dbName)
        } catch {
            print("Fehler beim Ermitteln des Datenbankpfads: \(error)")
            openDatabase()
            return false
        }
        
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
                print("Datenbankdatei gelöscht: \(fileURL.path)")
            }
        } catch {
            print("Fehler beim Löschen der Datenbankdatei: \(error)")
            openDatabase()
            return false
        }
        
        // Datenbank neu öffnen
        openDatabase()
        guard db != nil else {
            print("Fehler: Datenbank konnte nach Reset nicht neu geöffnet werden")
            return false
        }
        
        // Tabellen neu erstellen
        createTable()
        
        print("Datenbank erfolgreich zurückgesetzt")
        return true
    }
    
    // MARK: - Kosten
    
    func insertKosten(_ k: Kosten) -> Bool {
        beginTransaction()
        let sql = "INSERT INTO Kosten (hausAbrechnungId, kostenart, betrag, bezeichnung, verteilungsart) VALUES (?, ?, ?, ?, ?);"
        var stmt: OpaquePointer?
        var ok = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, k.hausAbrechnungId)
            sqlite3_bind_text(stmt, 2, (k.kostenart.rawValue as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 3, k.betrag)
            if let bezeichnung = k.bezeichnung, !bezeichnung.isEmpty {
                sqlite3_bind_text(stmt, 4, (bezeichnung as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 4)
            }
            sqlite3_bind_text(stmt, 5, (k.verteilungsart.rawValue as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_DONE { ok = true }
        }
        sqlite3_finalize(stmt)
        if ok { _ = commit() }
        return ok
    }
    
    func getKosten(byHausAbrechnungId hausId: Int64) -> [Kosten] {
        let sql = "SELECT id, hausAbrechnungId, kostenart, betrag, bezeichnung, verteilungsart FROM Kosten WHERE hausAbrechnungId = ? ORDER BY kostenart;"
        var stmt: OpaquePointer?
        var list: [Kosten] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, hausId)
            while sqlite3_step(stmt) == SQLITE_ROW {
                let kostenartRaw = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
                let verteilungsartRaw = sqlite3_column_text(stmt, 5).map { String(cString: $0) } ?? "nach Qm"
                if let kostenart = Kostenart(rawValue: kostenartRaw) {
                    let verteilungsart = Verteilungsart(rawValue: verteilungsartRaw) ?? .nachQm
                    list.append(Kosten(
                        id: sqlite3_column_int64(stmt, 0),
                        hausAbrechnungId: sqlite3_column_int64(stmt, 1),
                        kostenart: kostenart,
                        betrag: sqlite3_column_double(stmt, 3),
                        bezeichnung: sqlite3_column_text(stmt, 4).map { String(cString: $0) },
                        verteilungsart: verteilungsart
                    ))
                }
            }
        }
        sqlite3_finalize(stmt)
        return list
    }
    
    func updateKosten(_ k: Kosten) -> Bool {
        beginTransaction()
        let sql = "UPDATE Kosten SET kostenart = ?, betrag = ?, bezeichnung = ?, verteilungsart = ? WHERE id = ?;"
        var stmt: OpaquePointer?
        var ok = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (k.kostenart.rawValue as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 2, k.betrag)
            if let bezeichnung = k.bezeichnung, !bezeichnung.isEmpty {
                sqlite3_bind_text(stmt, 3, (bezeichnung as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 3)
            }
            sqlite3_bind_text(stmt, 4, (k.verteilungsart.rawValue as NSString).utf8String, -1, nil)
            sqlite3_bind_int64(stmt, 5, k.id)
            if sqlite3_step(stmt) == SQLITE_DONE { ok = true }
        }
        sqlite3_finalize(stmt)
        if ok { _ = commit() }
        return ok
    }
    
    func deleteKosten(id: Int64) -> Bool {
        deleteKostenFotos(byKostenId: id)
        beginTransaction()
        let sql = "DELETE FROM Kosten WHERE id = ?;"
        var stmt: OpaquePointer?
        var ok = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, id)
            if sqlite3_step(stmt) == SQLITE_DONE { ok = true }
        }
        sqlite3_finalize(stmt)
        if ok { _ = commit() }
        return ok
    }
    
    // MARK: - Musterhaus (Testversion)
    
    /// Legt ein Musterhaus mit 2 Muster-Wohnungen, Frischwasser-Zählern und Kostenpositionen (Phantasiewerte) an.
    /// Jahr = abrechnungsJahr (z. B. lfd. Jahr - 1). Gibt das angelegte Haus zurück oder nil bei Fehler.
    func createMusterhaus(abrechnungsJahr: Int) -> HausAbrechnung? {
        let hausBezeichnung = "Musterstraße 1"
        let ort = "Musterstadt"
        let postleitzahl = "12345"
        let haus = HausAbrechnung(
            hausBezeichnung: hausBezeichnung,
            abrechnungsJahr: abrechnungsJahr,
            postleitzahl: postleitzahl,
            ort: ort,
            gesamtflaeche: 110,
            anzahlWohnungen: 2,
            leerstandspruefung: .nein,
            verwalterName: "Muster-Verwaltung GmbH",
            verwalterStrasse: "Verwalterstraße 1",
            verwalterPLZOrt: "12345 Musterstadt",
            verwalterEmail: "info@muster-verwaltung.de",
            verwalterTelefon: "0123 456789",
            verwalterInEmailVorbelegen: false
        )
        guard insert(hausAbrechnung: haus) else { return nil }
        guard let insertedHaus = getAll().first(where: { $0.hausBezeichnung == hausBezeichnung && $0.ort == ort && $0.abrechnungsJahr == abrechnungsJahr }) else { return nil }
        let hausId = insertedHaus.id
        
        // Wohnung 1 (Muster-Mieter 1) + Wohnung 1 als eigener Eintrag (Muster-Folge-Mieter) + Wohnung 2
        let w1 = Wohnung(hausAbrechnungId: hausId, wohnungsnummer: "1", bezeichnung: "Muster-Wohnung 1", qm: 50, name: "Muster-Mieter 1", strasse: hausBezeichnung, plz: postleitzahl, ort: ort)
        let w1Folge = Wohnung(hausAbrechnungId: hausId, wohnungsnummer: "1", bezeichnung: "Muster-Wohnung 1", qm: 50, name: "Muster-Folge-Mieter", strasse: hausBezeichnung, plz: postleitzahl, ort: ort)
        let w2 = Wohnung(hausAbrechnungId: hausId, wohnungsnummer: "2", bezeichnung: "Muster-Wohnung 2", qm: 60, name: "Muster-Mieter 2", strasse: hausBezeichnung, plz: postleitzahl, ort: ort)
        guard let w1Id = insertWohnung(w1), let w1FolgeId = insertWohnung(w1Folge), let w2Id = insertWohnung(w2) else { return insertedHaus }
        
        // Wohnung 1 (erster Eintrag): Muster-Mieter 1 mit 2 Mietzeiträumen (01.01–31.05, 2 Pers. / 01.06–30.09, 1 Pers.)
        let w1_1von = "\(abrechnungsJahr)-01-01"
        let w1_1bis = "\(abrechnungsJahr)-05-31"
        let w1_2von = "\(abrechnungsJahr)-06-01"
        let w1_2bis = "\(abrechnungsJahr)-09-30"
        _ = insertMietzeitraum(Mietzeitraum(wohnungId: w1Id, jahr: abrechnungsJahr, hauptmieterName: "Muster-Mieter 1", vonDatum: w1_1von, bisDatum: w1_1bis, anzahlPersonen: 2))
        _ = insertMietzeitraum(Mietzeitraum(wohnungId: w1Id, jahr: abrechnungsJahr, hauptmieterName: "Muster-Mieter 1", vonDatum: w1_2von, bisDatum: w1_2bis, anzahlPersonen: 1))
        // Wohnung 1 (Folge-Mieter, eigener Eintrag in der Übersicht): Muster-Folge-Mieter 01.10–31.12, 3 Pers.
        let w1_3von = "\(abrechnungsJahr)-10-01"
        let w1_3bis = "\(abrechnungsJahr)-12-31"
        _ = insertMietzeitraum(Mietzeitraum(wohnungId: w1FolgeId, jahr: abrechnungsJahr, hauptmieterName: "Muster-Folge-Mieter", vonDatum: w1_3von, bisDatum: w1_3bis, anzahlPersonen: 3))
        // Wohnung 2: 2 aufeinander folgende Mieter (01.01–30.06 / 01.07–31.12)
        let w2_1von = "\(abrechnungsJahr)-01-01"
        let w2_1bis = "\(abrechnungsJahr)-06-30"
        let w2_2von = "\(abrechnungsJahr)-07-01"
        let w2_2bis = "\(abrechnungsJahr)-12-31"
        _ = insertMietzeitraum(Mietzeitraum(wohnungId: w2Id, jahr: abrechnungsJahr, hauptmieterName: "Muster-Mieter 2a", vonDatum: w2_1von, bisDatum: w2_1bis, anzahlPersonen: 1))
        _ = insertMietzeitraum(Mietzeitraum(wohnungId: w2Id, jahr: abrechnungsJahr, hauptmieterName: "Muster-Mieter 2b", vonDatum: w2_2von, bisDatum: w2_2bis, anzahlPersonen: 1))
        
        // Zählerstände pro Wohnung: 2× Frischwasser (1 mit Abwasser, 1 ohne), Warmwasser, Strom, Gas, Sonstiges – unterschiedliche Werte
        func musterZaehler(wohnungId: Int64, suffix: String, startOff: Double) {
            let s = startOff
            _ = insertZaehlerstand(Zaehlerstand(wohnungId: wohnungId, zaehlerTyp: "Frischwasser", zaehlerNummer: "FW-\(suffix)a", zaehlerStart: s, zaehlerEnde: s + 42.5, auchAbwasser: true, beschreibung: nil))
            _ = insertZaehlerstand(Zaehlerstand(wohnungId: wohnungId, zaehlerTyp: "Frischwasser", zaehlerNummer: "FW-\(suffix)b", zaehlerStart: s + 10, zaehlerEnde: s + 28.3, auchAbwasser: false, beschreibung: "Gartenwasser kein Abwasser"))
            _ = insertZaehlerstand(Zaehlerstand(wohnungId: wohnungId, zaehlerTyp: "Warmwasser", zaehlerNummer: "WW-\(suffix)", zaehlerStart: s + 100, zaehlerEnde: s + 127.8, auchAbwasser: nil, beschreibung: nil))
            _ = insertZaehlerstand(Zaehlerstand(wohnungId: wohnungId, zaehlerTyp: "Strom", zaehlerNummer: "ST-\(suffix)", zaehlerStart: s * 10, zaehlerEnde: s * 10 + 1250, auchAbwasser: nil, beschreibung: nil))
            _ = insertZaehlerstand(Zaehlerstand(wohnungId: wohnungId, zaehlerTyp: "Gas", zaehlerNummer: "GA-\(suffix)", zaehlerStart: s * 5, zaehlerEnde: s * 5 + 890, auchAbwasser: nil, beschreibung: nil))
            _ = insertZaehlerstand(Zaehlerstand(wohnungId: wohnungId, zaehlerTyp: "Sonstiges", zaehlerNummer: "SO-\(suffix)", zaehlerStart: s + 50, zaehlerEnde: s + 73.2, auchAbwasser: nil, beschreibung: nil))
        }
        musterZaehler(wohnungId: w1Id, suffix: "001", startOff: 100)
        musterZaehler(wohnungId: w1FolgeId, suffix: "001b", startOff: 152)
        musterZaehler(wohnungId: w2Id, suffix: "002", startOff: 80)
        
        // Kostenpositionen mit Abrechnungsarten (Phantasiewerte) – Defaults gemäß üblicher Verteilung
        _ = insertKosten(Kosten(hausAbrechnungId: hausId, kostenart: .frischwasser, betrag: 450, bezeichnung: nil, verteilungsart: .nachVerbrauch))
        _ = insertKosten(Kosten(hausAbrechnungId: hausId, kostenart: .warmwasser, betrag: 380, bezeichnung: nil, verteilungsart: .nachVerbrauch))
        _ = insertKosten(Kosten(hausAbrechnungId: hausId, kostenart: .abwasser, betrag: 280, bezeichnung: nil, verteilungsart: .nachVerbrauch))
        _ = insertKosten(Kosten(hausAbrechnungId: hausId, kostenart: .abfall, betrag: 180, bezeichnung: nil, verteilungsart: .nachPersonen))
        _ = insertKosten(Kosten(hausAbrechnungId: hausId, kostenart: .grundsteuer, betrag: 350, bezeichnung: nil, verteilungsart: .nachQm))
        _ = insertKosten(Kosten(hausAbrechnungId: hausId, kostenart: .strom, betrag: 620, bezeichnung: nil, verteilungsart: .nachVerbrauch))
        _ = insertKosten(Kosten(hausAbrechnungId: hausId, kostenart: .hausstrom, betrag: 120, bezeichnung: nil, verteilungsart: .nachPersonen))
        _ = insertKosten(Kosten(hausAbrechnungId: hausId, kostenart: .kabel, betrag: 80, bezeichnung: nil, verteilungsart: .nachWohneinheiten))
        _ = insertKosten(Kosten(hausAbrechnungId: hausId, kostenart: .niederschlagswasser, betrag: 120, bezeichnung: nil, verteilungsart: .nachQm))
        _ = insertKosten(Kosten(hausAbrechnungId: hausId, kostenart: .sachHaftpflichtVersicherung, betrag: 200, bezeichnung: nil, verteilungsart: .nachQm))
        _ = insertKosten(Kosten(hausAbrechnungId: hausId, kostenart: .schornsteinfeger, betrag: 0, bezeichnung: nil, verteilungsart: .nachEinzelnachweis))
        _ = insertKosten(Kosten(hausAbrechnungId: hausId, kostenart: .strassenreinigung, betrag: 95, bezeichnung: nil, verteilungsart: .nachQm))
        _ = insertKosten(Kosten(hausAbrechnungId: hausId, kostenart: .gas, betrag: 1100, bezeichnung: nil, verteilungsart: .nachVerbrauch))
        _ = insertKosten(Kosten(hausAbrechnungId: hausId, kostenart: .vorauszahlung, betrag: 0, bezeichnung: nil, verteilungsart: .nachEinzelnachweis))
        _ = insertKosten(Kosten(hausAbrechnungId: hausId, kostenart: .sonstiges, betrag: 0, bezeichnung: "Muster Sonstiges", verteilungsart: .nachEinzelnachweis))
        
        // Einzelnachweis für Vorauszahlung, Sonstiges und Schornsteinfeger (Phantasiewerte pro Wohnung: w1, w1Folge, w2)
        let kostenHaus = getKosten(byHausAbrechnungId: hausId)
        if let vorauszahlungId = kostenHaus.first(where: { $0.kostenart == .vorauszahlung })?.id {
            _ = insertEinzelnachweisWohnung(EinzelnachweisWohnung(kostenId: vorauszahlungId, wohnungId: w1Id, von: nil, betrag: 200))
            _ = insertEinzelnachweisWohnung(EinzelnachweisWohnung(kostenId: vorauszahlungId, wohnungId: w1FolgeId, von: nil, betrag: 200))
            _ = insertEinzelnachweisWohnung(EinzelnachweisWohnung(kostenId: vorauszahlungId, wohnungId: w2Id, von: nil, betrag: 200))
        }
        if let sonstigesId = kostenHaus.first(where: { $0.kostenart == .sonstiges })?.id {
            _ = insertEinzelnachweisWohnung(EinzelnachweisWohnung(kostenId: sonstigesId, wohnungId: w1Id, von: nil, betrag: 17))
            _ = insertEinzelnachweisWohnung(EinzelnachweisWohnung(kostenId: sonstigesId, wohnungId: w1FolgeId, von: nil, betrag: 17))
            _ = insertEinzelnachweisWohnung(EinzelnachweisWohnung(kostenId: sonstigesId, wohnungId: w2Id, von: nil, betrag: 16))
        }
        if let schornsteinfegerId = kostenHaus.first(where: { $0.kostenart == .schornsteinfeger })?.id {
            _ = insertEinzelnachweisWohnung(EinzelnachweisWohnung(kostenId: schornsteinfegerId, wohnungId: w1Id, von: nil, betrag: 50))
            _ = insertEinzelnachweisWohnung(EinzelnachweisWohnung(kostenId: schornsteinfegerId, wohnungId: w1FolgeId, von: nil, betrag: 50))
            _ = insertEinzelnachweisWohnung(EinzelnachweisWohnung(kostenId: schornsteinfegerId, wohnungId: w2Id, von: nil, betrag: 50))
        }
        
        return insertedHaus
    }
    
    // MARK: - EinzelnachweisWohnung
    
    func insertEinzelnachweisWohnung(_ e: EinzelnachweisWohnung) -> Bool {
        beginTransaction()
        let sql = "INSERT OR REPLACE INTO EinzelnachweisWohnung (kostenId, wohnungId, von, betrag) VALUES (?, ?, ?, ?);"
        var stmt: OpaquePointer?
        var ok = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, e.kostenId)
            sqlite3_bind_int64(stmt, 2, e.wohnungId)
            if let von = e.von, !von.isEmpty {
                sqlite3_bind_text(stmt, 3, (von as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 3)
            }
            if let betrag = e.betrag {
                sqlite3_bind_double(stmt, 4, betrag)
            } else {
                sqlite3_bind_null(stmt, 4)
            }
            if sqlite3_step(stmt) == SQLITE_DONE { ok = true }
        }
        sqlite3_finalize(stmt)
        if ok { _ = commit() }
        return ok
    }
    
    func getEinzelnachweisWohnung(kostenId: Int64, wohnungId: Int64) -> EinzelnachweisWohnung? {
        let sql = "SELECT id, kostenId, wohnungId, von, betrag FROM EinzelnachweisWohnung WHERE kostenId = ? AND wohnungId = ?;"
        var stmt: OpaquePointer?
        var result: EinzelnachweisWohnung? = nil
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, kostenId)
            sqlite3_bind_int64(stmt, 2, wohnungId)
            if sqlite3_step(stmt) == SQLITE_ROW {
                result = EinzelnachweisWohnung(
                    id: sqlite3_column_int64(stmt, 0),
                    kostenId: sqlite3_column_int64(stmt, 1),
                    wohnungId: sqlite3_column_int64(stmt, 2),
                    von: sqlite3_column_text(stmt, 3).map { String(cString: $0) },
                    betrag: sqlite3_column_type(stmt, 4) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 4)
                )
            }
        }
        sqlite3_finalize(stmt)
        return result
    }
    
    func getEinzelnachweisWohnungen(byKostenId kostenId: Int64) -> [EinzelnachweisWohnung] {
        let sql = "SELECT id, kostenId, wohnungId, von, betrag FROM EinzelnachweisWohnung WHERE kostenId = ?;"
        var stmt: OpaquePointer?
        var list: [EinzelnachweisWohnung] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, kostenId)
            while sqlite3_step(stmt) == SQLITE_ROW {
                list.append(EinzelnachweisWohnung(
                    id: sqlite3_column_int64(stmt, 0),
                    kostenId: sqlite3_column_int64(stmt, 1),
                    wohnungId: sqlite3_column_int64(stmt, 2),
                    von: sqlite3_column_text(stmt, 3).map { String(cString: $0) },
                    betrag: sqlite3_column_type(stmt, 4) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 4)
                ))
            }
        }
        sqlite3_finalize(stmt)
        return list
    }
    
    func getEinzelnachweisWohnungen(byWohnungId wohnungId: Int64) -> [EinzelnachweisWohnung] {
        let sql = "SELECT id, kostenId, wohnungId, von, betrag FROM EinzelnachweisWohnung WHERE wohnungId = ?;"
        var stmt: OpaquePointer?
        var list: [EinzelnachweisWohnung] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, wohnungId)
            while sqlite3_step(stmt) == SQLITE_ROW {
                list.append(EinzelnachweisWohnung(
                    id: sqlite3_column_int64(stmt, 0),
                    kostenId: sqlite3_column_int64(stmt, 1),
                    wohnungId: sqlite3_column_int64(stmt, 2),
                    von: sqlite3_column_text(stmt, 3).map { String(cString: $0) },
                    betrag: sqlite3_column_type(stmt, 4) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 4)
                ))
            }
        }
        sqlite3_finalize(stmt)
        return list
    }
    
    func deleteEinzelnachweisWohnung(kostenId: Int64, wohnungId: Int64) -> Bool {
        beginTransaction()
        let sql = "DELETE FROM EinzelnachweisWohnung WHERE kostenId = ? AND wohnungId = ?;"
        var stmt: OpaquePointer?
        var ok = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, kostenId)
            sqlite3_bind_int64(stmt, 2, wohnungId)
            if sqlite3_step(stmt) == SQLITE_DONE { ok = true }
        }
        sqlite3_finalize(stmt)
        if ok { _ = commit() }
        return ok
    }
    
    // MARK: - HausFoto
    
    /// Basis-URL für Haus-Fotos (Documents/HausFotos). Erstellt Verzeichnis falls nötig.
    func hausFotoBaseURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let base = docs.appendingPathComponent("HausFotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }
    
    /// Ordnername für Haus-Fotos (sanitized, für Unterordner)
    private static func hausFotoOrdnername(_ hausBezeichnung: String) -> String {
        let s = hausBezeichnung.trimmingCharacters(in: .whitespaces)
        let erlaubt = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        let sanitized = s.unicodeScalars.map { erlaubt.contains($0) ? String($0) : "_" }.joined()
        return sanitized.isEmpty ? "Haus" : sanitized
    }
    
    /// Vollständiger Ordner-URL für Fotos eines Hauses
    func hausFotoOrdnerURL(hausBezeichnung: String) -> URL {
        let base = hausFotoBaseURL()
        let ordner = Self.hausFotoOrdnername(hausBezeichnung)
        let url = base.appendingPathComponent(ordner, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    
    /// Vollständige URL zu einer gespeicherten Haus-Foto-Datei (imagePath ist relativ zu HausFotos/)
    func hausFotoFullURL(imagePath: String) -> URL {
        hausFotoBaseURL().appendingPathComponent(imagePath)
    }
    
    func insertHausFoto(hausBezeichnung: String, imagePath: String, sortOrder: Int, bildbezeichnung: String = "") -> Bool {
        beginTransaction()
        let sql = "INSERT INTO HausFoto (hausBezeichnung, imagePath, sortOrder, bildbezeichnung) VALUES (?, ?, ?, ?);"
        var stmt: OpaquePointer?
        var ok = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (hausBezeichnung as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (imagePath as NSString).utf8String, -1, nil)
            sqlite3_bind_int(stmt, 3, Int32(sortOrder))
            sqlite3_bind_text(stmt, 4, (bildbezeichnung as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_DONE { ok = true }
        }
        sqlite3_finalize(stmt)
        if ok { _ = commit() }
        return ok
    }
    
    func getHausFotos(byHausBezeichnung hausBezeichnung: String) -> [HausFoto] {
        let sql = "SELECT id, hausBezeichnung, imagePath, sortOrder, bildbezeichnung FROM HausFoto WHERE hausBezeichnung = ? ORDER BY sortOrder, id;"
        var stmt: OpaquePointer?
        var list: [HausFoto] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (hausBezeichnung as NSString).utf8String, -1, nil)
            while sqlite3_step(stmt) == SQLITE_ROW {
                list.append(HausFoto(
                    id: sqlite3_column_int64(stmt, 0),
                    hausBezeichnung: sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? "",
                    imagePath: sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? "",
                    sortOrder: Int(sqlite3_column_int(stmt, 3)),
                    bildbezeichnung: sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? ""
                ))
            }
        }
        sqlite3_finalize(stmt)
        return list
    }
    
    func updateHausFotoBezeichnung(id: Int64, bildbezeichnung: String) -> Bool {
        beginTransaction()
        let sql = "UPDATE HausFoto SET bildbezeichnung = ? WHERE id = ?;"
        var stmt: OpaquePointer?
        var ok = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (bildbezeichnung as NSString).utf8String, -1, nil)
            sqlite3_bind_int64(stmt, 2, id)
            if sqlite3_step(stmt) == SQLITE_DONE { ok = true }
        }
        sqlite3_finalize(stmt)
        if ok { _ = commit() }
        return ok
    }
    
    func deleteHausFoto(id: Int64) -> Bool {
        beginTransaction()
        let sql = "DELETE FROM HausFoto WHERE id = ?;"
        var stmt: OpaquePointer?
        var ok = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, id)
            if sqlite3_step(stmt) == SQLITE_DONE { ok = true }
        }
        sqlite3_finalize(stmt)
        if ok { _ = commit() }
        return ok
    }
    
    /// HausBezeichnung bei Fotos aktualisieren und Bildordner umbenennen (z. B. nach Umbenennung des Hauses)
    func updateHausFotoHausBezeichnung(from alt: String, to neu: String) {
        guard alt != neu else { return }
        let list = getHausFotos(byHausBezeichnung: alt)
        guard !list.isEmpty else { return }
        let base = hausFotoBaseURL()
        let oldOrdner = Self.hausFotoOrdnername(alt)
        let newOrdner = Self.hausFotoOrdnername(neu)
        let newOrdnerURL = base.appendingPathComponent(newOrdner, isDirectory: true)
        try? FileManager.default.createDirectory(at: newOrdnerURL, withIntermediateDirectories: true)
        beginTransaction()
        for f in list {
            let filename = (f.imagePath as NSString).lastPathComponent
            let src = base.appendingPathComponent(f.imagePath)
            let newPath = "\(newOrdner)/\(filename)"
            let dst = base.appendingPathComponent(newPath)
            if FileManager.default.fileExists(atPath: src.path) {
                try? FileManager.default.copyItem(at: src, to: dst)
            }
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, "UPDATE HausFoto SET hausBezeichnung = ?, imagePath = ? WHERE id = ?;", -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (neu as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (newPath as NSString).utf8String, -1, nil)
                sqlite3_bind_int64(stmt, 3, f.id)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
        _ = commit()
        let oldOrdnerURL = base.appendingPathComponent(oldOrdner, isDirectory: true)
        try? FileManager.default.removeItem(at: oldOrdnerURL)
    }
    
    // MARK: - MietzeitraumFoto
    
    func mietzeitraumFotoBaseURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let base = docs.appendingPathComponent("MietzeitraumFotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }
    
    func mietzeitraumFotoOrdnerURL(mietzeitraumId: Int64) -> URL {
        let base = mietzeitraumFotoBaseURL()
        let url = base.appendingPathComponent("\(mietzeitraumId)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    
    func mietzeitraumFotoFullURL(imagePath: String) -> URL {
        mietzeitraumFotoBaseURL().appendingPathComponent(imagePath)
    }
    
    func insertMietzeitraumFoto(mietzeitraumId: Int64, imagePath: String, sortOrder: Int, bildbezeichnung: String = "") -> Bool {
        beginTransaction()
        let sql = "INSERT INTO MietzeitraumFoto (mietzeitraumId, imagePath, sortOrder, bildbezeichnung) VALUES (?, ?, ?, ?);"
        var stmt: OpaquePointer?
        var ok = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, mietzeitraumId)
            sqlite3_bind_text(stmt, 2, (imagePath as NSString).utf8String, -1, nil)
            sqlite3_bind_int(stmt, 3, Int32(sortOrder))
            sqlite3_bind_text(stmt, 4, (bildbezeichnung as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_DONE { ok = true }
        }
        sqlite3_finalize(stmt)
        if ok { _ = commit() }
        return ok
    }
    
    func getMietzeitraumFotos(byMietzeitraumId mietzeitraumId: Int64) -> [MietzeitraumFoto] {
        let sql = "SELECT id, mietzeitraumId, imagePath, sortOrder, bildbezeichnung FROM MietzeitraumFoto WHERE mietzeitraumId = ? ORDER BY sortOrder, id;"
        var stmt: OpaquePointer?
        var list: [MietzeitraumFoto] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, mietzeitraumId)
            while sqlite3_step(stmt) == SQLITE_ROW {
                list.append(MietzeitraumFoto(
                    id: sqlite3_column_int64(stmt, 0),
                    mietzeitraumId: sqlite3_column_int64(stmt, 1),
                    imagePath: sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? "",
                    sortOrder: Int(sqlite3_column_int(stmt, 3)),
                    bildbezeichnung: sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? ""
                ))
            }
        }
        sqlite3_finalize(stmt)
        return list
    }
    
    func updateMietzeitraumFotoBezeichnung(id: Int64, bildbezeichnung: String) -> Bool {
        beginTransaction()
        let sql = "UPDATE MietzeitraumFoto SET bildbezeichnung = ? WHERE id = ?;"
        var stmt: OpaquePointer?
        var ok = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (bildbezeichnung as NSString).utf8String, -1, nil)
            sqlite3_bind_int64(stmt, 2, id)
            if sqlite3_step(stmt) == SQLITE_DONE { ok = true }
        }
        sqlite3_finalize(stmt)
        if ok { _ = commit() }
        return ok
    }
    
    func deleteMietzeitraumFoto(id: Int64) -> Bool {
        beginTransaction()
        let sql = "DELETE FROM MietzeitraumFoto WHERE id = ?;"
        var stmt: OpaquePointer?
        var ok = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, id)
            if sqlite3_step(stmt) == SQLITE_DONE { ok = true }
        }
        sqlite3_finalize(stmt)
        if ok { _ = commit() }
        return ok
    }
    
    /// Kopiert alle Mietzeitraum-Fotos (und Dateien) von einem Mietzeitraum zu einem anderen (z. B. beim Jahreswechsel).
    func duplicateMietzeitraumFotos(from alteMietzeitraumId: Int64, to neueMietzeitraumId: Int64) {
        let alteFotos = getMietzeitraumFotos(byMietzeitraumId: alteMietzeitraumId)
        let zielOrdner = mietzeitraumFotoOrdnerURL(mietzeitraumId: neueMietzeitraumId)
        for (idx, foto) in alteFotos.enumerated() {
            let srcURL = mietzeitraumFotoFullURL(imagePath: foto.imagePath)
            guard FileManager.default.fileExists(atPath: srcURL.path),
                  let data = try? Data(contentsOf: srcURL) else { continue }
            let filename = "img_\(UUID().uuidString).jpg"
            let destURL = zielOrdner.appendingPathComponent(filename)
            try? data.write(to: destURL)
            let relPath = "\(neueMietzeitraumId)/\(filename)"
            _ = insertMietzeitraumFoto(mietzeitraumId: neueMietzeitraumId, imagePath: relPath, sortOrder: idx, bildbezeichnung: foto.bildbezeichnung)
        }
    }
    
    // MARK: - KostenFoto
    
    func kostenFotoBaseURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let base = docs.appendingPathComponent("KostenFotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }
    
    func kostenFotoOrdnerURL(kostenId: Int64) -> URL {
        let base = kostenFotoBaseURL()
        let url = base.appendingPathComponent("\(kostenId)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    
    func kostenFotoFullURL(imagePath: String) -> URL {
        kostenFotoBaseURL().appendingPathComponent(imagePath)
    }
    
    func insertKostenFoto(kostenId: Int64, imagePath: String, sortOrder: Int, bildbezeichnung: String = "") -> Bool {
        beginTransaction()
        let sql = "INSERT INTO KostenFoto (kostenId, imagePath, sortOrder, bildbezeichnung) VALUES (?, ?, ?, ?);"
        var stmt: OpaquePointer?
        var ok = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, kostenId)
            sqlite3_bind_text(stmt, 2, (imagePath as NSString).utf8String, -1, nil)
            sqlite3_bind_int(stmt, 3, Int32(sortOrder))
            sqlite3_bind_text(stmt, 4, (bildbezeichnung as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_DONE { ok = true }
        }
        sqlite3_finalize(stmt)
        if ok { _ = commit() }
        return ok
    }
    
    func getKostenFotos(byKostenId kostenId: Int64) -> [KostenFoto] {
        let sql = "SELECT id, kostenId, imagePath, sortOrder, bildbezeichnung FROM KostenFoto WHERE kostenId = ? ORDER BY sortOrder, id;"
        var stmt: OpaquePointer?
        var list: [KostenFoto] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, kostenId)
            while sqlite3_step(stmt) == SQLITE_ROW {
                list.append(KostenFoto(
                    id: sqlite3_column_int64(stmt, 0),
                    kostenId: sqlite3_column_int64(stmt, 1),
                    imagePath: sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? "",
                    sortOrder: Int(sqlite3_column_int(stmt, 3)),
                    bildbezeichnung: sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? ""
                ))
            }
        }
        sqlite3_finalize(stmt)
        return list
    }
    
    func updateKostenFotoBezeichnung(id: Int64, bildbezeichnung: String) -> Bool {
        beginTransaction()
        let sql = "UPDATE KostenFoto SET bildbezeichnung = ? WHERE id = ?;"
        var stmt: OpaquePointer?
        var ok = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (bildbezeichnung as NSString).utf8String, -1, nil)
            sqlite3_bind_int64(stmt, 2, id)
            if sqlite3_step(stmt) == SQLITE_DONE { ok = true }
        }
        sqlite3_finalize(stmt)
        if ok { _ = commit() }
        return ok
    }
    
    func deleteKostenFoto(id: Int64) -> Bool {
        beginTransaction()
        let sql = "DELETE FROM KostenFoto WHERE id = ?;"
        var stmt: OpaquePointer?
        var ok = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, id)
            if sqlite3_step(stmt) == SQLITE_DONE { ok = true }
        }
        sqlite3_finalize(stmt)
        if ok { _ = commit() }
        return ok
    }
    
    // MARK: - ZaehlerstandFoto
    
    func zaehlerstandFotoBaseURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let base = docs.appendingPathComponent("ZaehlerstandFotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }
    
    func zaehlerstandFotoOrdnerURL(zaehlerstandId: Int64) -> URL {
        let base = zaehlerstandFotoBaseURL()
        let url = base.appendingPathComponent("\(zaehlerstandId)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    
    func zaehlerstandFotoFullURL(imagePath: String) -> URL {
        zaehlerstandFotoBaseURL().appendingPathComponent(imagePath)
    }
    
    func insertZaehlerstandFoto(zaehlerstandId: Int64, imagePath: String, sortOrder: Int, bildbezeichnung: String = "") -> Bool {
        beginTransaction()
        let sql = "INSERT INTO ZaehlerstandFoto (zaehlerstandId, imagePath, sortOrder, bildbezeichnung) VALUES (?, ?, ?, ?);"
        var stmt: OpaquePointer?
        var ok = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, zaehlerstandId)
            sqlite3_bind_text(stmt, 2, (imagePath as NSString).utf8String, -1, nil)
            sqlite3_bind_int(stmt, 3, Int32(sortOrder))
            sqlite3_bind_text(stmt, 4, (bildbezeichnung as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_DONE { ok = true }
        }
        sqlite3_finalize(stmt)
        if ok { _ = commit() }
        return ok
    }
    
    func getZaehlerstandFotos(byZaehlerstandId zaehlerstandId: Int64) -> [ZaehlerstandFoto] {
        let sql = "SELECT id, zaehlerstandId, imagePath, sortOrder, bildbezeichnung FROM ZaehlerstandFoto WHERE zaehlerstandId = ? ORDER BY sortOrder, id;"
        var stmt: OpaquePointer?
        var list: [ZaehlerstandFoto] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, zaehlerstandId)
            while sqlite3_step(stmt) == SQLITE_ROW {
                list.append(ZaehlerstandFoto(
                    id: sqlite3_column_int64(stmt, 0),
                    zaehlerstandId: sqlite3_column_int64(stmt, 1),
                    imagePath: sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? "",
                    sortOrder: Int(sqlite3_column_int(stmt, 3)),
                    bildbezeichnung: sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? ""
                ))
            }
        }
        sqlite3_finalize(stmt)
        return list
    }
    
    func updateZaehlerstandFotoBezeichnung(id: Int64, bildbezeichnung: String) -> Bool {
        beginTransaction()
        let sql = "UPDATE ZaehlerstandFoto SET bildbezeichnung = ? WHERE id = ?;"
        var stmt: OpaquePointer?
        var ok = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (bildbezeichnung as NSString).utf8String, -1, nil)
            sqlite3_bind_int64(stmt, 2, id)
            if sqlite3_step(stmt) == SQLITE_DONE { ok = true }
        }
        sqlite3_finalize(stmt)
        if ok { _ = commit() }
        return ok
    }
    
    func deleteZaehlerstandFoto(id: Int64) -> Bool {
        beginTransaction()
        let sql = "DELETE FROM ZaehlerstandFoto WHERE id = ?;"
        var stmt: OpaquePointer?
        var ok = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, id)
            if sqlite3_step(stmt) == SQLITE_DONE { ok = true }
        }
        sqlite3_finalize(stmt)
        if ok { _ = commit() }
        return ok
    }
    
    func deleteZaehlerstandFotos(byZaehlerstandId zaehlerstandId: Int64) {
        let fotos = getZaehlerstandFotos(byZaehlerstandId: zaehlerstandId)
        for foto in fotos {
            let url = zaehlerstandFotoFullURL(imagePath: foto.imagePath)
            if FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }
            _ = deleteZaehlerstandFoto(id: foto.id)
        }
    }
    
    /// Löscht alle Fotos einer Kostenposition (Dateien + DB-Einträge). Wird vor deleteKosten aufgerufen.
    func deleteKostenFotos(byKostenId kostenId: Int64) {
        let fotos = getKostenFotos(byKostenId: kostenId)
        for foto in fotos {
            let url = kostenFotoFullURL(imagePath: foto.imagePath)
            if FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }
            _ = deleteKostenFoto(id: foto.id)
        }
    }
    
    // MARK: - Jahreswechsel
    
    /// Prüft, ob für ein Haus ein neueres Jahr existiert (dann ist das alte Jahr gesperrt)
    func istJahrGesperrt(hausBezeichnung: String, jahr: Int) -> Bool {
        let sql = """
            SELECT COUNT(*) FROM HausAbrechnung 
            WHERE hausBezeichnung = ? AND abrechnungsJahr > ?
        """
        var stmt: OpaquePointer?
        var anzahl: Int = 0
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (hausBezeichnung as NSString).utf8String, -1, nil)
            sqlite3_bind_int(stmt, 2, Int32(jahr))
            if sqlite3_step(stmt) == SQLITE_ROW {
                anzahl = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        return anzahl > 0
    }
    
    /// Führt einen Jahreswechsel durch: Erstellt ein neues Jahr für das gleiche Haus
    /// und kopiert alle relevanten Daten
    func jahreswechsel(vonHausId: Int64, neuesJahr: Int) -> (erfolgreich: Bool, neuesHausId: Int64?, fehlermeldung: String?) {
        guard let altesHaus = getHausAbrechnung(by: vonHausId) else {
            return (false, nil, "Altes Haus nicht gefunden")
        }
        
        // Prüfe ob neues Jahr bereits existiert
        let existierendeHaeuser = getAll().filter { 
            $0.hausBezeichnung == altesHaus.hausBezeichnung && $0.abrechnungsJahr == neuesJahr 
        }
        if !existierendeHaeuser.isEmpty {
            return (false, nil, "Für dieses Haus existiert bereits ein Eintrag für das Jahr \(neuesJahr)")
        }
        
        beginTransaction()
        
        // 1. Erstelle neues Haus
        let neuesHaus = HausAbrechnung(
            hausBezeichnung: altesHaus.hausBezeichnung,
            abrechnungsJahr: neuesJahr,
            postleitzahl: altesHaus.postleitzahl,
            ort: altesHaus.ort,
            gesamtflaeche: altesHaus.gesamtflaeche,
            anzahlWohnungen: altesHaus.anzahlWohnungen,
            leerstandspruefung: altesHaus.leerstandspruefung,
            verwalterName: altesHaus.verwalterName,
            verwalterStrasse: altesHaus.verwalterStrasse,
            verwalterPLZOrt: altesHaus.verwalterPLZOrt,
            verwalterEmail: altesHaus.verwalterEmail,
            verwalterTelefon: altesHaus.verwalterTelefon,
            verwalterInEmailVorbelegen: altesHaus.verwalterInEmailVorbelegen
        )
        
        guard insert(hausAbrechnung: neuesHaus) else {
            _ = rollback()
            return (false, nil, "Fehler beim Erstellen des neuen Hauses")
        }
        
        guard let neuesHausAusDB = getAll().first(where: {
            $0.hausBezeichnung == neuesHaus.hausBezeichnung && $0.abrechnungsJahr == neuesJahr
        }) else {
            _ = rollback()
            return (false, nil, "Neues Haus konnte nicht gefunden werden")
        }
        
        let neuesHausId = neuesHausAusDB.id
        
        let jahresendeDatum = "\(altesHaus.abrechnungsJahr)-12-31"
        
        // 2. Kopiere nur Wohnungen, bei denen mindestens ein Mieter mit End-Datum 31.12. übernommen wird
        let alteWohnungen = getWohnungen(byHausAbrechnungId: vonHausId)
        var wohnungIdMapping: [Int64: Int64] = [:]
        
        for alteWohnung in alteWohnungen {
            let hatMieterBisJahresende = getMietzeitraeume(byWohnungId: alteWohnung.id).contains { $0.bisDatum == jahresendeDatum && $0.mietendeOption != .gekuendigtZumMietzeitende }
            if !hatMieterBisJahresende { continue }
            
            let neueWohnung = Wohnung(
                hausAbrechnungId: neuesHausId,
                wohnungsnummer: alteWohnung.wohnungsnummer,
                bezeichnung: alteWohnung.bezeichnung,
                qm: alteWohnung.qm,
                name: alteWohnung.name,
                strasse: alteWohnung.strasse,
                plz: alteWohnung.plz,
                ort: alteWohnung.ort,
                email: alteWohnung.email,
                telefon: alteWohnung.telefon
            )
            
            if let neueWohnungId = insertWohnung(neueWohnung) {
                wohnungIdMapping[alteWohnung.id] = neueWohnungId
            }
        }
        
        // 3. Kopiere Mietzeiträume (nur die mit End-Datum 31.12. des Abrechnungsjahres, höchster Eintrag pro Hauptmieter)
        for alteWohnung in alteWohnungen {
            guard let neueWohnungId = wohnungIdMapping[alteWohnung.id] else { continue }
            
            // Hole alle Mietzeiträume für diese Wohnung
            let alleMietzeitraeume = getMietzeitraeume(byWohnungId: alteWohnung.id)
            
            // Nur Mieter übernehmen, deren End-Datum exakt der 31.12. des Jahres ist und die nicht „gekündigt zum Mietzeitende“ sind
            let mietzeitraeumeBisJahresende = alleMietzeitraeume.filter { $0.bisDatum == jahresendeDatum && $0.mietendeOption != .gekuendigtZumMietzeitende }
            
            // Gruppiere nach Hauptmieter und nimm den höchsten Eintrag (nach ID)
            let gruppiert = Dictionary(grouping: mietzeitraeumeBisJahresende) { $0.hauptmieterName }
            
            for (hauptmieterName, zeitraeume) in gruppiert {
                // Nimm den Eintrag mit der höchsten ID (neuester Eintrag)
                guard let letzterMietzeitraum = zeitraeume.max(by: { $0.id < $1.id }) else { continue }
                
                // Erstelle neuen Mietzeitraum für das neue Jahr: 1.1. - 31.12. (mietendeOption übernehmen)
                let neuerMietzeitraum = Mietzeitraum(
                    wohnungId: neueWohnungId,
                    jahr: neuesJahr,
                    hauptmieterName: letzterMietzeitraum.hauptmieterName,
                    vonDatum: "\(neuesJahr)-01-01",
                    bisDatum: "\(neuesJahr)-12-31",
                    anzahlPersonen: letzterMietzeitraum.anzahlPersonen,
                    mietendeOption: letzterMietzeitraum.mietendeOption
                )
                
                guard insertMietzeitraum(neuerMietzeitraum) else {
                    _ = rollback()
                    return (false, nil, "Fehler beim Kopieren der Mietzeiträume")
                }
                
                // Kopiere Mitmieter (falls vorhanden)
                let alteMitmieter = getMitmieter(byMietzeitraumId: letzterMietzeitraum.id)
                if let neuerMietzeitraumAusDB = getMietzeitraeume(byWohnungId: neueWohnungId).last {
                    for alterMitmieter in alteMitmieter {
                        let neuerMitmieter = Mitmieter(
                            mietzeitraumId: neuerMietzeitraumAusDB.id,
                            name: alterMitmieter.name,
                            vonDatum: "\(neuesJahr)-01-01",
                            bisDatum: "\(neuesJahr)-12-31"
                        )
                        _ = insertMitmieter(neuerMitmieter)
                    }
                    // Kopiere Mietzeitraum-Fotos (Verträge/Anhänge) mit duplizierten Dateien
                    duplicateMietzeitraumFotos(from: letzterMietzeitraum.id, to: neuerMietzeitraumAusDB.id)
                }
            }
        }
        
        // 4. Kopiere Kosten-Positionen (ohne Wert, Betrag = 0)
        let alteKosten = getKosten(byHausAbrechnungId: vonHausId)
        for alteKostenPosition in alteKosten {
            let neueKostenPosition = Kosten(
                hausAbrechnungId: neuesHausId,
                kostenart: alteKostenPosition.kostenart,
                betrag: 0.0, // Wert auf 0 setzen
                bezeichnung: alteKostenPosition.bezeichnung,
                verteilungsart: alteKostenPosition.verteilungsart
            )
            _ = insertKosten(neueKostenPosition)
        }
        
        // 5. Kopiere Zählerstände nur für Wohnungen, bei denen ein Mieter mit End-Datum 31.12. (nicht gekündigt) übernommen wurde
        for alteWohnung in alteWohnungen {
            let hatMieterBisJahresende = getMietzeitraeume(byWohnungId: alteWohnung.id).contains { $0.bisDatum == jahresendeDatum && $0.mietendeOption != .gekuendigtZumMietzeitende }
            if !hatMieterBisJahresende { continue }
            
            guard let neueWohnungId = wohnungIdMapping[alteWohnung.id] else { continue }
            
            let alteZaehlerstaende = getZaehlerstaende(byWohnungId: alteWohnung.id)
            
            // Gruppiere nach Zähler-Typ und Zähler-Nummer
            let gruppiert = Dictionary(grouping: alteZaehlerstaende) { (z: Zaehlerstand) -> String in
                "\(z.zaehlerTyp)_\(z.zaehlerNummer ?? "")"
            }
            
            for (_, zaehlerstaende) in gruppiert {
                // Nimm den Zählerstand mit dem höchsten zaehlerEnde (letzter Stand)
                guard let letzterZaehlerstand = zaehlerstaende.max(by: { $0.zaehlerEnde < $1.zaehlerEnde }) else { continue }
                
                // Erstelle neuen Zählerstand mit letztem Stand als Start
                let neuerZaehlerstand = Zaehlerstand(
                    wohnungId: neueWohnungId,
                    zaehlerTyp: letzterZaehlerstand.zaehlerTyp,
                    zaehlerNummer: letzterZaehlerstand.zaehlerNummer,
                    zaehlerStart: letzterZaehlerstand.zaehlerEnde, // Letzter Stand wird neuer Start
                    zaehlerEnde: letzterZaehlerstand.zaehlerEnde, // Initial gleich, wird später aktualisiert
                    auchAbwasser: letzterZaehlerstand.auchAbwasser,
                    beschreibung: letzterZaehlerstand.beschreibung
                )
                _ = insertZaehlerstand(neuerZaehlerstand)
            }
        }
        
        // Jede aufgerufene Methode (insert, insertWohnung, insertMietzeitraum, …) führt bereits
        // eigene beginTransaction/commit aus. Eine äußere Transaktion ist danach nicht mehr aktiv.
        // Ein weiterer commit() würde fehlschlagen, obwohl alle Daten korrekt gespeichert sind.
        return (true, neuesHausId, nil)
    }
}
