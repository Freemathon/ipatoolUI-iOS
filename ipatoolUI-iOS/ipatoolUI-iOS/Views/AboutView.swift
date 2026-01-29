import SwiftUI

struct AboutView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 16) {
                        Image("AboutAppIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 13))
                        
                        Text("ipatool UI")
                            .font(.title2.bold())
                        
                        Text(appState.localizationManager.strings.iosVersion)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("\(appState.localizationManager.strings.aboutAuthor): \(appState.localizationManager.strings.aboutAuthorName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(appState.localizationManager.strings.appDescription)
                        .font(.body)
                    
                    Text(appState.localizationManager.strings.aboutFeatures)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            } header: {
                Text(appState.localizationManager.strings.overview)
            }
            
            Section {
                Link(appState.localizationManager.strings.aboutLinkIpatoolAPI, destination: URL(string: "https://github.com/Freemathon/ipatoolUI-iOS")!)
            } header: {
                Text(appState.localizationManager.strings.links)
            }
            
            Section {
                Link(appState.localizationManager.strings.aboutLinkIpatool, destination: URL(string: "https://github.com/majd/ipatool")!)
                Link(appState.localizationManager.strings.aboutLinkIpatoolUIMac, destination: URL(string: "https://github.com/davefiorino/ipatoolUI")!)
            } header: {
                Text(appState.localizationManager.strings.aboutSpecialThanks)
            }
        }
        .formStyle(.grouped)
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            AboutView()
        }
    }
}
