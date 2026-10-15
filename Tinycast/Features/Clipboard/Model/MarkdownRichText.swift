import Foundation
import Markdown

/// GitHub Flavored Markdown rendered as a standalone HTML document, for pasting as rich text.
enum MarkdownRichText {
    private static let stylesheet = """
        body { font-family: -apple-system, system-ui, sans-serif; }
        code, pre { font-family: ui-monospace, Menlo, monospace; }
        li > p { margin: 0; }
        table { border-collapse: collapse; }
        th, td { border: 1px solid #d0d7de; padding: 4px 8px; }
        """

    static func htmlDocument(fromMarkdown markdown: String) -> String {
        var escaper = HTMLTextEscaper()
        let parsed = Document(parsing: markdown, options: .disableSmartOpts)
        let document = escaper.visit(parsed) ?? Document()
        let body = HTMLFormatter.format(document)
        return """
            <!DOCTYPE html>
            <html><head><meta charset="utf-8"><style>
            \(stylesheet)
            </style></head><body>
            \(body)</body></html>
            """
    }

    static func escapeHTML(_ text: String) -> String {
        var escaped = ""
        escaped.reserveCapacity(text.count)
        for character in text {
            switch character {
            case "&": escaped += "&amp;"
            case "<": escaped += "&lt;"
            case ">": escaped += "&gt;"
            case "\"": escaped += "&quot;"
            default: escaped.append(character)
            }
        }
        return escaped
    }

    /// swift-markdown leaves cmark-gfm's autolink extension off, so bare URLs are linked here.
    static func autolinkedHTML(_ text: String) -> String? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        else { return nil }
        let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
        guard !matches.isEmpty else { return nil }
        var html = ""
        var cursor = text.startIndex
        for match in matches {
            guard let url = match.url, let range = Range(match.range, in: text) else { continue }
            html += escapeHTML(String(text[cursor..<range.lowerBound]))
            html += "<a href=\"\(escapeHTML(url.absoluteString))\">\(escapeHTML(String(text[range])))</a>"
            cursor = range.upperBound
        }
        return html + escapeHTML(String(text[cursor...]))
    }
}

/// `HTMLFormatter` writes text, code and URLs verbatim, so `a < b` would otherwise become markup.
private struct HTMLTextEscaper: MarkupRewriter {
    mutating func visitText(_ text: Text) -> Markup? {
        if !isInsideLink(text), let html = MarkdownRichText.autolinkedHTML(text.string) {
            return InlineHTML(html)
        }
        return Text(MarkdownRichText.escapeHTML(text.string))
    }

    private func isInsideLink(_ markup: Markup) -> Bool {
        var ancestor = markup.parent
        while let current = ancestor {
            if current is Link || current is Image { return true }
            ancestor = current.parent
        }
        return false
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> Markup? {
        InlineCode(MarkdownRichText.escapeHTML(inlineCode.code))
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> Markup? {
        var escaped = codeBlock
        escaped.code = MarkdownRichText.escapeHTML(codeBlock.code)
        return escaped
    }

    mutating func visitLink(_ link: Link) -> Markup? {
        var escaped = link
        escaped.destination = link.destination.map(MarkdownRichText.escapeHTML)
        return defaultVisit(escaped)
    }

    mutating func visitImage(_ image: Image) -> Markup? {
        var escaped = image
        escaped.source = image.source.map(MarkdownRichText.escapeHTML)
        escaped.title = image.title.map(MarkdownRichText.escapeHTML)
        return escaped
    }
}
