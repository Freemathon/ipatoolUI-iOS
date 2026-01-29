import SwiftUI

struct MainView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        TabView(selection: $appState.selectedFeature) {
            ForEach(Feature.allCases) { feature in
                contentView(for: feature)
                    .tabItem {
                        Label(feature.title(using: appState.localizationManager.strings), systemImage: feature.icon)
                    }
                    .tag(feature)
            }
        }
    }
    
    @ViewBuilder
    private func contentView(for feature: Feature) -> some View {
        NavigationStack {
            switch feature {
            case .auth:
                AuthView(viewModel: appState.authViewModel)
                    .navigationTitle(feature.title(using: appState.localizationManager.strings))
            case .search:
                SearchView(viewModel: appState.searchViewModel)
                    .navigationTitle(feature.title(using: appState.localizationManager.strings))
            case .purchase:
                PurchaseView(viewModel: appState.purchaseViewModel)
                    .navigationTitle(feature.title(using: appState.localizationManager.strings))
            case .listVersions:
                ListVersionsView(viewModel: appState.listVersionsViewModel)
                    .navigationTitle(feature.title(using: appState.localizationManager.strings))
            case .download:
                DownloadView(viewModel: appState.downloadViewModel)
                    .navigationTitle(feature.title(using: appState.localizationManager.strings))
            case .install:
                InstallView(viewModel: appState.installViewModel)
                    .navigationTitle(feature.title(using: appState.localizationManager.strings))
            case .metadata:
                VersionMetadataView(viewModel: appState.versionMetadataViewModel)
                    .navigationTitle(feature.title(using: appState.localizationManager.strings))
            case .logs:
                LogsView()
                    .navigationTitle(feature.title(using: appState.localizationManager.strings))
            case .settings:
                SettingsView()
                    .navigationTitle(feature.title(using: appState.localizationManager.strings))
            case .about:
                AboutView()
                    .navigationTitle(feature.title(using: appState.localizationManager.strings))
            }
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
            .environmentObject(AppState())
    }
}
