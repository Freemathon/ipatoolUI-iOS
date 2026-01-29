package cmd

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/gorilla/mux"
	"github.com/majd/ipatool/v2/pkg/appstore"
	"github.com/majd/ipatool/v2/pkg/log"
)

var version = "dev"

// RunServer starts the HTTP API server with the specified port and optional API key.
// This is the main entry point for the server-only mode.
// The server uses JSON logging format and non-interactive keychain access.
func RunServer(port int, apiKey string) error {
	// Initialize server dependencies with verbose logging enabled
	initServer(true)

	return runServer(port, apiKey)
}

// runServer configures and starts the HTTP server with all API endpoints.
// If the specified port is in use, it automatically uses a random available port.
func runServer(port int, apiKey string) error {
	router := mux.NewRouter()
	router.StrictSlash(true) // allow /api/v1/install and /api/v1/install/
	api := router.PathPrefix("/api/v1").Subrouter()

	if apiKey != "" {
		api.Use(apiKeyMiddleware(apiKey))
	}
	api.Use(corsMiddleware)
	api.Use(rateLimitMiddleware)
	api.Use(loggingMiddleware(dependencies.Logger))
	api.Use(bodySizeLimitMiddleware)

	protectedAPI := api.PathPrefix("").Subrouter()
	protectedAPI.Use(accountInfoMiddleware)

	auth := api.PathPrefix("/auth").Subrouter()
	auth.HandleFunc("/login", handleAuthLogin).Methods("POST")
	auth.HandleFunc("/info", handleAuthInfo).Methods("GET")
	auth.HandleFunc("/revoke", handleAuthRevoke).Methods("POST")

	protectedAPI.HandleFunc("/search", handleSearch).Methods("GET")
	protectedAPI.HandleFunc("/purchase", handlePurchase).Methods("POST")
	protectedAPI.HandleFunc("/versions", handleListVersions).Methods("GET")
	protectedAPI.HandleFunc("/metadata", handleVersionMetadata).Methods("GET")
	protectedAPI.HandleFunc("/download", handleDownload).Methods("POST")
	protectedAPI.HandleFunc("/install", handleInstall).Methods("POST")

	// Health check and root endpoints (no authentication required)
	router.HandleFunc("/health", handleHealth).Methods("GET")
	router.HandleFunc("/", handleRoot).Methods("GET")
	router.NotFoundHandler = http.HandlerFunc(handleNotFound)

	// Configure HTTP server with appropriate timeouts for large file downloads
	addr := fmt.Sprintf(":%d", port)

	// Try to listen on the specified port, or use a random port if it's in use
	listener, actualPort, err := tryListen(addr)
	if err != nil {
		return fmt.Errorf("failed to start server: %w", err)
	}

	// If we're using a different port than requested, log it and write to file
	if actualPort != port {
		dependencies.Logger.Log().Msgf("Port %d is in use, using random port %d instead", port, actualPort)
		// Security: Write port to file for programmatic access
		if portFile := os.Getenv("IPATOOL_PORT_FILE"); portFile != "" {
			if err := os.WriteFile(portFile, []byte(fmt.Sprintf("%d\n", actualPort)), 0644); err != nil {
				dependencies.Logger.Error().Err(err).Msg("Failed to write port to file")
			}
		}
		// Also print to stdout for CLI usage
		fmt.Fprintf(os.Stdout, "Server running on port %d\n", actualPort)
	}

	httpServer := &http.Server{
		Addr:           listener.Addr().String(),
		Handler:        router,
		ReadTimeout:    30 * time.Second,
		WriteTimeout:   2 * time.Hour, // Extended for multi-GB file downloads
		IdleTimeout:    300 * time.Second,
		MaxHeaderBytes: 1 << 20, // 1MB header size limit
	}
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)

	go func() {
		dependencies.Logger.Log().Msgf("Starting ipatool HTTP server on port %d", actualPort)
		if apiKey != "" {
			dependencies.Logger.Log().Msg("API key authentication enabled")
		}
		if err := httpServer.Serve(listener); err != nil && err != http.ErrServerClosed {
			dependencies.Logger.Error().Err(err).Msg("Server error")
			os.Exit(1)
		}
	}()

	<-sigChan

	dependencies.Logger.Log().Msg("Shutting down server...")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := httpServer.Shutdown(ctx); err != nil {
		return fmt.Errorf("error shutting down server: %w", err)
	}

	dependencies.Logger.Log().Msg("Server stopped gracefully")
	return nil
}

