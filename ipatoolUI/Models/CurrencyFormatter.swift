import Foundation

struct CurrencyFormatter {
    /// Get currency symbol from country code
    static func currencySymbol(for countryCode: String?) -> String {
        // First, try to get from CountryCode list
        if let code = countryCode, let country = CountryCode.find(by: code) {
            return country.currencySymbol
        }
        
        // Fallback: Try to get currency symbol using Locale
        guard let countryCode = countryCode?.uppercased() else {
            return "$" // Default to dollar
        }
        
        let locale = Locale(identifier: "\(countryCode.lowercased())_\(countryCode.uppercased())")
        if #available(macOS 13.0, *) {
            if let currencyIdentifier = locale.currency?.identifier,
               let symbol = Locale.current.localizedString(forCurrencyCode: currencyIdentifier) {
                return symbol
            }
        } else {
            // Compatibility for macOS < 13
            if let currencyCode = locale.currencyCode,
               let symbol = Locale.current.localizedString(forCurrencyCode: currencyCode) {
                return symbol
            }
        }
        return "$" // Fallback
    }
    
    /// Format price for display
    static func formatPrice(_ price: Double, countryCode: String?) -> String {
        let symbol = currencySymbol(for: countryCode)
        return String(format: "\(symbol)%.2f", price)
    }
}

