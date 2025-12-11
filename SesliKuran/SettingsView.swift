// MARK: - Imports
import SwiftUI

struct SettingsView: View {
    @ObservedObject var themeManager: ThemeManager
    @ObservedObject var audioManager: AudioManager
    @Environment(\.presentationMode) var presentationMode

    let playbackRates: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Erscheinungsbild")) {
                    Toggle(isOn: $themeManager.isDarkMode.animation()) {
                        HStack {
                            Image(systemName: themeManager.isDarkMode ? "moon.fill" : "sun.max.fill")
                                .foregroundColor(themeManager.isDarkMode ? .white : .orange)
                            Text("Dunkelmodus")
                        }
                    }
                }

                Section(header: Text("Audio")) {
                    Picker("Wiedergabegeschwindigkeit", selection: Binding(
                        get: { audioManager.playbackRate },
                        set: { audioManager.setPlaybackSpeed($0) }
                    )) {
                        ForEach(playbackRates, id: \.self) { rate in
                            Text("\(String(format: "%.2fx", rate))")
                                .tag(rate)
                        }
                    }
                }

                Section(header: Text("Hilfe")) {
                    NavigationLink(destination: HelpView()) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.blue)
                            Text("Audio hinzufügen")
                        }
                    }
                }

                Section(header: Text("Über")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("So fügen Sie Audio-Dateien hinzu")
                    .font(.title)
                    .bold()

                Text("Diese App ist ein Offline-Player. Sie können Ihre eigenen Audio-Dateien über iTunes/Finder hinzufügen.")
                    .font(.body)

                VStack(alignment: .leading, spacing: 10) {
                    Text("1. Verbinden Sie Ihr iPhone mit dem Computer.")
                    Text("2. Öffnen Sie iTunes (Windows) oder Finder (Mac).")
                    Text("3. Gehen Sie zu 'Dateien' und wählen Sie 'SesliKuran'.")
                    Text("4. Ziehen Sie Ihre MP3-Dateien hinein.")
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)

                Text("Wichtig: Dateinamen")
                    .font(.headline)

                Text("Die Dateien müssen wie folgt benannt sein:")

                Text("Audio {ID}.mp3")
                    .font(.system(.body, design: .monospaced))
                    .padding(5)
                    .background(Color.yellow.opacity(0.2))
                    .cornerRadius(5)

                Text("Beispiele: 'Audio 1.mp3' für Al-Fatiha.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .navigationTitle("Hilfe")
    }
}