// tryListen attempts to listen on the specified address.
// If the port is in use, it automatically uses a random available port.
// Returns the listener, the actual port used, and any error.
func tryListen(addr string) (net.Listener, int, error) {
	// First, try to listen on the specified address
	listener, err := net.Listen("tcp", addr)
	if err == nil {
		// Successfully listening on the requested port
		actualPort := listener.Addr().(*net.TCPAddr).Port
		return listener, actualPort, nil
	}

	// Check if the error is due to port already in use
	if isPortInUseError(err) {
		// Port is in use, try a random port
		randomListener, err := net.Listen("tcp", ":0")
		if err != nil {
			return nil, 0, fmt.Errorf("failed to listen on random port: %w", err)
		}
		actualPort := randomListener.Addr().(*net.TCPAddr).Port
		return randomListener, actualPort, nil
	}

	// Some other error occurred
	return nil, 0, err
}

// isPortInUseError checks if the error indicates that the port is already in use.
func isPortInUseError(err error) bool {
	if err == nil {
		return false
	}
	errStr := err.Error()
	return strings.Contains(errStr, "address already in use") ||
		strings.Contains(errStr, "bind: address already in use") ||
		strings.Contains(errStr, "port is already allocated")
}

// Request and response types for API endpoints

// AuthLoginRequest represents a login request.
type AuthLoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
	AuthCode string `json:"auth_code,omitempty"`
}

// AuthLoginResponse represents a login response.
type AuthLoginResponse struct {
	Success     bool   `json:"success"`
	Email       string `json:"email,omitempty"`
	Name        string `json:"name,omitempty"`
	CountryCode string `json:"country_code,omitempty"`
}

// AuthInfoResponse represents account information response.
type AuthInfoResponse struct {
	Email       string `json:"email,omitempty"`
	Name        string `json:"name,omitempty"`
	CountryCode string `json:"country_code,omitempty"`
}

// SearchResponse represents a search results response.
type SearchResponse struct {
	Count int       `json:"count"`
	Apps  []AppInfo `json:"apps"`
}

type AppInfo struct {
	TrackID    int64   `json:"track_id,omitempty"`
	BundleID   string  `json:"bundle_id,omitempty"`
	Name       string  `json:"name,omitempty"`
	Version    string  `json:"version,omitempty"`
	Price      float64 `json:"price,omitempty"`
	ArtworkURL string  `json:"artwork_url,omitempty"`
}

func appToAppInfo(app appstore.App) AppInfo {
	// Prefer higher resolution artwork URLs, fallback to lower resolution
	artworkURL := app.ArtworkURL512
	if artworkURL == "" {
		artworkURL = app.ArtworkURL100
	}
	if artworkURL == "" {
		artworkURL = app.ArtworkURL60
	}

	return AppInfo{
		TrackID:    app.ID,
		BundleID:   app.BundleID,
		Name:       app.Name,
		Version:    app.Version,
		Price:      app.Price,
		ArtworkURL: artworkURL,
	}
}

type PurchaseRequest struct {
	BundleID string `json:"bundle_id"`
}

type PurchaseResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message,omitempty"`
}

type ListVersionsResponse struct {
	BundleID           string   `json:"bundle_id,omitempty"`
	ExternalVersionIDs []string `json:"external_version_identifiers"`
	Success            bool     `json:"success"`
}

type VersionMetadataResponse struct {
	Success           bool   `json:"success"`
	ExternalVersionID string `json:"external_version_id,omitempty"`
	DisplayVersion    string `json:"display_version,omitempty"`
	ReleaseDate       string `json:"release_date,omitempty"`
}

type DownloadRequest struct {
	AppID             int64  `json:"app_id,omitempty"`
	BundleID          string `json:"bundle_id,omitempty"`
	ExternalVersionID string `json:"external_version_id,omitempty"`
	AutoPurchase      bool   `json:"auto_purchase,omitempty"`
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	respondSuccess(w, map[string]string{
		"status":  "ok",
		"service": "ipatool-api",
	})
}

