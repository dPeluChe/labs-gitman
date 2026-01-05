import SwiftUI

struct CodeViewer: View {
    let content: String
    let fileExtension: String
    
    var body: some View {
        ScrollView {
            Text(highlightedCode)
                .font(.monospaced(.body)())
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .background(Color(.textBackgroundColor))
    }
    
    private var highlightedCode: AttributedString {
        SyntaxHighlighter.highlight(code: content, extension: fileExtension)
    }
}

struct SyntaxHighlighter {
    static func highlight(code: String, extension ext: String) -> AttributedString {
        var attributed = AttributedString(code)
        
        // Basic styling
        attributed.foregroundColor = .primary
        
        let string = String(code)
        
        // Helper to apply color to regex matches
        func applyPattern(_ pattern: String, color: Color) {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
            let matches = regex.matches(in: string, options: [], range: NSRange(location: 0, length: string.utf16.count))
            
            for match in matches {
                // Convert NSRange back to Swift String Range
                if let range = Range(match.range, in: attributed) {
                    attributed[range].foregroundColor = color
                }
            }
        }
        
        // 1. Comments (Gray) - Single line //
        applyPattern("//.*", color: .gray)
        
        // 2. Strings (Orange) - Double quotes
        applyPattern("\".*?\"", color: .orange)
        
        // 3. Keywords (Purple)
        let keywords = [
            "import", "class", "struct", "enum", "func", "var", "let", "if", "else", 
            "return", "true", "false", "nil", "init", "self", "super", "extension", 
            "public", "private", "fileprivate", "actor", "guard", "switch", "case", "try", "catch", "async", "await"
        ]
        let keywordPattern = "\\b(" + keywords.joined(separator: "|") + ")\\b"
        applyPattern(keywordPattern, color: .purple)
        
        return attributed
    }
}
