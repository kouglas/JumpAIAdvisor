//
//  Markdown.swift
//  JumpAIAdvisor
//
//  Created by Kari Douglas on 5/10/25.
//

import SwiftUI

// MARK: - ViewHeightKey PreferenceKey
struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - MarkdownText View
struct Markdown: View {
    let text: String
    
    var body: some View {
        let attributedString = parseMarkdown(text)
        
        Text(AttributedString(attributedString))
            .fixedSize(horizontal: false, vertical: true)
    }
    
    private func parseMarkdown(_ text: String) -> NSAttributedString {
        let mutableAttributedString = NSMutableAttributedString(string: text)
        let range = NSRange(location: 0, length: text.count)
        
        // Basic markdown patterns
        let patterns: [(pattern: String, attributes: [NSAttributedString.Key: Any])] = [
            // Bold
            ("\\*\\*(.*?)\\*\\*", [.font: UIFont.boldSystemFont(ofSize: 17)]),
            // Italic
            ("\\*(.*?)\\*", [.font: UIFont.italicSystemFont(ofSize: 17)]),
            // Code
            ("`(.*?)`", [.font: UIFont.monospacedSystemFont(ofSize: 16, weight: .regular),
                        .backgroundColor: UIColor.systemGray5])
        ]
        
        for (pattern, attributes) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.matches(in: text, options: [], range: range)
                
                // Process matches in reverse order to avoid range issues
                for match in matches.reversed() {
                    if match.numberOfRanges >= 2 {
                        let contentRange = match.range(at: 1)
                        let fullRange = match.range(at: 0)
                        
                        let content = (text as NSString).substring(with: contentRange)
                        mutableAttributedString.replaceCharacters(in: fullRange, with: content)
                        
                        let newRange = NSRange(location: fullRange.location, length: content.count)
                        mutableAttributedString.addAttributes(attributes, range: newRange)
                    }
                }
            }
        }
        
        // Headers
        let headerPatterns: [(pattern: String, fontSize: CGFloat)] = [
            ("^# (.*?)$", 24),
            ("^## (.*?)$", 22),
            ("^### (.*?)$", 20)
        ]
        
        for (pattern, fontSize) in headerPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) {
                let matches = regex.matches(in: text, options: [], range: range)
                
                for match in matches.reversed() {
                    if match.numberOfRanges >= 2 {
                        let contentRange = match.range(at: 1)
                        let fullRange = match.range(at: 0)
                        
                        let content = (text as NSString).substring(with: contentRange)
                        mutableAttributedString.replaceCharacters(in: fullRange, with: content)
                        
                        let newRange = NSRange(location: fullRange.location, length: content.count)
                        mutableAttributedString.addAttributes([.font: UIFont.boldSystemFont(ofSize: fontSize)], range: newRange)
                    }
                }
            }
        }
        
        return mutableAttributedString
    }
}
