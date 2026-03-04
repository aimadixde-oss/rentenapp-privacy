import Foundation

struct ExchangeRateResult {
    let rate: Double
    let date: String
    let fromCurrency: String
    let toCurrency: String
}

final class CurrencyService {
    static let shared = CurrencyService()

    private let ecbBaseURL = "https://data-api.ecb.europa.eu/service/data/EXR"
    private var cache: [String: ExchangeRateResult] = [:]

    private init() {}

    func convertToEUR(amount: Double, fromCurrency: String, on date: Date? = nil) async throws -> ExchangeRateResult {
        if fromCurrency == "EUR" {
            let dateStr = formatDate(date ?? Date())
            return ExchangeRateResult(rate: 1.0, date: dateStr, fromCurrency: "EUR", toCurrency: "EUR")
        }

        let cacheKey = "\(fromCurrency)_\(formatDate(date ?? Date()))"
        if let cached = cache[cacheKey] {
            return ExchangeRateResult(
                rate: cached.rate,
                date: cached.date,
                fromCurrency: cached.fromCurrency,
                toCurrency: cached.toCurrency
            )
        }

        let rate = try await fetchECBRate(currency: fromCurrency, date: date)
        cache[cacheKey] = rate
        return rate
    }

    private func fetchECBRate(currency: String, date: Date?) async throws -> ExchangeRateResult {
        // ECB Statistical Data Warehouse API
        // Format: EXR/D.{currency}.EUR.SP00.A
        let dateStr = formatDate(date ?? Date())
        let urlString = "\(ecbBaseURL)/D.\(currency).EUR.SP00.A?startPeriod=\(dateStr)&endPeriod=\(dateStr)&format=csvdata"

        guard let url = URL(string: urlString) else {
            throw CurrencyError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CurrencyError.networkError
        }

        if httpResponse.statusCode == 404 {
            // No data for this specific date, try fetching latest
            return try await fetchLatestECBRate(currency: currency)
        }

        guard httpResponse.statusCode == 200 else {
            throw CurrencyError.apiError(statusCode: httpResponse.statusCode)
        }

        guard let csvString = String(data: data, encoding: .utf8) else {
            throw CurrencyError.parsingError
        }

        return try parseCSVRate(csvString, currency: currency)
    }

    private func fetchLatestECBRate(currency: String) async throws -> ExchangeRateResult {
        let urlString = "\(ecbBaseURL)/D.\(currency).EUR.SP00.A?lastNObservations=1&format=csvdata"

        guard let url = URL(string: urlString) else {
            throw CurrencyError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw CurrencyError.networkError
        }

        guard let csvString = String(data: data, encoding: .utf8) else {
            throw CurrencyError.parsingError
        }

        return try parseCSVRate(csvString, currency: currency)
    }

    private func parseCSVRate(_ csv: String, currency: String) throws -> ExchangeRateResult {
        let lines = csv.components(separatedBy: "\n")

        guard lines.count >= 2 else {
            throw CurrencyError.parsingError
        }

        // Find the header line and data line
        let headers = lines[0].components(separatedBy: ",")
        guard let obsValueIndex = headers.firstIndex(where: { $0.contains("OBS_VALUE") }),
              let timePeriodIndex = headers.firstIndex(where: { $0.contains("TIME_PERIOD") }) else {
            throw CurrencyError.parsingError
        }

        let dataLine = lines[1].components(separatedBy: ",")
        guard dataLine.count > max(obsValueIndex, timePeriodIndex) else {
            throw CurrencyError.parsingError
        }

        guard let rate = Double(dataLine[obsValueIndex]) else {
            throw CurrencyError.parsingError
        }

        let datePeriod = dataLine[timePeriodIndex]

        // ECB rate is "1 EUR = X currency", so we need the inverse for "currency to EUR"
        let inverseRate = 1.0 / rate

        return ExchangeRateResult(
            rate: inverseRate,
            date: datePeriod,
            fromCurrency: currency,
            toCurrency: "EUR"
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

enum CurrencyError: LocalizedError {
    case invalidURL
    case networkError
    case apiError(statusCode: Int)
    case parsingError
    case unsupportedCurrency

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Ungültige URL für den Wechselkursdienst."
        case .networkError: return "Netzwerkfehler beim Abrufen des Wechselkurses."
        case .apiError(let code): return "API-Fehler (Status: \(code))."
        case .parsingError: return "Der Wechselkurs konnte nicht gelesen werden."
        case .unsupportedCurrency: return "Diese Währung wird nicht unterstützt."
        }
    }
}
