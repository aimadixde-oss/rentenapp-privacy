import SwiftUI

extension Color {
    static let appPrimary = Color(red: 0, green: 0.106, blue: 0.239)    // #001B3D
    static let appAccent = Color(red: 0.788, green: 0.659, blue: 0.298) // #C9A84C
    static let appBackground = Color(red: 0.973, green: 0.976, blue: 0.98) // #f8f9fa
}

extension Double {
    var formattedEUR: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: NSNumber(value: self)) ?? "0,00 €"
    }

    var formatted2Decimals: String {
        String(format: "%.2f", self)
    }
}

extension Date {
    var germanFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: self)
    }
}

extension View {
    func formSectionStyle() -> some View {
        self
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

struct LabeledFormField: View {
    let label: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(label, text: $text)
                .keyboardType(keyboardType)
                .textFieldStyle(.roundedBorder)
        }
    }
}
