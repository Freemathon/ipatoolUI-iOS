import SwiftUI
import Combine

enum Feature: String, CaseIterable, Identifiable {
    case auth
    case search
    case purchase
    case listVersions
    case download
    case metadata
    case logs
    case settings
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auth: return "Authentication"
        case .search: return "Search"
        case .purchase: return "Purchase"
        case .listVersions: return "Versions"
        case .download: return "Download"
        case .metadata: return "Version Metadata"
        case .logs: return "Logs"
        case .settings: return "Settings"
        case .about: return "About"
        }
    }

    var icon: String {
        switch self {
        case .auth: return "person.badge.key"
        case .search: return "magnifyingglass"
        case .purchase: return "cart"
        case .listVersions: return "list.number"
        case .download: return "arrow.down.circle"
        case .metadata: return "info.circle"
        case .logs: return "note.text"
        case .settings: return "gear"
        case .about: return "info.square"
        }
    }
}

struct Preferences: Codable, Equatable {
    enum OutputFormat: String, Codable, CaseIterable, Identifiable {
        case text
        case json

        var id: String { rawValue }
    }

    var ipatoolPath: String
    var nonInteractive: Bool
    var verboseLogs: Bool
    var outputFormat: OutputFormat
    var keychainPassphrase: String
    var selectedCountryCode: String? // User-selected locale (nil means auto-detect)

    static let `default` = Preferences(
        ipatoolPath: IpatoolService.defaultExecutablePath ?? "/usr/local/bin/ipatool",
        nonInteractive: true,
        verboseLogs: false,
        outputFormat: .json,
        keychainPassphrase: "",
        selectedCountryCode: nil
    )
}

struct CommandEnvironment {
    let service: IpatoolService
    let preferences: Preferences
    let logger: CommandLogger
}

@MainActor
final class AppState: ObservableObject {
    @Published var preferences: Preferences {
        didSet {
            PreferencesStore.shared.save(preferences)
            // Defer update to avoid publishing during view updates
            DispatchQueue.main.async { [weak self] in
                self?.updateEffectiveCountryCode()
            }
        }
    }

    @Published var selectedFeature: Feature = .auth
    @Published var accountCountryCode: String? = nil
    @Published var effectiveCountryCode: String? = nil
    
    private var systemCountryCode: String? = nil

    let service = IpatoolService()
    let commandLogger = CommandLogger()
    let authViewModel = AuthViewModel()
    let searchViewModel = SearchViewModel()
    let downloadViewModel = DownloadViewModel()
    let listVersionsViewModel = ListVersionsViewModel()
    let versionMetadataViewModel = VersionMetadataViewModel()

    init() {
        preferences = PreferencesStore.shared.load()
        
        // Set initial country code from system locale
        systemCountryCode = Self.getSystemCountryCode()
        accountCountryCode = systemCountryCode
        updateEffectiveCountryCode()

        Task { [weak self] in
            guard let self else { return }
            self.authViewModel.bootstrap(using: self.environmentSnapshot())
        }
        
        // Monitor account country code and reflect to AppState (if obtained from ipatool)
        authViewModel.$countryCode
            .compactMap { $0 } // Ignore nil values
            .assign(to: &$accountCountryCode)
        
        // Update effective country code when preferences or account country code changes
        $preferences
            .map { $0.selectedCountryCode }
            .removeDuplicates()
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateEffectiveCountryCode()
                }
            }
            .store(in: &cancellables)
        
        $accountCountryCode
            .removeDuplicates()
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateEffectiveCountryCode()
                }
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private func updateEffectiveCountryCode() {
        // Effective country code to use (selected locale > account locale > system locale)
        if let selected = preferences.selectedCountryCode, !selected.isEmpty {
            effectiveCountryCode = selected
        } else if let account = accountCountryCode, !account.isEmpty {
            effectiveCountryCode = account
        } else {
            effectiveCountryCode = systemCountryCode ?? Self.getSystemCountryCode()
        }
    }
    
    /// Get country code from system locale
    private static func getSystemCountryCode() -> String? {
        // First, try to get country code from current locale (macOS 13+)
        if #available(macOS 13.0, *) {
            if let regionCode = Locale.current.region?.identifier {
                return regionCode
            }
        }
        
        // Fallback: Extract country code from locale identifier
        let localeIdentifier = Locale.current.identifier
        if let range = localeIdentifier.range(of: "_") {
            let countryCode = String(localeIdentifier[range.upperBound...])
            if countryCode.count == 2 {
                return countryCode.uppercased()
            }
        }
        
        // Further fallback: Guess from language settings
        if let preferredLanguage = Locale.preferredLanguages.first {
            let components = preferredLanguage.components(separatedBy: "-")
            if components.count >= 2, components[1].count == 2 {
                return components[1].uppercased()
            }
        }
        
        return nil
    }

    func environmentSnapshot() -> CommandEnvironment {
        CommandEnvironment(service: service, preferences: preferences, logger: commandLogger)
    }
}

struct PreferencesStore {
    static let shared = PreferencesStore()

    private let storageKey = "com.dave.ipatoolui.preferences"

    func load() -> Preferences {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode(Preferences.self, from: data)
        else {
            return Preferences.default
        }

        return decoded
    }

    func save(_ preferences: Preferences) {
        guard let data = try? JSONEncoder().encode(preferences) else {
            return
        }

        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
