import Foundation
import Combine

@MainActor
final class InstallViewModel: BaseViewModel {
    @Published var appIDString: String = ""
    @Published var bundleIdentifier: String = ""
    @Published var externalVersionID: String = ""
    @Published var deviceUDID: String = ""
    @Published var shouldAutoPurchase: Bool = false
    @Published var isInstalling: Bool = false
    @Published var installSuccessMessage: String?
    
    func install() {
        guard ValidationHelpers.isValidAppIDOrBundleID(appID: appIDString, bundleID: bundleIdentifier) else {
            activeError = .serverError(400, localizationManager.strings.appIDOrBundleIDRequiredError)
            return
        }
        
        isInstalling = true
        isLoading = true
        clearError()
        statusMessage = nil
        installSuccessMessage = nil
        
        Task { [weak self] in
            guard let self else { return }
            do {
                let appID = Int64(self.appIDString)
                _ = try await apiService.install(
                    bundleID: self.bundleIdentifier.isEmpty ? nil : self.bundleIdentifier,
                    appID: appID,
                    externalVersionID: self.externalVersionID.isEmpty ? nil : self.externalVersionID,
                    autoPurchase: self.shouldAutoPurchase,
                    deviceUDID: self.deviceUDID.isEmpty ? nil : self.deviceUDID
                )
                self.installSuccessMessage = self.localizationManager.strings.installedSuccessfully
            } catch {
                self.handleError(error)
            }
            
            self.isInstalling = false
            self.isLoading = false
        }
    }
}
