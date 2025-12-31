import SwiftUI
#if os(macOS)
import AppKit
#endif

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var detectionMessage: String?

    var body: some View {
        Form {
            Section("ipatool Binary") {
                HStack {
                    TextField("Path to ipatool", text: binding(\.ipatoolPath))
                        .textFieldStyle(.roundedBorder)
                    Button("Browse…", action: browseForExecutable)
                    Button("Auto-Detect", action: autoDetect)
                }
                if let message = detectionMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Behavior") {
                Toggle("Non-interactive", isOn: binding(\.nonInteractive))
                Toggle("Verbose Logs", isOn: binding(\.verboseLogs))
                Picker("Output Format", selection: binding(\.outputFormat)) {
                    ForEach(Preferences.OutputFormat.allCases) { format in
                        Text(format.rawValue.uppercased()).tag(format)
                    }
                }
                SecureField("Keychain Passphrase", text: binding(\.keychainPassphrase))
                    .textFieldStyle(.roundedBorder)
            }
            
            Section("Currency Display") {
                Picker("Locale", selection: localeBinding) {
                    Text("Auto (System/Account)").tag(String?.none)
                    ForEach(CountryCode.allCountries) { country in
                        Text("\(country.name) (\(country.currencySymbol))").tag(String?.some(country.code))
                    }
                }
                if let selectedCode = appState.preferences.selectedCountryCode,
                   let country = CountryCode.find(by: selectedCode) {
                    Text("Selected: \(country.name) - \(country.currencySymbol)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Using: \(appState.effectiveCountryCode ?? "Unknown")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<Preferences, Value>) -> Binding<Value> {
        Binding(
            get: { appState.preferences[keyPath: keyPath] },
            set: { newValue in
                appState.preferences[keyPath: keyPath] = newValue
            }
        )
    }
    
    private var localeBinding: Binding<String?> {
        Binding(
            get: { appState.preferences.selectedCountryCode },
            set: { newValue in
                appState.preferences.selectedCountryCode = newValue
            }
        )
    }

    private func autoDetect() {
        DispatchQueue.main.async {
            if let detected = IpatoolService.autoDetectExecutablePath() {
                self.appState.preferences.ipatoolPath = detected
                self.detectionMessage = "Detected at \(detected)."
            } else {
                self.detectionMessage = "Unable to locate ipatool. Install it via Homebrew first."
            }
        }
    }

    private func browseForExecutable() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            DispatchQueue.main.async {
                self.appState.preferences.ipatoolPath = url.path
                self.detectionMessage = "Using \(url.path)"
            }
        }
        #endif
    }
}