func handleRoot(w http.ResponseWriter, r *http.Request) {
	respondSuccess(w, map[string]interface{}{
		"service": "ipatool-api",
		"version": version,
		"endpoints": map[string]string{
			"health":           "GET /health",
			"auth_login":       "POST /api/v1/auth/login",
			"auth_info":        "GET /api/v1/auth/info",
			"auth_revoke":      "POST /api/v1/auth/revoke",
			"search":           "GET /api/v1/search",
			"purchase":         "POST /api/v1/purchase",
			"list_versions":    "GET /api/v1/versions",
			"version_metadata": "GET /api/v1/metadata",
			"download":         "POST /api/v1/download",
			"install":          "POST /api/v1/install",
		},
	})
}

func handleNotFound(w http.ResponseWriter, r *http.Request) {
	respondError(w, http.StatusNotFound, fmt.Sprintf("Endpoint not found: %s %s", r.Method, r.URL.Path))
}

func handleAuthLogin(w http.ResponseWriter, r *http.Request) {
	var req AuthLoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	if err := validateEmail(req.Email); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}
	if req.AuthCode != "" {
		if err := validateAuthCode(req.AuthCode); err != nil {
			respondError(w, http.StatusBadRequest, err.Error())
			return
		}
	}

	result, err := dependencies.AppStore.Login(appstore.LoginInput{
		Email:    req.Email,
		Password: req.Password,
		AuthCode: req.AuthCode,
	})
	if err != nil {
		statusCode, message := mapAppStoreErrorToHTTPStatus(err)
		respondError(w, statusCode, message)
		return
	}

	response := AuthLoginResponse{
		Success:     true,
		Email:       result.Account.Email,
		Name:        result.Account.Name,
		CountryCode: result.Account.StoreFront,
	}

	respondSuccess(w, response)
}

func handleAuthInfo(w http.ResponseWriter, r *http.Request) {
	info, err := dependencies.AppStore.AccountInfo()
	if err != nil {
		statusCode, message := mapAppStoreErrorToHTTPStatus(err)
		respondError(w, statusCode, message)
		return
	}

	response := AuthInfoResponse{
		Email:       info.Account.Email,
		Name:        info.Account.Name,
		CountryCode: info.Account.StoreFront,
	}

	respondSuccess(w, response)
}

func handleAuthRevoke(w http.ResponseWriter, r *http.Request) {
	if err := dependencies.AppStore.Revoke(); err != nil {
		statusCode, message := mapAppStoreErrorToHTTPStatus(err)
		respondError(w, statusCode, message)
		return
	}

	respondSuccess(w, map[string]bool{"success": true})
}

func handleSearch(w http.ResponseWriter, r *http.Request) {
	term := r.URL.Query().Get("term")
	if err := validateTerm(term); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	limit, err := validateLimit(r.URL.Query().Get("limit"))
	if err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	countryCode := r.URL.Query().Get("country")
	if err := validateCountryCode(countryCode); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	accountInfo, ok := getAccountInfo(r)
	if !ok {
		respondError(w, http.StatusUnauthorized, "Authentication required")
		return
	}

	result, err := dependencies.AppStore.Search(appstore.SearchInput{
		Account:     accountInfo.Account,
		Term:        term,
		Limit:       limit,
		CountryCode: countryCode,
	})
	if err != nil {
		statusCode, message := mapAppStoreErrorToHTTPStatus(err)
		respondError(w, statusCode, message)
		return
	}

	appInfos := make([]AppInfo, len(result.Results))
	for i, app := range result.Results {
		appInfos[i] = appToAppInfo(app)
	}

	respondSuccess(w, SearchResponse{
		Count: result.Count,
		Apps:  appInfos,
	})
}

func handlePurchase(w http.ResponseWriter, r *http.Request) {
	var req PurchaseRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	if err := validateBundleID(req.BundleID); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	accountInfo, ok := getAccountInfo(r)
	if !ok {
		respondError(w, http.StatusUnauthorized, "Authentication required")
		return
	}

	app := appstore.App{BundleID: req.BundleID}
	err := dependencies.AppStore.Purchase(appstore.PurchaseInput{
		Account: accountInfo.Account,
		App:     app,
	})
	if err != nil {
		dependencies.Logger.Error().
			Err(err).
			Str("bundleID", req.BundleID).
			Str("appID", fmt.Sprintf("%d", app.ID)).
			Msg("Purchase failed")

		statusCode, message := mapAppStoreErrorToHTTPStatus(err)
		respondError(w, statusCode, message)
		return
	}

	respondSuccess(w, PurchaseResponse{
		Success: true,
		Message: "License purchased successfully",
	})
}

