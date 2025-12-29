# Anleitung zum Hinzufügen der Audiodateien

Diese Anleitung führt dich Schritt für Schritt durch den Prozess, wie du die 114 Koran-Rezitationen (Suren) korrekt in deine App einfügst.

## 1. Audiodateien vorbereiten (Umbenennen)

Damit die App die Dateien automatisch erkennt, müssen sie exakt nach einem bestimmten Muster benannt sein.

1.  Sammle alle deine 114 MP3-Dateien in einem Ordner auf deinem Mac.
2.  Benenne jede Datei entsprechend ihrer Sure-Nummer um. Das Format muss **exakt** so aussehen:

    *   Al-Fatiha (Sure 1) -> `Audio 1.mp3`
    *   Al-Baqarah (Sure 2) -> `Audio 2.mp3`
    *   ...
    *   An-Nas (Sure 114) -> `Audio 114.mp3`

    **Wichtig:** Achte auf das Leerzeichen zwischen "Audio" und der Zahl! (`Audio 1.mp3` ✅, `Audio1.mp3` ❌)

## 2. Projekt in Xcode öffnen

1.  Starte Xcode.
2.  Öffne dein Projekt `SesliKuran.xcodeproj`.
3.  Du solltest nun links die Dateileiste (Project Navigator) sehen.

## 3. Dateien in Xcode importieren

Dies ist der wichtigste Schritt.

1.  Markiere alle 114 umbenannten MP3-Dateien in deinem Finder-Fenster.
2.  Ziehe die Dateien (Drag & Drop) in die linke Leiste von Xcode, am besten in den Ordner `SesliKuran` (dort wo auch `ContentView.swift` liegt).
3.  Sobald du die Dateien loslässt, erscheint ein Fenster mit Optionen ("Choose options for adding these files").

## 4. Import-Einstellungen (Sehr Wichtig!)

Stelle sicher, dass folgende Haken gesetzt sind:

*   **[x] Copy items if needed** (Kopiere Elemente, falls nötig) -> **Muss aktiviert sein!**
*   **Added folders:** "Create groups" (Gruppen erstellen)
*   **Add to targets:**
    *   **[x] SesliKuran** (Hier muss unbedingt ein Haken bei deiner App sein!)

4.  Klicke auf **Finish**.

## 5. Fertigstellung

1.  Du siehst nun die Dateien `Audio 1.mp3` bis `Audio 114.mp3` in der linken Leiste von Xcode.
2.  Starte die App (Play-Button oben links).
3.  Wenn du nun eine Sure auswählst, sollte sie sofort abgespielt werden.

---

### Fehlerbehebung

*   **"Fehler: Audiodatei nicht gefunden"**: Wenn du diese Meldung in der App siehst, bedeutet das meistens:
    *   Die Datei heißt falsch (z.B. `Audio1.mp3` statt `Audio 1.mp3`).
    *   Oder: Beim Importieren wurde der Haken bei **"Add to targets: SesliKuran"** vergessen.
    *   Lösung: Lösche die Datei aus Xcode (Remove Reference) und ziehe sie erneut hinein, diesmal mit gesetztem Haken.
