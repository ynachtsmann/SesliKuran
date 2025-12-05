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
