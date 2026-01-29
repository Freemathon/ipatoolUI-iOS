import SwiftUI

struct VersionMetadataView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: VersionMetadataViewModel
    
    init(viewModel: VersionMetadataViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        Form {
            Section {
                TextField(appState.localizationManager.strings.versionID, text: $viewModel.versionID)
                    .autocorrectionDisabled()
                
                TextField(appState.localizationManager.strings.appID, text: $viewModel.appIDString)
                
                TextField(appState.localizationManager.strings.bundleID, text: $viewModel.bundleID)
                    .autocorrectionDisabled()
            } header: {
                Text(appState.localizationManager.strings.information)
            } footer: {
                Text(appState.localizationManager.strings.versionIDRequired)
            }
            
            Section {
                Button(action: fetchMetadata) {
                    HStack {
                        if viewModel.isFetching {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(appState.localizationManager.strings.fetchMetadata)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isFetching || !validateInput())
            }
            
            if let status = viewModel.statusMessage {
                Section {
                    Text(status)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } header: {
                    Text(appState.localizationManager.strings.status)
                }
            }
            
            if let error = viewModel.activeError {
                Section {
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.red)
                } header: {
                    Text(appState.localizationManager.strings.error)
                }
            }
            
            if viewModel.displayVersion != nil || viewModel.releaseDate != nil {
                Section {
                    if let displayVersion = viewModel.displayVersion {
                        HStack {
                            Text(appState.localizationManager.strings.displayVersion)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(displayVersion)
                                .font(.body.monospaced())
                        }
                    }
                    
                    if let releaseDate = viewModel.releaseDate {
                        HStack {
                            Text(appState.localizationManager.strings.releaseDate)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(formatDate(releaseDate))
                                .font(.body)
                        }
                    }
                } header: {
                    Text(appState.localizationManager.strings.metadata)
                }
            }
        }
        .formStyle(.grouped)
    }
    
    private func fetchMetadata() {
        viewModel.fetchMetadata()
    }
    
    private func validateInput() -> Bool {
        guard ValidationHelpers.isValidVersionID(viewModel.versionID) else {
            return false
        }
        return ValidationHelpers.isValidAppIDOrBundleID(appID: viewModel.appIDString, bundleID: viewModel.bundleID)
    }
    
    private func formatDate(_ dateString: String) -> String {
        DateFormatterHelper.formatDate(dateString, locale: appState.localizationManager.currentBundleLanguage.locale)
    }
}

struct VersionMetadataView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            VersionMetadataView(viewModel: VersionMetadataViewModel())
        }
    }
}
