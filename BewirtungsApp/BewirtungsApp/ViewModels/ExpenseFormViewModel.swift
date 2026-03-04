import Foundation
import SwiftUI

@Observable
final class ExpenseFormViewModel {
    var isProcessingOCR = false
    var isConvertingCurrency = false
    var errorMessage: String?
}
