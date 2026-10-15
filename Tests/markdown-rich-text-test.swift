// Standalone test for the Markdown to HTML conversion behind Paste Markdown as Rich Text.
import Foundation

@main
struct MarkdownRichTextTests {
    nonisolated(unsafe) static var failures = 0
    nonisolated(unsafe) static var passes = 0

    static func main() {
        rendersHeadingsParagraphsAndBreaks()
        rendersInlineEmphasis()
        rendersCode()
        rendersLinksAutolinksAndImages()
        rendersLists()
        rendersTaskList()
        rendersBlockQuoteAndThematicBreak()
        rendersAlignedTable()
        passesInlineHTMLThrough()
        escapesTextThatLooksLikeMarkup()
        keepsPlainProseUnchanged()
        wrapsInAStyledDocument()

        print("\(passes)/\(passes + failures) passed")
        if failures > 0 { exit(1) }
    }

    static func rendersHeadingsParagraphsAndBreaks() {
        let html = convert("# Title\n\n### Sub\n\nfirst line  \nsecond line")
        expectContains(html, "<h1>Title</h1>", "level 1 heading")
        expectContains(html, "<h3>Sub</h3>", "level 3 heading")
        expectContains(html, "<p>first line<br />\nsecond line</p>", "hard line break in a paragraph")
    }

    static func rendersInlineEmphasis() {
        let html = convert("**bold** *italic* ~~gone~~")
        expectContains(html, "<strong>bold</strong>", "bold")
        expectContains(html, "<em>italic</em>", "italic")
        expectContains(html, "<del>gone</del>", "strikethrough")
    }

    static func rendersCode() {
        let html = convert("Use `let x`.\n\n```swift\nprint(1)\n```\n\n    indented")
        expectContains(html, "<code>let x</code>", "inline code")
        expectContains(html, "<pre><code class=\"language-swift\">print(1)\n</code></pre>", "fenced code")
        expectContains(html, "<pre><code>indented\n</code></pre>", "indented code")
    }

    static func rendersLinksAutolinksAndImages() {
        let html = convert("[site](https://a.example) https://b.example ![logo](https://c.example/l.png)")
        expectContains(html, "<a href=\"https://a.example\">site</a>", "link")
        expectContains(html, "<a href=\"https://b.example\">https://b.example</a>", "autolink")
        expectContains(html, "<img src=\"https://c.example/l.png\" />", "image")
        let linkedURL = convert("[https://d.example](https://d.example)")
        expectContains(linkedURL, "<a href=\"https://d.example\">https://d.example</a>", "no nested link")
        expectContains(convert("\"quoted\""), "&quot;quoted&quot;", "straight quotes, as GitHub")
    }

    static func rendersLists() {
        let html = convert("1. one\n2. two\n   - nested\n\n- bullet")
        expectContains(html, "<ol>\n<li>", "ordered list")
        expectContains(html, "<p>two</p>\n<ul>\n<li><p>nested</p>", "nested unordered list")
        expectContains(html, "<ul>\n<li><p>bullet</p>", "unordered list item")
    }

    static func rendersTaskList() {
        let html = convert("- [x] done\n- [ ] todo")
        expectContains(html, "<li><input type=\"checkbox\" disabled=\"\" checked=\"\" /> <p>done</p>", "checked")
        expectContains(html, "<li><input type=\"checkbox\" disabled=\"\" /> <p>todo</p>", "unchecked")
    }

    static func rendersBlockQuoteAndThematicBreak() {
        let html = convert("> quoted\n\n---")
        expectContains(html, "<blockquote>\n<p>quoted</p>\n</blockquote>", "block quote")
        expectContains(html, "<hr />", "thematic break")
    }

    static func rendersAlignedTable() {
        let html = convert("| L | C | R | N |\n|:--|:-:|--:|---|\n| a | b | c | d |")
        expectContains(html, "<thead>\n<tr>\n<th align=\"left\">L</th>", "left header")
        expectContains(html, "<th align=\"center\">C</th>", "center header")
        expectContains(html, "<th align=\"right\">R</th>", "right header")
        expectContains(html, "<th>N</th>", "unaligned header")
        expectContains(html, "<td align=\"center\">b</td>", "center cell")
    }

    static func passesInlineHTMLThrough() {
        let html = convert("press <kbd>Cmd</kbd>")
        expectContains(html, "<kbd>Cmd</kbd>", "inline HTML")
    }

    static func escapesTextThatLooksLikeMarkup() {
        let html = convert("a < b & c\n\n`<div>`\n\n```\n<b>x</b>\n```")
        expectContains(html, "<p>a &lt; b &amp; c</p>", "text")
        expectContains(html, "<code>&lt;div&gt;</code>", "inline code")
        expectContains(html, "<pre><code>&lt;b&gt;x&lt;/b&gt;\n</code></pre>", "code block")
    }

    static func keepsPlainProseUnchanged() {
        let html = convert("Just some words.\n\nAnother paragraph.")
        expectContains(html, "<p>Just some words.</p>\n<p>Another paragraph.</p>", "paragraphs")
    }

    static func wrapsInAStyledDocument() {
        let html = convert("x")
        expectContains(html, "<meta charset=\"utf-8\">", "charset")
        expectContains(html, "border-collapse: collapse", "table stylesheet")
        expectContains(html, "body, table { font-family: -apple-system, system-ui, sans-serif; font-size: 14px; }", "body size")
        expectContains(html, "h1 { font-size: 16px; }", "h1 size")
        expectContains(html, "h2 { font-size: 15px; }", "h2 size")
        expectContains(html, "h3, h4, h5, h6 { font-size: 14px; }", "h3 to h6 size")
        expectContains(html, "h1, h2, h3, h4, h5, h6 { font-weight: bold;", "bold headings")
        expectContains(html, "code, pre { font-family: Menlo, ui-monospace, monospace; font-size: 13px; }", "code size")
        expectContains(html, "<body>\n<p>x</p>\n</body>", "body")
    }

    static func convert(_ markdown: String) -> String {
        MarkdownRichText.htmlDocument(fromMarkdown: markdown)
    }

    static func expectContains(_ html: String, _ fragment: String, _ label: String) {
        if html.contains(fragment) {
            passes += 1
        } else {
            failures += 1
            print("FAIL \(label): missing \(fragment.debugDescription)\n\(html)")
        }
    }
}
