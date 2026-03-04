import Foundation
import UIKit

final class ExcelExportService {
    static let shared = ExcelExportService()

    private init() {}

    func generateExcel(for report: ExpenseReport) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = report.formattedFileName
        let fileURL = tempDir.appendingPathComponent(fileName)

        // Build XLSX (which is a ZIP of XML files)
        let xlsxBuilder = XLSXBuilder()

        // Map fields to cells according to the specification
        mapReportToExcel(report: report, builder: xlsxBuilder)

        let data = try xlsxBuilder.build()
        try data.write(to: fileURL)

        return fileURL
    }

    private func mapReportToExcel(report: ExpenseReport, builder: XLSXBuilder) {
        // Company checkbox (Row 2-3, Column E)
        if let company = report.selectedCompany {
            switch company {
            case .froneriIceCreamDeutschland:
                builder.setCell("E2", value: "x")
            case .froneriSchoeller:
                builder.setCell("E3", value: "x")
            }
        }

        // Header data
        builder.setCell("B6", value: report.department)          // Abt. / Reg.
        builder.setCell("B7", value: report.name)                // Name (Abrechner)
        builder.setCell("B8", value: report.function)            // Funktion
        builder.setCell("L7", value: report.personalNumber)      // Personal-Nr.
        builder.setCell("E6", value: report.businessUnit)        // Business Unit
        builder.setCell("E7", value: report.subledger)           // Subledger
        builder.setCell("E8", value: report.plant)               // Werk / NL

        // Entertainment details
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy"

        builder.setCell("C16", value: dateFormatter.string(from: report.entertainmentDate))
        builder.setCell("C19", value: "\(report.restaurantName), \(report.restaurantAddress)")
        builder.setCell("C22", value: report.occasion)

        // Participants (C26, C27, ...)
        for (index, participant) in report.participants.enumerated() {
            let row = 26 + index
            let participantText = "\(participant.name) (\(participant.company)) - \(participant.category.displayName)"
            builder.setCell("C\(row)", value: participantText)
        }

        // VAT and amounts
        if report.isGermanReceipt {
            builder.setCell("J33", value: String(format: "%.2f", report.vatRate19))
            builder.setCell("J34", value: String(format: "%.2f", report.vatRate7))
        }
        builder.setCell("J35", value: String(format: "%.2f", report.totalAmount))

        // Accountant
        builder.setCell("R18", value: report.accountantName)
        builder.setCell("R19", value: dateFormatter.string(from: report.accountantDate))

        // Supervisor
        builder.setCell("R25", value: report.supervisorName)
        builder.setCell("R26", value: dateFormatter.string(from: report.supervisorDate))
    }
}

// MARK: - XLSX Builder (creates a minimal .xlsx file from scratch)

final class XLSXBuilder {
    private var cells: [String: String] = [:]

    func setCell(_ reference: String, value: String) {
        cells[reference] = value
    }

    func build() throws -> Data {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Create directory structure
        let xlDir = tempDir.appendingPathComponent("xl")
        let worksheetsDir = xlDir.appendingPathComponent("worksheets")
        let relsDir = tempDir.appendingPathComponent("_rels")
        let xlRelsDir = xlDir.appendingPathComponent("_rels")

        try FileManager.default.createDirectory(at: worksheetsDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: relsDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: xlRelsDir, withIntermediateDirectories: true)

        // [Content_Types].xml
        try contentTypesXML().write(
            to: tempDir.appendingPathComponent("[Content_Types].xml"),
            atomically: true, encoding: .utf8
        )

        // _rels/.rels
        try relsXML().write(
            to: relsDir.appendingPathComponent(".rels"),
            atomically: true, encoding: .utf8
        )

        // xl/workbook.xml
        try workbookXML().write(
            to: xlDir.appendingPathComponent("workbook.xml"),
            atomically: true, encoding: .utf8
        )

        // xl/_rels/workbook.xml.rels
        try workbookRelsXML().write(
            to: xlRelsDir.appendingPathComponent("workbook.xml.rels"),
            atomically: true, encoding: .utf8
        )

        // xl/styles.xml
        try stylesXML().write(
            to: xlDir.appendingPathComponent("styles.xml"),
            atomically: true, encoding: .utf8
        )

        // xl/sharedStrings.xml
        let (sharedStrings, stringIndex) = buildSharedStrings()
        try sharedStrings.write(
            to: xlDir.appendingPathComponent("sharedStrings.xml"),
            atomically: true, encoding: .utf8
        )

        // xl/worksheets/sheet1.xml
        try sheetXML(stringIndex: stringIndex).write(
            to: worksheetsDir.appendingPathComponent("sheet1.xml"),
            atomically: true, encoding: .utf8
        )

        // Create ZIP
        return try createZip(from: tempDir)
    }

