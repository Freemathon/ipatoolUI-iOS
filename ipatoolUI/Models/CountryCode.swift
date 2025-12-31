import Foundation

struct CountryCode: Identifiable, Hashable {
    let code: String
    let name: String
    let currencySymbol: String
    
    var id: String { code }
    
    static let allCountries: [CountryCode] = [
        // Asia
        CountryCode(code: "JP", name: "Japan (日本)", currencySymbol: "¥"),
        CountryCode(code: "CN", name: "China (中国)", currencySymbol: "¥"),
        CountryCode(code: "KR", name: "South Korea (한국)", currencySymbol: "₩"),
        CountryCode(code: "IN", name: "India (भारत)", currencySymbol: "₹"),
        CountryCode(code: "TH", name: "Thailand (ไทย)", currencySymbol: "฿"),
        CountryCode(code: "SG", name: "Singapore", currencySymbol: "S$"),
        CountryCode(code: "HK", name: "Hong Kong (香港)", currencySymbol: "HK$"),
        CountryCode(code: "TW", name: "Taiwan (台灣)", currencySymbol: "NT$"),
        CountryCode(code: "MY", name: "Malaysia", currencySymbol: "RM"),
        CountryCode(code: "ID", name: "Indonesia", currencySymbol: "Rp"),
        CountryCode(code: "PH", name: "Philippines", currencySymbol: "₱"),
        CountryCode(code: "VN", name: "Vietnam (Việt Nam)", currencySymbol: "₫"),
        
        // Europe
        CountryCode(code: "GB", name: "United Kingdom", currencySymbol: "£"),
        CountryCode(code: "CH", name: "Switzerland (Schweiz)", currencySymbol: "CHF"),
        CountryCode(code: "SE", name: "Sweden (Sverige)", currencySymbol: "kr"),
        CountryCode(code: "NO", name: "Norway (Norge)", currencySymbol: "kr"),
        CountryCode(code: "DK", name: "Denmark (Danmark)", currencySymbol: "kr"),
        CountryCode(code: "PL", name: "Poland (Polska)", currencySymbol: "zł"),
        CountryCode(code: "CZ", name: "Czech Republic (Česká republika)", currencySymbol: "Kč"),
        CountryCode(code: "HU", name: "Hungary (Magyarország)", currencySymbol: "Ft"),
        CountryCode(code: "RO", name: "Romania (România)", currencySymbol: "lei"),
        CountryCode(code: "TR", name: "Turkey (Türkiye)", currencySymbol: "₺"),
        CountryCode(code: "RU", name: "Russia (Россия)", currencySymbol: "₽"),
        
        // Eurozone
        CountryCode(code: "DE", name: "Germany (Deutschland)", currencySymbol: "€"),
        CountryCode(code: "FR", name: "France", currencySymbol: "€"),
        CountryCode(code: "IT", name: "Italy (Italia)", currencySymbol: "€"),
        CountryCode(code: "ES", name: "Spain (España)", currencySymbol: "€"),
        CountryCode(code: "NL", name: "Netherlands (Nederland)", currencySymbol: "€"),
        CountryCode(code: "BE", name: "Belgium (België)", currencySymbol: "€"),
        CountryCode(code: "AT", name: "Austria (Österreich)", currencySymbol: "€"),
        CountryCode(code: "PT", name: "Portugal", currencySymbol: "€"),
        CountryCode(code: "FI", name: "Finland (Suomi)", currencySymbol: "€"),
        CountryCode(code: "IE", name: "Ireland (Éire)", currencySymbol: "€"),
        CountryCode(code: "GR", name: "Greece (Ελλάδα)", currencySymbol: "€"),
        CountryCode(code: "LU", name: "Luxembourg", currencySymbol: "€"),
        CountryCode(code: "SK", name: "Slovakia (Slovensko)", currencySymbol: "€"),
        CountryCode(code: "SI", name: "Slovenia (Slovenija)", currencySymbol: "€"),
        CountryCode(code: "EE", name: "Estonia (Eesti)", currencySymbol: "€"),
        CountryCode(code: "LV", name: "Latvia (Latvija)", currencySymbol: "€"),
        CountryCode(code: "LT", name: "Lithuania (Lietuva)", currencySymbol: "€"),
        CountryCode(code: "MT", name: "Malta", currencySymbol: "€"),
        CountryCode(code: "CY", name: "Cyprus (Κύπρος)", currencySymbol: "€"),
        
        // North America
        CountryCode(code: "US", name: "United States", currencySymbol: "$"),
        CountryCode(code: "CA", name: "Canada", currencySymbol: "C$"),
        CountryCode(code: "MX", name: "Mexico (México)", currencySymbol: "$"),
        
        // South America
        CountryCode(code: "BR", name: "Brazil (Brasil)", currencySymbol: "R$"),
        CountryCode(code: "AR", name: "Argentina", currencySymbol: "$"),
        CountryCode(code: "CL", name: "Chile", currencySymbol: "$"),
        CountryCode(code: "CO", name: "Colombia", currencySymbol: "$"),
        CountryCode(code: "PE", name: "Peru (Perú)", currencySymbol: "S/"),
        
        // Middle East & Africa
        CountryCode(code: "AE", name: "United Arab Emirates (الإمارات)", currencySymbol: "د.إ"),
        CountryCode(code: "SA", name: "Saudi Arabia (السعودية)", currencySymbol: "﷼"),
        CountryCode(code: "IL", name: "Israel (ישראל)", currencySymbol: "₪"),
        CountryCode(code: "ZA", name: "South Africa", currencySymbol: "R"),
        CountryCode(code: "EG", name: "Egypt (مصر)", currencySymbol: "£"),
        
        // Oceania
        CountryCode(code: "AU", name: "Australia", currencySymbol: "A$"),
        CountryCode(code: "NZ", name: "New Zealand", currencySymbol: "NZ$"),
    ]
    
    static func find(by code: String?) -> CountryCode? {
        guard let code = code?.uppercased() else { return nil }
        return allCountries.first { $0.code == code }
    }
}