func handleListVersions(w http.ResponseWriter, r *http.Request) {
	bundleID := r.URL.Query().Get("bundle_id")
	appIDStr := r.URL.Query().Get("app_id")

	if err := validateAppIDOrBundleID(appIDStr, bundleID); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	accountInfo, ok := getAccountInfo(r)
	if !ok {
		respondError(w, http.StatusUnauthorized, "Authentication required")
		return
	}

	var app appstore.App
	if bundleID != "" {
		lookupResult, err := dependencies.AppStore.Lookup(appstore.LookupInput{
			Account:  accountInfo.Account,
			BundleID: bundleID,
		})
		if err != nil {
			statusCode, message := mapAppStoreErrorToHTTPStatus(err)
			respondError(w, statusCode, message)
			return
		}
		app = lookupResult.App
	} else {
		appID, _ := strconv.ParseInt(appIDStr, 10, 64)
		app = appstore.App{ID: appID}
	}

	result, err := dependencies.AppStore.ListVersions(appstore.ListVersionsInput{
		Account: accountInfo.Account,
		App:     app,
	})
	if err != nil {
		statusCode, message := mapAppStoreErrorToHTTPStatus(err)
		respondError(w, statusCode, message)
		return
	}

	respondSuccess(w, ListVersionsResponse{
		BundleID:           app.BundleID,
		ExternalVersionIDs: result.ExternalVersionIdentifiers,
		Success:            true,
	})
}

func handleVersionMetadata(w http.ResponseWriter, r *http.Request) {
	versionID := r.URL.Query().Get("version_id")
	bundleID := r.URL.Query().Get("bundle_id")
	appIDStr := r.URL.Query().Get("app_id")

	if err := validateVersionID(versionID); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	if err := validateAppIDOrBundleID(appIDStr, bundleID); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	accountInfo, ok := getAccountInfo(r)
	if !ok {
		respondError(w, http.StatusUnauthorized, "Authentication required")
		return
	}

	var app appstore.App
	if appIDStr != "" {
		appID, _ := strconv.ParseInt(appIDStr, 10, 64)
		app.ID = appID
	} else {
		app.BundleID = bundleID
	}

	result, err := dependencies.AppStore.GetVersionMetadata(appstore.GetVersionMetadataInput{
		Account:   accountInfo.Account,
		App:       app,
		VersionID: versionID,
	})
	if err != nil {
		statusCode, message := mapAppStoreErrorToHTTPStatus(err)
		respondError(w, statusCode, message)
		return
	}

	respondSuccess(w, VersionMetadataResponse{
		Success:           true,
		ExternalVersionID: versionID,
		DisplayVersion:    result.DisplayVersion,
		ReleaseDate:       result.ReleaseDate.Format(time.RFC3339),
	})
}

