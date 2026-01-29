import Foundation
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case japanese = "ja"
    case english = "en"
    case chinese = "zh-Hans"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .japanese: return "日本語"
        case .english: return "English"
        case .chinese: return "简体中文"
        }
    }
    
    var locale: Locale {
        Locale(identifier: rawValue)
    }
}

// Uses NSLocalizedString so language follows Settings → [App] → Language (or system language).
struct LocalizedStrings {
    var search: String { NSLocalizedString("search", comment: "") }
    var settings: String { NSLocalizedString("settings", comment: "") }
    var cancel: String { NSLocalizedString("cancel", comment: "") }
    var ok: String { NSLocalizedString("ok", comment: "") }
    var copy: String { NSLocalizedString("copy", comment: "") }
    var authentication: String { NSLocalizedString("authentication", comment: "") }
    var purchase: String { NSLocalizedString("purchase", comment: "") }
    var versions: String { NSLocalizedString("versions", comment: "") }
    var download: String { NSLocalizedString("download", comment: "") }
    var install: String { NSLocalizedString("install", comment: "") }
    var installToSimulator: String { NSLocalizedString("installToSimulator", comment: "") }
    var installToDevice: String { NSLocalizedString("installToDevice", comment: "") }
    var installDeviceNote: String { NSLocalizedString("installDeviceNote", comment: "") }
    var installedSuccessfully: String { NSLocalizedString("installedSuccessfully", comment: "") }
    var shareFile: String { NSLocalizedString("shareFile", comment: "") }
    var deleteFile: String { NSLocalizedString("deleteFile", comment: "") }
    var fileDeleted: String { NSLocalizedString("fileDeleted", comment: "") }
    var deleteIPAAfterShare: String { NSLocalizedString("deleteIPAAfterShare", comment: "") }
    var deleteIPAAfterShareFooter: String { NSLocalizedString("deleteIPAAfterShareFooter", comment: "") }
    var downloadedFiles: String { NSLocalizedString("downloadedFiles", comment: "") }
    var deleteAll: String { NSLocalizedString("deleteAll", comment: "") }
    var allIPAsDeleted: String { NSLocalizedString("allIPAsDeleted", comment: "") }
    var versionMetadata: String { NSLocalizedString("versionMetadata", comment: "") }
    var logs: String { NSLocalizedString("logs", comment: "") }
    var about: String { NSLocalizedString("about", comment: "") }
    var email: String { NSLocalizedString("email", comment: "") }
    var password: String { NSLocalizedString("password", comment: "") }
    var authCode: String { NSLocalizedString("authCode", comment: "") }
    var login: String { NSLocalizedString("login", comment: "") }
    var logout: String { NSLocalizedString("logout", comment: "") }
    var revoke: String { NSLocalizedString("revoke", comment: "") }
    var searchTerm: String { NSLocalizedString("searchTerm", comment: "") }
    var limit: String { NSLocalizedString("limit", comment: "") }
    var searchResults: String { NSLocalizedString("searchResults", comment: "") }
    var copyBundleID: String { NSLocalizedString("copyBundleID", comment: "") }
    var copyVersion: String { NSLocalizedString("copyVersion", comment: "") }
    var purchased: String { NSLocalizedString("purchased", comment: "") }
    var purchaseButton: String { NSLocalizedString("purchaseButton", comment: "") }
    var serverSettings: String { NSLocalizedString("serverSettings", comment: "") }
    var apiBaseURL: String { NSLocalizedString("apiBaseURL", comment: "") }
    var apiKey: String { NSLocalizedString("apiKey", comment: "") }
    var resetToDefault: String { NSLocalizedString("resetToDefault", comment: "") }
    var languageLabel: String { NSLocalizedString("languageLabel", comment: "") }
    var autoSystem: String { NSLocalizedString("autoSystem", comment: "") }
    var currencyDisplay: String { NSLocalizedString("currencyDisplay", comment: "") }
    var locale: String { NSLocalizedString("locale", comment: "") }
    var autoSystemAccount: String { NSLocalizedString("autoSystemAccount", comment: "") }
    var selected: String { NSLocalizedString("selected", comment: "") }
    var using: String { NSLocalizedString("using", comment: "") }
    var version: String { NSLocalizedString("version", comment: "") }
    var unknown: String { NSLocalizedString("unknown", comment: "") }
    var appID: String { NSLocalizedString("appID", comment: "") }
    var bundleID: String { NSLocalizedString("bundleID", comment: "") }
    var externalVersionIDOptional: String { NSLocalizedString("externalVersionIDOptional", comment: "") }
    var versionID: String { NSLocalizedString("versionID", comment: "") }
    var twoFactorAuthCodeOptional: String { NSLocalizedString("twoFactorAuthCodeOptional", comment: "") }
    var targetApp: String { NSLocalizedString("targetApp", comment: "") }
    var appInfo: String { NSLocalizedString("appInfo", comment: "") }
    var information: String { NSLocalizedString("information", comment: "") }
    var options: String { NSLocalizedString("options", comment: "") }
    var status: String { NSLocalizedString("status", comment: "") }
    var error: String { NSLocalizedString("error", comment: "") }
    var note: String { NSLocalizedString("note", comment: "") }
    var versionList: String { NSLocalizedString("versionList", comment: "") }
    var metadata: String { NSLocalizedString("metadata", comment: "") }
    var displayVersion: String { NSLocalizedString("displayVersion", comment: "") }
    var releaseDate: String { NSLocalizedString("releaseDate", comment: "") }
    var noLogsYet: String { NSLocalizedString("noLogsYet", comment: "") }
    var clearLogs: String { NSLocalizedString("clearLogs", comment: "") }
    var iosVersion: String { NSLocalizedString("iosVersion", comment: "") }
    var overview: String { NSLocalizedString("overview", comment: "") }
    var links: String { NSLocalizedString("links", comment: "") }
    var appleID: String { NSLocalizedString("appleID", comment: "") }
    var signIn: String { NSLocalizedString("signIn", comment: "") }
    var accountInfo: String { NSLocalizedString("accountInfo", comment: "") }
    var deleteAuth: String { NSLocalizedString("deleteAuth", comment: "") }
    var downloadIPA: String { NSLocalizedString("downloadIPA", comment: "") }
    var autoPurchaseLicense: String { NSLocalizedString("autoPurchaseLicense", comment: "") }
    var fetchVersions: String { NSLocalizedString("fetchVersions", comment: "") }
    var fetchMetadata: String { NSLocalizedString("fetchMetadata", comment: "") }
    var downloaded: String { NSLocalizedString("downloaded", comment: "") }
    var appIDOrBundleIDRequired: String { NSLocalizedString("appIDOrBundleIDRequired", comment: "") }
    var versionIDRequired: String { NSLocalizedString("versionIDRequired", comment: "") }
    var enterBundleIDToPurchase: String { NSLocalizedString("enterBundleIDToPurchase", comment: "") }
    var appDescription: String { NSLocalizedString("appDescription", comment: "") }
    var aboutFeatures: String { NSLocalizedString("aboutFeatures", comment: "") }
    var aboutLinkIpatoolAPI: String { NSLocalizedString("aboutLinkIpatoolAPI", comment: "") }
    var aboutSpecialThanks: String { NSLocalizedString("aboutSpecialThanks", comment: "") }
    var aboutLinkIpatool: String { NSLocalizedString("aboutLinkIpatool", comment: "") }
    var aboutLinkIpatoolUIMac: String { NSLocalizedString("aboutLinkIpatoolUIMac", comment: "") }
    var aboutAuthor: String { NSLocalizedString("aboutAuthor", comment: "") }
    var aboutAuthorName: String { NSLocalizedString("aboutAuthorName", comment: "") }
    var appIDOrBundleIDRequiredError: String { NSLocalizedString("appIDOrBundleIDRequiredError", comment: "") }
    var searchTermRequired: String { NSLocalizedString("searchTermRequired", comment: "") }
    var bundleIDRequired: String { NSLocalizedString("bundleIDRequired", comment: "") }
    var versionIDRequiredError: String { NSLocalizedString("versionIDRequiredError", comment: "") }
    var emailPasswordRequired: String { NSLocalizedString("emailPasswordRequired", comment: "") }
    var fileNotFound: String { NSLocalizedString("fileNotFound", comment: "") }
    var loginFailed: String { NSLocalizedString("loginFailed", comment: "") }
    var purchaseFailed: String { NSLocalizedString("purchaseFailed", comment: "") }
    var fetchVersionsFailed: String { NSLocalizedString("fetchVersionsFailed", comment: "") }
    var fetchMetadataFailed: String { NSLocalizedString("fetchMetadataFailed", comment: "") }
    var unauthenticated: String { NSLocalizedString("unauthenticated", comment: "") }
    var signedInAs: String { NSLocalizedString("signedInAs", comment: "") }
    var activeSession: String { NSLocalizedString("activeSession", comment: "") }
    var authDeleted: String { NSLocalizedString("authDeleted", comment: "") }
    var appsFound: String { NSLocalizedString("appsFound", comment: "") }
    var purchaseSuccess: String { NSLocalizedString("purchaseSuccess", comment: "") }
    var purchaseCompletedNoFlag: String { NSLocalizedString("purchaseCompletedNoFlag", comment: "") }
    var fileSaved: String { NSLocalizedString("fileSaved", comment: "") }
    var versionsFound: String { NSLocalizedString("versionsFound", comment: "") }
    var metadataFetched: String { NSLocalizedString("metadataFetched", comment: "") }
}

// Language is now determined by Settings → [App] → Language (or system language). No in-app language picker.
@MainActor
class LocalizationManager: ObservableObject {
    @Published var strings = LocalizedStrings()
    
    static let shared = LocalizationManager()
    
    private init() {}
    
    /// Current app language from Bundle (for locale/formatting). Change language in Settings → [App] → Language.
    var currentBundleLanguage: AppLanguage {
        let code = Bundle.main.preferredLocalizations.first ?? "en"
        if code.hasPrefix("ja") { return .japanese }
        if code.hasPrefix("zh") { return .chinese }
        return .english
    }
}