    private func contentTypesXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
          <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
          <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
          <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
        </Types>
        """
    }

    private func relsXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
        """
    }

    private func workbookXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
                  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <sheets>
            <sheet name="Bewirtung" sheetId="1" r:id="rId1"/>
          </sheets>
        </workbook>
        """
    }

    private func workbookRelsXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
          <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
          <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>
        </Relationships>
        """
    }

    private func stylesXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <fonts count="2">
            <font><sz val="11"/><name val="Calibri"/></font>
            <font><b/><sz val="11"/><name val="Calibri"/></font>
          </fonts>
          <fills count="2">
            <fill><patternFill patternType="none"/></fill>
            <fill><patternFill patternType="gray125"/></fill>
          </fills>
          <borders count="1">
            <border>
              <left/><right/><top/><bottom/><diagonal/>
            </border>
          </borders>
          <cellStyleXfs count="1">
            <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
          </cellStyleXfs>
          <cellXfs count="2">
            <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
            <xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>
          </cellXfs>
        </styleSheet>
        """
    }

    private func buildSharedStrings() -> (String, [String: Int]) {
        let uniqueStrings = Array(Set(cells.values)).sorted()
        var index: [String: Int] = [:]
        for (i, str) in uniqueStrings.enumerated() {
            index[str] = i
        }

        let siEntries = uniqueStrings.map { str in
            "  <si><t>\(escapeXML(str))</t></si>"
        }.joined(separator: "\n")

        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="\(cells.count)" uniqueCount="\(uniqueStrings.count)">
        \(siEntries)
        </sst>
        """

        return (xml, index)
    }

    private func sheetXML(stringIndex: [String: Int]) -> String {
        // Sort cells by row then column
        let sortedCells = cells.keys.sorted { ref1, ref2 in
            let (col1, row1) = parseReference(ref1)
            let (col2, row2) = parseReference(ref2)
            if row1 != row2 { return row1 < row2 }
            return col1 < col2
        }

        // Group by row
        var rows: [Int: [(String, String)]] = [:]
        for ref in sortedCells {
            let (_, row) = parseReference(ref)
            if rows[row] == nil { rows[row] = [] }
            rows[row]?.append((ref, cells[ref]!))
        }

        var rowXMLs: [String] = []
        for row in rows.keys.sorted() {
            let cellXMLs = rows[row]!.map { (ref, value) -> String in
                if let idx = stringIndex[value] {
                    return "      <c r=\"\(ref)\" t=\"s\"><v>\(idx)</v></c>"
                }
                return "      <c r=\"\(ref)\"><v>\(escapeXML(value))</v></c>"
            }.joined(separator: "\n")

            rowXMLs.append("""
                <row r="\(row)">
            \(cellXMLs)
                </row>
            """)
        }

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <sheetData>
        \(rowXMLs.joined(separator: "\n"))
          </sheetData>
        </worksheet>
        """
    }

    private func parseReference(_ ref: String) -> (String, Int) {
        var col = ""
        var rowStr = ""
        for char in ref {
            if char.isLetter {
                col.append(char)
            } else {
                rowStr.append(char)
            }
        }
        return (col, Int(rowStr) ?? 0)
    }

    private func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private func createZip(from directory: URL) throws -> Data {
        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).xlsx")

        let coordinator = NSFileCoordinator()
        var error: NSError?
        var zipData: Data?

        coordinator.coordinate(readingItemAt: directory, options: .forUploading, error: &error) { url in
            zipData = try? Data(contentsOf: url)
        }

        if let error = error {
            throw error
        }

        guard let data = zipData else {
            throw ExcelError.zipCreationFailed
        }

        // Clean up
        try? FileManager.default.removeItem(at: zipURL)

        return data
    }
}

enum ExcelError: LocalizedError {
    case zipCreationFailed
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .zipCreationFailed: return "Die Excel-Datei konnte nicht erstellt werden."
        case .exportFailed: return "Der Export ist fehlgeschlagen."
        }
    }
}