func handleDownload(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Minute)
	defer cancel()
	r = r.WithContext(ctx)

	var req DownloadRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	if err := validateAppIDOrBundleID(fmt.Sprintf("%d", req.AppID), req.BundleID); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	if err := validateExternalVersionID(req.ExternalVersionID); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	accountInfo, ok := getAccountInfo(r)
	if !ok {
		respondError(w, http.StatusUnauthorized, "Authentication required")
		return
	}

	app := buildAppFromRequest(req.AppID, req.BundleID)

	if req.BundleID != "" && app.ID == 0 {
		lookupResult, err := dependencies.AppStore.Lookup(appstore.LookupInput{
			Account:  accountInfo.Account,
			BundleID: req.BundleID,
		})
		if err != nil {
			dependencies.Logger.Error().Err(err).Str("bundleID", req.BundleID).Msg("Lookup failed")
			statusCode, message := mapAppStoreErrorToHTTPStatus(err)
			respondError(w, statusCode, message)
			return
		}
		app = lookupResult.App
	}

	if req.AutoPurchase {
		err := dependencies.AppStore.Purchase(appstore.PurchaseInput{
			Account: accountInfo.Account,
			App:     app,
		})
		if err != nil {
			if !errors.Is(err, appstore.ErrLicenseRequired) {
				dependencies.Logger.Error().Err(err).Msg("AutoPurchase failed")
				statusCode, message := mapAppStoreErrorToHTTPStatus(err)
				respondError(w, statusCode, message)
				return
			}
			dependencies.Logger.Log().Msg("AutoPurchase: License may already be purchased, continuing with download")
		} else {
			dependencies.Logger.Log().Msg("AutoPurchase: License purchased successfully")
		}
	}

	tmpFile, err := os.CreateTemp("", "ipatool-*.ipa")
	if err != nil {
		dependencies.Logger.Error().Err(err).Msg("Failed to create temporary file")
		respondError(w, http.StatusInternalServerError, "Failed to create temporary file")
		return
	}
	tmpPath := tmpFile.Name()
	tmpFile.Close()

	defer func() {
		if err := os.Remove(tmpPath); err != nil {
			dependencies.Logger.Error().Err(err).Str("path", tmpPath).Msg("Failed to remove temporary file")
		}
	}()

	result, err := dependencies.AppStore.Download(appstore.DownloadInput{
		Account:           accountInfo.Account,
		App:               app,
		ExternalVersionID: req.ExternalVersionID,
		OutputPath:        tmpPath,
	})
	if err != nil {
		dependencies.Logger.Error().Err(err).Msg("Download failed")
		statusCode, message := mapAppStoreErrorToHTTPStatus(err)
		respondError(w, statusCode, message)
		return
	}

	file, err := os.Open(result.DestinationPath)
	if err != nil {
		dependencies.Logger.Error().Err(err).Str("path", result.DestinationPath).Msg("Failed to open downloaded file")
		respondError(w, http.StatusInternalServerError, "Failed to open downloaded file")
		return
	}
	defer file.Close()

	filename := generateFilename(app, req.ExternalVersionID)

	fileInfo, err := file.Stat()
	if err != nil {
		dependencies.Logger.Error().Err(err).Str("path", result.DestinationPath).Msg("Failed to stat downloaded file")
		respondError(w, http.StatusInternalServerError, "Failed to get file information")
		return
	}

	setDownloadHeaders(w, filename, fileInfo.Size())

	buffer := make([]byte, 4*1024*1024)
	if _, err := io.CopyBuffer(w, file, buffer); err != nil {
		dependencies.Logger.Error().Err(err).Msg("Error streaming file")
		if err == io.ErrClosedPipe || err == io.EOF {
			return
		}
		if strings.Contains(err.Error(), "timeout") || strings.Contains(err.Error(), "broken pipe") {
			dependencies.Logger.Log().Err(err).Msg("Client disconnected or timeout during file streaming")
			return
		}
		return
	}

	dependencies.Logger.Log().
		Str("filename", filename).
		Int64("size", fileInfo.Size()).
		Msg("File downloaded and streamed successfully")
}

// Session management
var (
	lastActivityTime = make(map[string]time.Time)
	sessionMu        sync.RWMutex
)

func accountInfoMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		accountInfo, err := dependencies.AppStore.AccountInfo()
		if err != nil {
			statusCode, message := mapAppStoreErrorToHTTPStatus(err)
			respondError(w, statusCode, message)
			return
		}

		// Security: Check session timeout
		ip := getClientIP(r)
		sessionMu.Lock()
		lastActivity, exists := lastActivityTime[ip]
		if exists {
			timeSinceLastActivity := time.Since(lastActivity)
			if timeSinceLastActivity > time.Duration(sessionTimeoutHours)*time.Hour {
				// Session expired
				sessionMu.Unlock()
				respondError(w, http.StatusUnauthorized, "Session expired. Please login again.")
				return
			}
		}
		// Update last activity time
		lastActivityTime[ip] = time.Now()
		sessionMu.Unlock()

		ctx := context.WithValue(r.Context(), "accountInfo", accountInfo)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// Cleanup expired sessions
func init() {
	go func() {
		ticker := time.NewTicker(1 * time.Hour)
		defer ticker.Stop()
		for range ticker.C {
			sessionMu.Lock()
			now := time.Now()
			for ip, lastActivity := range lastActivityTime {
				if now.Sub(lastActivity) > time.Duration(sessionTimeoutHours)*time.Hour {
					delete(lastActivityTime, ip)
				}
			}
			sessionMu.Unlock()
		}
	}()
}

