import Foundation
import Vision
import UIKit

struct ReceiptData {
    var restaurantName: String = ""
    var restaurantAddress: String = ""
    var date: Date?
    var totalAmount: Double = 0
    var currency: String = "EUR"
    var isGerman: Bool = true
}

final class OCRService {
    static let shared = OCRService()

    private init() {}

    func extractReceiptData(from image: UIImage) async throws -> ReceiptData {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        let recognizedText = try await performOCR(on: cgImage)
        return parseReceiptText(recognizedText)
    }

    private func performOCR(on image: CGImage) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let results = request.results as? [VNRecognizedTextObservation] ?? []
                let texts = results.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: texts)
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["de-DE", "en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func parseReceiptText(_ lines: [String]) -> ReceiptData {
        var data = ReceiptData()

        let fullText = lines.joined(separator: "\n")

        // Detect currency
        data.currency = detectCurrency(in: fullText)
        data.isGerman = detectIfGerman(lines: lines, currency: data.currency)

        // Extract restaurant name (usually first non-empty line)
        if let firstLine = lines.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            data.restaurantName = firstLine
        }

        // Extract address (look for patterns with street numbers, PLZ)
        data.restaurantAddress = extractAddress(from: lines)

        // Extract date
        data.date = extractDate(from: fullText)

        // Extract total amount
        data.totalAmount = extractTotalAmount(from: lines, currency: data.currency)

        return data
    }

    private func detectCurrency(in text: String) -> String {
        let currencyPatterns: [(String, String)] = [
            ("\\$", "USD"),
            ("USD", "USD"),
            ("NZD", "NZD"),
            ("AUD", "AUD"),
            ("GBP", "GBP"),
            ("£", "GBP"),
            ("CHF", "CHF"),
            ("€", "EUR"),
            ("EUR", "EUR")
        ]

        for (pattern, currency) in currencyPatterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return currency
            }
        }

        return "EUR"
    }

    private func detectIfGerman(lines: [String], currency: String) -> Bool {
        if currency != "EUR" { return false }

        let germanIndicators = ["MwSt", "USt", "Steuer-Nr", "UID", "DE\\d{9}", "\\d{5}\\s+\\w+"]
        let fullText = lines.joined(separator: " ")

        for pattern in germanIndicators {
            if fullText.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }

        return true // Default to German for EUR
    }

    private func extractAddress(from lines: [String]) -> String {
        let addressPatterns = [
            "\\d+[a-zA-Z]?\\s+\\w+(?:str|straße|weg|platz|allee|gasse)",
            "\\w+(?:str|straße|weg|platz|allee|gasse)\\.?\\s+\\d+",
            "\\d{4,5}\\s+\\w+"
        ]

        var addressParts: [String] = []

        for line in lines {
            for pattern in addressPatterns {
                if line.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                    addressParts.append(line.trimmingCharacters(in: .whitespaces))
                    break
                }
            }
        }

        return addressParts.joined(separator: ", ")
    }

    private func extractDate(from text: String) -> Date? {
        let datePatterns = [
            "\\d{2}\\.\\d{2}\\.\\d{4}",
            "\\d{2}\\.\\d{2}\\.\\d{2}",
            "\\d{2}/\\d{2}/\\d{4}",
            "\\d{4}-\\d{2}-\\d{2}"
        ]

        let dateFormats = [
            "dd.MM.yyyy",
            "dd.MM.yy",
            "dd/MM/yyyy",
            "yyyy-MM-dd"
        ]

        for (pattern, format) in zip(datePatterns, dateFormats) {
            if let range = text.range(of: pattern, options: .regularExpression) {
                let dateString = String(text[range])
                let formatter = DateFormatter()
                formatter.dateFormat = format
                formatter.locale = Locale(identifier: "de_DE")
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
        }

        return nil
    }

    private func extractTotalAmount(from lines: [String], currency: String) -> Double {
        let totalKeywords = ["SUMME", "TOTAL", "GESAMT", "BETRAG", "ZU ZAHLEN", "ENDBETRAG", "GESAMTBETRAG"]

        for line in lines.reversed() {
            let upper = line.uppercased()
            for keyword in totalKeywords {
                if upper.contains(keyword) {
                    if let amount = extractAmount(from: line) {
                        return amount
                    }
                }
            }
        }

        // Fallback: find the largest amount
        var maxAmount: Double = 0
        for line in lines {
            if let amount = extractAmount(from: line), amount > maxAmount {
                maxAmount = amount
            }
        }

        return maxAmount
    }

    private func extractAmount(from text: String) -> Double? {
        // Match patterns like "123,45" or "1.234,56" (German) or "123.45" (English)
        let patterns = [
            "\\d{1,3}(?:\\.\\d{3})*,\\d{2}",  // German: 1.234,56
            "\\d+,\\d{2}",                       // German simple: 123,45
            "\\d{1,3}(?:,\\d{3})*\\.\\d{2}",    // English: 1,234.56
            "\\d+\\.\\d{2}"                       // English simple: 123.45
        ]

        for pattern in patterns {
            if let range = text.range(of: pattern, options: .regularExpression) {
                var amountStr = String(text[range])
                // Normalize to Double-parseable format
                if amountStr.contains(",") && amountStr.contains(".") {
                    if amountStr.lastIndex(of: ",")! > amountStr.lastIndex(of: ".")! {
                        // German format: 1.234,56
                        amountStr = amountStr.replacingOccurrences(of: ".", with: "")
                        amountStr = amountStr.replacingOccurrences(of: ",", with: ".")
                    } else {
                        // English format: 1,234.56
                        amountStr = amountStr.replacingOccurrences(of: ",", with: "")
                    }
                } else if amountStr.contains(",") {
                    amountStr = amountStr.replacingOccurrences(of: ",", with: ".")
                }
                if let value = Double(amountStr) {
                    return value
                }
            }
        }

        return nil
    }
}

enum OCRError: LocalizedError {
    case invalidImage
    case recognitionFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Das Bild konnte nicht verarbeitet werden."
        case .recognitionFailed: return "Die Texterkennung ist fehlgeschlagen."
        }
    }
}
