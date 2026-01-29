import Foundation

@MainActor
final class APIService {
    static let shared = APIService()
    
    private var _baseURL: String?
    private var _apiKey: String?
    
    var baseURL: String {
        _baseURL ?? PreferencesStore.shared.load().apiBaseURL
    }
    
    var apiKey: String? {
        if let key = _apiKey {
            return key.isEmpty ? nil : key
        }
        let key = PreferencesStore.shared.load().apiKey
        return key.isEmpty ? nil : key
    }
    
    private let session: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 7200
        config.httpMaximumConnectionsPerHost = 6
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.waitsForConnectivity = true
        config.networkServiceType = .video
        config.httpShouldSetCookies = true
        config.urlCache = nil
        self.session = URLSession(configuration: config)
    }
    
    func updateConfiguration(baseURL: String? = nil, apiKey: String? = nil) {
        if let baseURL = baseURL {
            _baseURL = baseURL
        }
        if let apiKey = apiKey {
            _apiKey = apiKey
        }
    }
    
    // MARK: - Authentication
    
    func login(email: String, password: String, authCode: String?) async throws -> AuthLoginResponse {
        let url = try buildURL(path: "/api/v1/auth/login")
        var body: [String: Any] = [
            "email": email,
            "password": password
        ]
        if let authCode = authCode, !authCode.isEmpty {
            body["auth_code"] = authCode
        }
        let request = try buildRequest(url: url, method: "POST", body: body)
        return try await performRequest(request, responseType: AuthLoginResponse.self)
    }
    
    func getAuthInfo() async throws -> AuthInfoResponse {
        let url = try buildURL(path: "/api/v1/auth/info")
        let request = try buildRequest(url: url, method: "GET")
        return try await performRequest(request, responseType: AuthInfoResponse.self)
    }
    
    func revokeAuth() async throws {
        let url = try buildURL(path: "/api/v1/auth/revoke")
        let request = try buildRequest(url: url, method: "POST")
        let (_, response) = try await session.data(for: request)
        try await validateResponse(response, data: Data())
    }
    
    // MARK: - Search & Purchase
    
    func search(term: String, limit: Int = 25, countryCode: String? = nil) async throws -> SearchResponse {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let countryCode = countryCode, !countryCode.isEmpty {
            queryItems.append(URLQueryItem(name: "country", value: countryCode))
        }
        let url = try buildURL(path: "/api/v1/search", queryItems: queryItems)
        let request = try buildRequest(url: url, method: "GET")
        return try await performRequest(request, responseType: SearchResponse.self)
    }
    
    func purchase(bundleID: String) async throws -> PurchaseResponse {
        let url = try buildURL(path: "/api/v1/purchase")
        let body = ["bundle_id": bundleID]
        let request = try buildRequest(url: url, method: "POST", body: body)
        return try await performRequest(request, responseType: PurchaseResponse.self)
    }
    
    // MARK: - Versions & Metadata
    
    func listVersions(bundleID: String? = nil, appID: Int64? = nil) async throws -> ListVersionsResponse {
        var queryItems: [URLQueryItem] = []
        if let bundleID = bundleID {
            queryItems.append(URLQueryItem(name: "bundle_id", value: bundleID))
        }
        if let appID = appID {
            queryItems.append(URLQueryItem(name: "app_id", value: String(appID)))
        }
        let url = try buildURL(path: "/api/v1/versions", queryItems: queryItems.isEmpty ? nil : queryItems)
        let request = try buildRequest(url: url, method: "GET")
        return try await performRequest(request, responseType: ListVersionsResponse.self)
    }
    
    func getVersionMetadata(versionID: String, bundleID: String? = nil, appID: Int64? = nil) async throws -> VersionMetadataResponse {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "version_id", value: versionID)
        ]
        if let bundleID = bundleID {
            queryItems.append(URLQueryItem(name: "bundle_id", value: bundleID))
        }
        if let appID = appID {
            queryItems.append(URLQueryItem(name: "app_id", value: String(appID)))
        }
        let url = try buildURL(path: "/api/v1/metadata", queryItems: queryItems)
        let request = try buildRequest(url: url, method: "GET")
        return try await performRequest(request, responseType: VersionMetadataResponse.self)
    }
    
    // MARK: - Install
    
    func install(
        bundleID: String? = nil,
        appID: Int64? = nil,
        externalVersionID: String? = nil,
        autoPurchase: Bool = false,
        deviceUDID: String? = nil
    ) async throws -> InstallResponse {
        let url = try buildURL(path: "/api/v1/install")
        var body: [String: Any] = [:]
        if let bundleID = bundleID {
            body["bundle_id"] = bundleID
        }
        if let appID = appID {
            body["app_id"] = appID
        }
        if let externalVersionID = externalVersionID {
            body["external_version_id"] = externalVersionID
        }
        body["auto_purchase"] = autoPurchase
        if let deviceUDID = deviceUDID, !deviceUDID.isEmpty {
            body["device_udid"] = deviceUDID
        }
        let request = try buildRequest(url: url, method: "POST", body: body)
        return try await performRequest(request, responseType: InstallResponse.self)
    }
    
    // MARK: - Download
    
    func download(
        bundleID: String? = nil,
        appID: Int64? = nil,
        externalVersionID: String? = nil,
        autoPurchase: Bool = false,
        progressHandler: @escaping (Int64, Int64?) -> Void
    ) async throws -> (data: Data, filename: String) {
        let (fileURL, filename) = try await downloadToFile(
            bundleID: bundleID,
            appID: appID,
            externalVersionID: externalVersionID,
            autoPurchase: autoPurchase,
            progressHandler: progressHandler
        )
        
        let data = try Data(contentsOf: fileURL)
        try? FileManager.default.removeItem(at: fileURL)
        
        return (data, filename)
    }
    
    func downloadToFile(
        bundleID: String? = nil,
        appID: Int64? = nil,
        externalVersionID: String? = nil,
        autoPurchase: Bool = false,
        progressHandler: @escaping (Int64, Int64?) -> Void
    ) async throws -> (fileURL: URL, filename: String) {
        let url = try buildURL(path: "/api/v1/download")
        var body: [String: Any] = [:]
        if let bundleID = bundleID {
            body["bundle_id"] = bundleID
        }
        if let appID = appID {
            body["app_id"] = appID
        }
        if let externalVersionID = externalVersionID {
            body["external_version_id"] = externalVersionID
        }
        body["auto_purchase"] = autoPurchase
        
        var request = try buildRequest(url: url, method: "POST", body: body)
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        let (asyncBytes, response) = try await session.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            var errorData = Data()
            for try await byte in asyncBytes {
                errorData.append(byte)
            }
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: errorData) {
                throw APIError.serverError(httpResponse.statusCode, errorResponse.message ?? errorResponse.error)
            }
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let contentLength = httpResponse.value(forHTTPHeaderField: "Content-Length")
            .flatMap { Int64($0) }
        
        let contentDisposition = httpResponse.value(forHTTPHeaderField: "Content-Disposition")
        let filename = extractFilename(from: contentDisposition) ?? "app.ipa"
        
        let fileManagerService = FileManagerService.shared
        let tempFileURL = try fileManagerService.createTempFile(extension: "ipa")
        
        guard let fileHandle = try? FileHandle(forWritingTo: tempFileURL) else {
            throw APIError.networkError(NSError(domain: "APIService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to create temporary file"]))
        }
        defer { try? fileHandle.close() }
        
        var downloadedBytes: Int64 = 0
        var buffer = [UInt8]()
        buffer.reserveCapacity(4 * 1024 * 1024)
        
        for try await byte in asyncBytes {
            buffer.append(byte)
            downloadedBytes += 1
            
            if buffer.count >= 4 * 1024 * 1024 {
                let chunkData = Data(buffer)
                try fileHandle.write(contentsOf: chunkData)
                buffer.removeAll(keepingCapacity: true)
                
                if downloadedBytes % (2 * 1024 * 1024) == 0 {
                    progressHandler(downloadedBytes, contentLength)
                }
            }
        }
        
        if !buffer.isEmpty {
            let chunkData = Data(buffer)
            try fileHandle.write(contentsOf: chunkData)
        }
        
        try fileHandle.synchronize()
        progressHandler(downloadedBytes, contentLength)
        
        return (tempFileURL, filename)
    }
    
    // MARK: - Request Builders
    
    private func buildURL(path: String, queryItems: [URLQueryItem]? = nil) throws -> URL {
        // Security: Validate base URL before use
        guard isValidURL(baseURL) else {
            throw APIError.networkError(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid base URL format"]))
        }
        
        guard var components = URLComponents(string: "\(baseURL)\(path)") else {
            throw APIError.networkError(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL: \(baseURL)"]))
        }
        
        if let queryItems = queryItems {
            components.queryItems = queryItems
        }
        
        guard let url = components.url else {
            throw APIError.networkError(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
        }
        
        // Security: Additional URL validation
        guard isValidURL(url.absoluteString) else {
            throw APIError.networkError(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL format"]))
        }
        
        return url
    }
    
    // Security: Validate URL format
    private func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else {
            return false
        }
        
        // Must have a scheme (http or https)
        guard let scheme = url.scheme?.lowercased() else {
            return false
        }
        
        // Only allow http and https schemes
        guard scheme == "http" || scheme == "https" else {
            return false
        }
        
        // Must have a host
        guard url.host != nil else {
            return false
        }
        
        // For localhost/127.0.0.1, allow http
        // For other hosts, prefer https (but allow http for development)
        let host = url.host!.lowercased()
        if host == "localhost" || host == "127.0.0.1" || host.hasPrefix("192.168.") || host.hasPrefix("10.") || host.hasPrefix("172.") {
            // Local network - http is acceptable
            return true
        }
        
        // For remote hosts, https is recommended but not enforced (user's choice)
        return true
    }
    
    private func buildRequest(url: URL, method: String, body: [String: Any]? = nil) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // Set API key header if available
        if let apiKey = apiKey {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }
        
        // Set body for POST/PUT requests
        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        return request
    }
    
    private func performRequest<T: Decodable>(_ request: URLRequest, responseType: T.Type) async throws -> T {
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    // MARK: - Helpers
    
    private func validateResponse(_ response: URLResponse, data: Data) async throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(httpResponse.statusCode, errorResponse.message ?? errorResponse.error)
            }
            throw APIError.httpError(httpResponse.statusCode)
        }
    }
    
    private func extractFilename(from contentDisposition: String?) -> String? {
        guard let contentDisposition = contentDisposition else { return nil }
        
        // Content-Disposition: attachment; filename="app.ipa"
        if let range = contentDisposition.range(of: "filename=\"([^\"]+)\"", options: .regularExpression) {
            let filename = String(contentDisposition[range])
                .replacingOccurrences(of: "filename=\"", with: "")
                .replacingOccurrences(of: "\"", with: "")
            return filename
        }
        
        return nil
    }
}

// MARK: - エラー型

enum APIError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case serverError(Int, String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