func apiKeyMiddleware(apiKey string) mux.MiddlewareFunc {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Security: Only accept API key from header, not from URL query parameter
			key := r.Header.Get("X-API-Key")

			if key == "" || key != apiKey {
				respondError(w, http.StatusUnauthorized, "Invalid API key")
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}

func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")

		// Security: Restrict CORS to allowed origins
		if corsAllowedOrigins == "" {
			// Development mode: allow all origins (backward compatibility)
			w.Header().Set("Access-Control-Allow-Origin", "*")
		} else {
			// Production mode: check against allowed origins
			allowed := strings.Split(corsAllowedOrigins, ",")
			allowedOrigin := ""
			for _, allowedOrig := range allowed {
				if strings.TrimSpace(allowedOrig) == origin {
					allowedOrigin = origin
					break
				}
			}
			if allowedOrigin != "" {
				w.Header().Set("Access-Control-Allow-Origin", allowedOrigin)
			}
			// If origin not allowed, don't set CORS headers (browser will block)
		}

		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, X-API-Key")
		w.Header().Set("Access-Control-Max-Age", "3600")

		// Security headers
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("X-XSS-Protection", "1; mode=block")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusNoContent)
			return
		}

		next.ServeHTTP(w, r)
	})
}

// rateLimitMiddleware implements rate limiting
func rateLimitMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ip := getClientIP(r)
		path := r.URL.Path

		if !globalRateLimiter.isAllowed(ip, path) {
			respondError(w, http.StatusTooManyRequests, "Rate limit exceeded. Please try again later.")
			return
		}

		next.ServeHTTP(w, r)
	})
}

// bodySizeLimitMiddleware limits request body size
func bodySizeLimitMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Limit body size based on endpoint
		var maxSize int64 = 1024 * 1024 // 1MB default

		path := r.URL.Path
		if strings.HasPrefix(path, "/api/v1/download") {
			// Download endpoint might need larger body for metadata
			maxSize = 10 * 1024 * 1024 // 10MB
		} else if strings.HasPrefix(path, "/api/v1/auth/login") {
			// Login endpoint should be small
			maxSize = 2 * 1024 // 2KB
		}

		r.Body = http.MaxBytesReader(w, r.Body, maxSize)
		next.ServeHTTP(w, r)
	})
}

func loggingMiddleware(logger log.Logger) mux.MiddlewareFunc {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			requestID := generateRequestID()
			start := time.Now()
			wrapped := &responseWriter{ResponseWriter: w, statusCode: http.StatusOK}

			ctx := context.WithValue(r.Context(), "requestID", requestID)
			r = r.WithContext(ctx)

			// Security: Mask sensitive data in request URI for logging
			safeURI := maskSensitiveData(r.RequestURI)

			next.ServeHTTP(wrapped, r)

			duration := time.Since(start)
			statusCode := wrapped.statusCode

			if shouldLogRequest(r, statusCode) {
				if statusCode >= 500 {
					logger.Error().
						Str("request_id", requestID).
						Str("method", r.Method).
						Str("path", safeURI).
						Str("ip", getClientIP(r)).
						Int("status", statusCode).
						Dur("duration", duration).
						Msg("Server error")
				} else if statusCode >= 400 {
					logger.Error().
						Str("request_id", requestID).
						Str("method", r.Method).
						Str("path", safeURI).
						Str("ip", getClientIP(r)).
						Int("status", statusCode).
						Dur("duration", duration).
						Msg("Client error")
				} else if statusCode >= 200 && statusCode < 300 {
					if isCriticalEndpoint(r.RequestURI) {
						logger.Log().
							Str("request_id", requestID).
							Str("method", r.Method).
							Str("path", safeURI).
							Int("status", statusCode).
							Dur("duration", duration).
							Msg("Request completed")
					}
				}
			}
		})
	}
}

func shouldLogRequest(r *http.Request, statusCode int) bool {
	path := r.RequestURI

	if strings.Contains(path, ".png") || strings.Contains(path, ".jpg") ||
		strings.Contains(path, ".jpeg") || strings.Contains(path, ".gif") ||
		strings.Contains(path, ".ico") || strings.Contains(path, ".svg") {
		return false
	}

	if path == "/health" && statusCode == 200 {
		return false
	}

	if isCriticalEndpoint(path) {
		return true
	}

	return statusCode >= 400
}

func isCriticalEndpoint(path string) bool {
	criticalPaths := []string{
		"/api/v1/auth/login",
		"/api/v1/auth/info",
		"/api/v1/auth/revoke",
		"/api/v1/search",
		"/api/v1/purchase",
		"/api/v1/download",
		"/api/v1/versions",
		"/api/v1/metadata",
	}

	for _, criticalPath := range criticalPaths {
		if strings.HasPrefix(path, criticalPath) {
			return true
		}
	}

	return false
}

type responseWriter struct {
	http.ResponseWriter
	statusCode int
}

func (rw *responseWriter) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}
