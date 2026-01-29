import SwiftUI

struct InstallView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: InstallViewModel
    
    init(viewModel: InstallViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        Form {
            Section {
                Text(appState.localizationManager.strings.installDeviceNote)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } header: {
                Text(appState.localizationManager.strings.note)
            }
            
            Section {
                TextField(appState.localizationManager.strings.appID, text: $viewModel.appIDString)
                
                TextField(appState.localizationManager.strings.bundleID, text: $viewModel.bundleIdentifier)
                    .autocorrectionDisabled()
                
                TextField(appState.localizationManager.strings.externalVersionIDOptional, text: $viewModel.externalVersionID)
                    .autocorrectionDisabled()
                
                TextField("Device UDID (optional)", text: $viewModel.deviceUDID)
                    .autocorrectionDisabled()
            } header: {
                Text(appState.localizationManager.strings.targetApp)
            }
            
            Section {
                Toggle(appState.localizationManager.strings.autoPurchaseLicense, isOn: $viewModel.shouldAutoPurchase)
            } header: {
                Text(appState.localizationManager.strings.options)
            }
            
            Section {
                Button(action: { viewModel.install() }) {
                    HStack {
                        if viewModel.isInstalling {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Label(appState.localizationManager.strings.installToDevice, systemImage: "arrow.down.to.line.circle")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isInstalling || !validateInput())
            }
            
            if let message = viewModel.installSuccessMessage {
                Section {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } header: {
                    Text(appState.localizationManager.strings.status)
                }
            }
            
            if let error = viewModel.activeError {
                Section {
                    Text(error.localizedDescription)
                        .font(.callout)
                        .foregroundStyle(.red)
                } header: {
                    Text(appState.localizationManager.strings.error)
                }
            }
        }
    }
    
    private func validateInput() -> Bool {
        let appID = viewModel.appIDString.trimmingCharacters(in: .whitespacesAndNewlines)
        let bundleID = viewModel.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        return ValidationHelpers.isValidAppIDOrBundleID(appID: appID, bundleID: bundleID)
    }
}
