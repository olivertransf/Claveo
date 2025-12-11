import Foundation

// Script to update dictionary definitions from Open Music Theory glossary
// Removes symbols and only keeps terms from the glossary

struct MusicTerm: Codable {
    let term: String
    var definition: String
    let category: String
    let example: String?
}

struct MusicDictionary: Codable {
    var terms: [MusicTerm]
}

func fetchGlossary() async -> [String: String]? {
    guard let url = URL(string: "https://viva.pressbooks.pub/openmusictheory/back-matter/glossary/") else {
        return nil
    }
    
    do {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        // Parse HTML to extract glossary entries
        var glossary: [String: String] = [:]
        
        // Look for definition list patterns
        // Terms are typically in <dt> tags and definitions in <dd> tags
        let dtPattern = "<dt[^>]*>(.*?)</dt>"
        let ddPattern = "<dd[^>]*>(.*?)</dd>"
        
        let dtRegex = try NSRegularExpression(pattern: dtPattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
        let ddRegex = try NSRegularExpression(pattern: ddPattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
        
        let nsString = html as NSString
        let dtMatches = dtRegex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
        let ddMatches = ddRegex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
        
        // Match dt and dd pairs
        for (index, dtMatch) in dtMatches.enumerated() {
            if index < ddMatches.count {
                let termRange = dtMatch.range(at: 1)
                let defRange = ddMatches[index].range(at: 1)
                
                var term = nsString.substring(with: termRange)
                var definition = nsString.substring(with: defRange)
                
                // Clean HTML tags
                term = cleanHTML(term)
                definition = cleanHTML(definition)
                
                // Normalize term (lowercase for matching)
                let normalizedTerm = term.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                glossary[normalizedTerm] = definition.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return glossary
    } catch {
        print("Error fetching glossary: \(error)")
        return nil
    }
}

func cleanHTML(_ html: String) -> String {
    var cleaned = html
    
    // Remove HTML tags
    cleaned = cleaned.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    
    // Decode HTML entities
    cleaned = cleaned.replacingOccurrences(of: "&nbsp;", with: " ")
    cleaned = cleaned.replacingOccurrences(of: "&amp;", with: "&")
    cleaned = cleaned.replacingOccurrences(of: "&lt;", with: "<")
    cleaned = cleaned.replacingOccurrences(of: "&gt;", with: ">")
    cleaned = cleaned.replacingOccurrences(of: "&quot;", with: "\"")
    cleaned = cleaned.replacingOccurrences(of: "&#39;", with: "'")
    cleaned = cleaned.replacingOccurrences(of: "&apos;", with: "'")
    
    // Clean up whitespace
    cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    
    return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
}

func normalizeTerm(_ term: String) -> String {
    // Remove common variations and normalize
    var normalized = term.lowercased()
    
    // Remove common suffixes/prefixes
    normalized = normalized.replacingOccurrences(of: "^the ", with: "", options: .regularExpression)
    normalized = normalized.replacingOccurrences(of: " \\(.*\\)", with: "", options: .regularExpression)
    normalized = normalized.replacingOccurrences(of: ",.*", with: "", options: .regularExpression)
    normalized = normalized.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    
    return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
}

func findMatchingDefinition(term: String, glossary: [String: String]) -> String? {
    let normalized = normalizeTerm(term)
    
    // Try exact match first
    if let def = glossary[normalized] {
        return def
    }
    
    // Try word-by-word matching (for multi-word terms)
    let words = normalized.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
    
    // Try matching each word
    var bestMatch: (key: String, value: String, score: Int)? = nil
    
    for (key, value) in glossary {
        let keyWords = key.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        // Count matching words
        var matchScore = 0
        for word in words {
            for keyWord in keyWords {
                if word == keyWord || word.contains(keyWord) || keyWord.contains(word) {
                    matchScore += 1
                    break
                }
            }
        }
        
        // If most words match, consider it
        if matchScore > 0 && matchScore >= words.count / 2 {
            if bestMatch == nil || matchScore > bestMatch!.score {
                bestMatch = (key, value, matchScore)
            }
        }
    }
    
    if let match = bestMatch, match.score >= words.count / 2 {
        return match.value
    }
    
    // Try partial substring matches as fallback
    for (key, value) in glossary {
        if key.contains(normalized) || normalized.contains(key) {
            // Check if it's a reasonable match
            let lengthDiff = abs(key.count - normalized.count)
            let maxLength = max(key.count, normalized.count)
            if lengthDiff < Int(Double(maxLength) * 0.6) {
                return value
            }
        }
    }
    
    return nil
}

let fileManager = FileManager.default
let currentDir = fileManager.currentDirectoryPath
let jsonPath = "\(currentDir)/Claveo/Resources/musicDictionary.json"

print("📚 Loading dictionary...")
guard let jsonData = try? Data(contentsOf: URL(fileURLWithPath: jsonPath)) else {
    print("❌ Could not read musicDictionary.json")
    exit(1)
}

// First, decode with symbols to get terms
struct OldMusicDictionary: Codable {
    var terms: [MusicTerm]
    let symbols: [MusicSymbol]?
}

struct MusicSymbol: Codable {
    let symbol: String
    let unicode: String
    let name: String
    let category: String
    let description: String
    let smuflCode: String?
}

guard let oldDictionary = try? JSONDecoder().decode(OldMusicDictionary.self, from: jsonData) else {
    print("❌ Could not decode JSON")
    exit(1)
}

var dictionary = MusicDictionary(terms: oldDictionary.terms)

print("✅ Loaded \(dictionary.terms.count) terms")
print("🌐 Fetching glossary from Open Music Theory...")

guard let glossary = await fetchGlossary() else {
    print("❌ Failed to fetch glossary")
    exit(1)
}

print("✅ Fetched \(glossary.count) glossary entries")
print("🔄 Updating definitions and filtering to only include terms from glossary...\n")

// Create backup first
let backupPath = "\(currentDir)/Claveo/Resources/musicDictionary_backup_\(Int(Date().timeIntervalSince1970)).json"
try? jsonData.write(to: URL(fileURLWithPath: backupPath))
print("💾 Backup saved to: \(backupPath)\n")

var updated = 0
var notFound = 0
var filteredTerms: [MusicTerm] = []

for term in dictionary.terms {
    if let newDefinition = findMatchingDefinition(term: term.term, glossary: glossary) {
        var updatedTerm = term
        updatedTerm.definition = newDefinition
        filteredTerms.append(updatedTerm)
        updated += 1
        if updated <= 20 || updated % 50 == 0 {
            print("[\(updated)] ✅ Updated: \(term.term)")
        }
    } else {
        notFound += 1
        if notFound <= 10 {
            print("[\(notFound)] ⚠️  Not found in glossary: \(term.term)")
        }
    }
}

dictionary.terms = filteredTerms

print("\n📊 Results:")
print("   ✅ Updated and included: \(updated)")
print("   ⚠️  Not found (excluded): \(notFound)")
print("   📝 Final term count: \(dictionary.terms.count)")

// Write updated dictionary (without symbols)
if let encoded = try? JSONEncoder().encode(dictionary) {
    try? encoded.write(to: URL(fileURLWithPath: jsonPath))
    print("\n✅ Updated dictionary saved to: musicDictionary.json")
    print("   ✨ Symbols removed, only terms from Open Music Theory glossary included")
} else {
    print("\n❌ Failed to encode dictionary")
    exit(1)
}
