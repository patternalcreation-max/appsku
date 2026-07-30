import Foundation

struct PageLink: Identifiable, Codable {
    let id: UUID
    let ref: String
    let text: String
    let href: String

    init(id: UUID = UUID(), ref: String, text: String, href: String) {
        self.id = id
        self.ref = ref
        self.text = text
        self.href = href
    }
}

struct PageFormField: Identifiable, Codable {
    let id: UUID
    let ref: String
    let tag: String
    let type: String
    let name: String
    let label: String
    let placeholder: String
    let required: Bool

    init(id: UUID = UUID(), ref: String, tag: String, type: String, name: String, label: String, placeholder: String, required: Bool) {
        self.id = id
        self.ref = ref
        self.tag = tag
        self.type = type
        self.name = name
        self.label = label
        self.placeholder = placeholder
        self.required = required
    }
}

struct PageForm: Identifiable, Codable {
    let id: UUID
    let ref: String
    let action: String
    let method: String
    let fields: [PageFormField]

    init(id: UUID = UUID(), ref: String, action: String, method: String, fields: [PageFormField]) {
        self.id = id
        self.ref = ref
        self.action = action
        self.method = method
        self.fields = fields
    }
}

struct PageTable: Identifiable, Codable {
    let id: UUID
    let headers: [String]
    let rows: [[String]]

    init(id: UUID = UUID(), headers: [String], rows: [[String]]) {
        self.id = id
        self.headers = headers
        self.rows = rows
    }
}

struct DOMElement: Identifiable, Codable {
    let id: UUID
    let ref: String?
    let tag: String
    let text: String
    let ariaLabel: String
    let role: String
    let type: String
    let name: String
    let placeholder: String
    let isVisible: Bool

    init(id: UUID = UUID(), ref: String? = nil, tag: String, text: String, ariaLabel: String, role: String, type: String, name: String, placeholder: String, isVisible: Bool) {
        self.id = id
        self.ref = ref
        self.tag = tag
        self.text = text
        self.ariaLabel = ariaLabel
        self.role = role
        self.type = type
        self.name = name
        self.placeholder = placeholder
        self.isVisible = isVisible
    }
}

struct PageSnapshot: Identifiable, Codable {
    let id: UUID
    let identity: SnapshotIdentity
    let title: String
    let url: String
    let text: String
    let headings: [DOMElement]
    let buttons: [DOMElement]
    let inputs: [DOMElement]
    let links: [PageLink]
    let forms: [PageForm]
    let tables: [PageTable]
    let capturedAt: Date

    init(
        id: UUID? = nil,
        identity: SnapshotIdentity,
        title: String,
        url: String,
        text: String,
        headings: [DOMElement],
        buttons: [DOMElement],
        inputs: [DOMElement],
        links: [PageLink],
        forms: [PageForm],
        tables: [PageTable],
        capturedAt: Date = Date()
    ) {
        self.id = id ?? identity.snapshotID
        self.identity = identity
        self.title = title
        self.url = url
        self.text = text
        self.headings = headings
        self.buttons = buttons
        self.inputs = inputs
        self.links = links
        self.forms = forms
        self.tables = tables
        self.capturedAt = capturedAt
    }

    /// Bounded, control-character-clean model evidence. Only opaque refs are emitted.
    var summaryText: String {
        let clean = ModelSummarySanitizer.clean
        let reference: (String) -> String = { StableElementReference.isValidOpaqueRef($0) ? $0 : "invalid-ref" }
        let clippedText = clean(text, 9_000)
        let headingBlock = headings.prefix(25).map { "- \(clean($0.text, 240))" }.joined(separator: "\n")
        let buttonBlock = buttons.prefix(40).map {
            "- ref=\($0.ref.map(reference) ?? "none") \(clean($0.text.isEmpty ? $0.ariaLabel : $0.text, 240))"
        }.joined(separator: "\n")
        let linkBlock = links.prefix(40).enumerated().map {
            "\($0.offset + 1). ref=\(reference($0.element.ref)) \(clean($0.element.text, 240)) → \(clean($0.element.href, 1_024))"
        }.joined(separator: "\n")
        let inputBlock = inputs.prefix(40).map {
            "- ref=\($0.ref.map(reference) ?? "none") \(clean($0.type, 64)) \(clean($0.name, 128)) \(clean($0.placeholder, 240))"
        }.joined(separator: "\n")
        let formBlock = forms.prefix(10).map { form in
            let fields = form.fields.prefix(40).map {
                "  - ref=\(reference($0.ref)) \(clean($0.type, 64)) \(clean($0.name, 128)) \(clean($0.placeholder, 240))"
            }.joined(separator: "\n")
            return "FORM ref=\(reference(form.ref)) \(clean(form.method, 16)) \(clean(form.action, 1_024))\n\(fields)"
        }.joined(separator: "\n")
        let tableBlock = tables.prefix(8).map { table in
            let headers = table.headers.prefix(32).map { clean($0, 240) }.joined(separator: " | ")
            let rows = table.rows.prefix(8).map { row in
                row.prefix(32).map { clean($0, 240) }.joined(separator: " | ")
            }.joined(separator: "\n")
            return "TABLE\nHeaders: \(headers)\n\(rows)"
        }.joined(separator: "\n")

        let summary = """
        K3 Browser DOM Snapshot V3
        Page generation: \(identity.pageGeneration)
        Snapshot: \(identity.snapshotID.uuidString)
        Origin: \(clean(identity.origin, 512))
        Title: \(clean(title, 512).isEmpty ? "(none)" : clean(title, 512))
        URL: \(clean(url, 2_048))

        TEXT
        \(clippedText.isEmpty ? "(no readable text)" : clippedText)

        HEADINGS
        \(headingBlock.isEmpty ? "(none)" : headingBlock)

        BUTTONS
        \(buttonBlock.isEmpty ? "(none)" : buttonBlock)

        LINKS
        \(linkBlock.isEmpty ? "(none)" : linkBlock)

        INPUTS
        \(inputBlock.isEmpty ? "(none)" : inputBlock)

        FORMS
        \(formBlock.isEmpty ? "(none)" : formBlock)

        TABLES
        \(tableBlock.isEmpty ? "(none)" : tableBlock)
        """
        return ModelSummarySanitizer.utf8Prefix(summary, maximumBytes: 24_000)
    }
}

private enum ModelSummarySanitizer {
    static func clean(_ raw: String, _ maximumBytes: Int) -> String {
        let allowed = raw.unicodeScalars.filter { scalar in
            if scalar == "\n" || scalar == "\t" { return true }
            if scalar.properties.isControl { return false }
            switch scalar.value {
            case 0x202A...0x202E, 0x2066...0x2069: return false
            default: return true
            }
        }
        return utf8Prefix(String(String.UnicodeScalarView(allowed)), maximumBytes: maximumBytes)
    }

    static func utf8Prefix(_ value: String, maximumBytes: Int) -> String {
        guard maximumBytes > 0, value.utf8.count > maximumBytes else { return maximumBytes > 0 ? value : "" }
        var end = value.startIndex
        var bytes = 0
        while end < value.endIndex {
            let next = value.index(after: end)
            let width = value[end..<next].utf8.count
            guard bytes + width <= maximumBytes else { break }
            bytes += width
            end = next
        }
        return String(value[..<end])
    }
}
