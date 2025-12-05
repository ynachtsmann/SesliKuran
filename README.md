# SesliKuran (Audio Quran)

Eine moderne iOS-Anwendung zum Anhören des Heiligen Koran.

## Funktionen

*   **Audio-Player:** Vollständiger Player mit Play/Pause, Vor/Zurück und Fortschrittsanzeige.
*   **Audiobook-Steuerung:** Spezielle Tasten zum Springen (-15s / +30s) und Unterstützung für die Wiedergabesteuerung im Sperrbildschirm.
*   **Intelligente Wiederaufnahme:** Die App merkt sich automatisch die letzte Surah und die genaue Position.
*   **Schlaftimer:** Stellen Sie einen Timer ein, um die Wiedergabe automatisch zu stoppen (15, 30, 45, 60 Min).
*   **Favoriten & Suche:** Markieren Sie Ihre Lieblings-Surahs und durchsuchen Sie die Liste schnell.
*   **AirPlay:** Streamen Sie Audio an externe Lautsprecher.
*   **Dunkelmodus:** Vollständige Unterstützung für den Dark Mode.
*   **Einstellungen:** Passen Sie die Wiedergabegeschwindigkeit (0.5x - 2.0x) an.

## Audio-Dateien hinzufügen

Diese App ist als Offline-Player konzipiert. Sie müssen die Audio-Dateien selbst bereitstellen.

1.  Verbinden Sie Ihr iPhone mit Ihrem Computer.
2.  Öffnen Sie **Finder** (macOS) oder **iTunes** (Windows).
3.  Wählen Sie Ihr Gerät aus und gehen Sie zum Reiter **"Dateien"** (Files).
4.  Suchen Sie **SesliKuran** in der Liste der Apps.
5.  Ziehen Sie Ihre MP3-Dateien in den Ordner der App.

**Wichtig:** Die Dateien müssen folgendes Namensschema haben:
`Audio {ID}.mp3`

Beispiele:
*   `Audio 1.mp3` (für Al-Fatiha)
*   `Audio 18.mp3` (für Al-Kahf)
*   `Audio 114.mp3` (für An-Nas)

Wenn eine Datei fehlt, zeigt die App eine entsprechende Meldung an.

## Entwicklung

Das Projekt verwendet **SwiftUI** und folgt dem **MVVM**-Muster.
*   `AudioManager`: Verwaltet die Logik für Wiedergabe, Sitzungswiederherstellung und Audio-Session.
*   `ThemeManager`: Verwaltet das Erscheinungsbild der App.
*   `SurahData`: Statische Daten für die 114 Surahs.

### Tests
Das Projekt enthält Unit-Tests und UI-Tests, um die Stabilität zu gewährleisten. Führen Sie diese mit `Cmd+U` in Xcode aus.
