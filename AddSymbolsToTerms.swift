import Foundation

// Script to add symbols to terms using SMuFL codes

struct MusicTerm: Codable {
    let term: String
    let definition: String
    let category: String
    let example: String?
    var symbol: String?
    var smuflCode: String?
}

struct MusicDictionary: Codable {
    var terms: [MusicTerm]
}

// Common term to SMuFL code mappings
let termSymbolMappings: [String: (smuflCode: String, symbol: String)] = [
    // Clefs
    "treble clef": ("U+E050", "𝄞"),
    "g clef": ("U+E050", "𝄞"),
    "bass clef": ("U+E062", "𝄢"),
    "f clef": ("U+E062", "𝄢"),
    "alto clef": ("U+E05C", "𝄡"),
    "c clef": ("U+E05C", "𝄡"),
    "tenor clef": ("U+E05C", "𝄡"),
    
    // Accidentals
    "sharp": ("U+E262", "♯"),
    "flat": ("U+E260", "♭"),
    "natural": ("U+E261", "♮"),
    "double sharp": ("U+E263", "𝄪"),
    "double flat": ("U+E264", "𝄫"),
    
    // Noteheads
    "whole note": ("U+E0A2", "𝅝"),
    "half note": ("U+E0A3", "𝅗𝅥"),
    "quarter note": ("U+E0A4", "♩"),
    "eighth note": ("U+E0A5", "♫"),
    "sixteenth note": ("U+E0A6", "♬"),
    
    // Rests
    "whole rest": ("U+E4E3", "𝄻"),
    "half rest": ("U+E4E4", "𝄼"),
    "quarter rest": ("U+E4E5", "𝄽"),
    "eighth rest": ("U+E4E6", "𝄾"),
    "sixteenth rest": ("U+E4E7", "𝄿"),
    
    // Dynamics
    "piano": ("U+E520", "𝆏"),
    "forte": ("U+E522", "𝆑"),
    "mezzo forte": ("U+E521", "𝆐"),
    "mezzo piano": ("U+E521", "𝆐"),
    "fortissimo": ("U+E523", "𝆒"),
    "pianissimo": ("U+E52F", "𝆟"),
    "crescendo": ("U+E53E", "𝆖"),
    "decrescendo": ("U+E53F", "𝆗"),
    "diminuendo": ("U+E53F", "𝆗"),
    
    // Articulations
    "staccato": ("U+E4A0", "𝆔"),
    "legato": ("U+E4A4", "𝆕"),
    "tenuto": ("U+E4A2", "𝆓"),
    "accent": ("U+E4A3", "𝆒"),
    "marcato": ("U+E4AC", "𝆕"),
    "fermata": ("U+E4C1", "𝄐"),
    
    // Ornaments
    "trill": ("U+E566", "𝆝"),
    "turn": ("U+E567", "𝆞"),
    "mordent": ("U+E56C", "𝆜"),
    "appoggiatura": ("U+E562", "𝆚"),
    
    // Barlines
    "bar line": ("U+E030", "|"),
    "double barline": ("U+E031", "||"),
    "final barline": ("U+E032", "||"),
    
    // Repeats
    "repeat sign": ("U+E040", "𝄆"),
    "da capo": ("U+E046", "𝄊"),
    "dal segno": ("U+E045", "𝄉"),
    "coda": ("U+E048", "𝄌"),
    "segno": ("U+E047", "𝄋"),
    
    // Other
    "tie": ("U+E1F0", "𝆀"),
    "slur": ("U+E1F0", "𝆀"),
    "dot": ("U+E1E7", "·"),
    "breath mark": ("U+E4CE", "𝄒")
]

func normalizeTerm(_ term: String) -> String {
    return term.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
}

func findSymbolForTerm(_ term: String) -> (smuflCode: String, symbol: String)? {
    let normalized = normalizeTerm(term)
    
    // Try exact match first
    for (key, value) in termSymbolMappings {
        if normalized == key || normalized.contains(key) {
            return value
        }
    }
    
    // Try partial matches
    for (key, value) in termSymbolMappings {
        let keyWords = key.components(separatedBy: " ")
        var matches = 0
        for word in keyWords {
            if normalized.contains(word) && word.count > 2 {
                matches += 1
            }
        }
        if matches >= keyWords.count / 2 && matches > 0 {
            return value
        }
    }
    
    return nil
}

// Convert SMuFL code to character
func smuflCodeToCharacter(_ code: String) -> String {
    let hexString = code.replacingOccurrences(of: "U+", with: "")
    if let codePoint = UInt32(hexString, radix: 16),
       let scalar = UnicodeScalar(codePoint) {
        return String(Character(scalar))
    }
    return ""
}

let fileManager = FileManager.default
let currentDir = fileManager.currentDirectoryPath
let jsonPath = "\(currentDir)/Claveo/Resources/musicDictionary.json"

print("📚 Loading dictionary...")
guard let jsonData = try? Data(contentsOf: URL(fileURLWithPath: jsonPath)) else {
    print("❌ Could not read musicDictionary.json")
    exit(1)
}

guard var dictionary = try? JSONDecoder().decode(MusicDictionary.self, from: jsonData) else {
    print("❌ Could not decode JSON")
    exit(1)
}

print("✅ Loaded \(dictionary.terms.count) terms")
print("🔄 Matching symbols to terms...\n")

var matched = 0

// Match symbols to terms
for (index, term) in dictionary.terms.enumerated() {
    if let symbolInfo = findSymbolForTerm(term.term) {
        let symbolChar = smuflCodeToCharacter(symbolInfo.smuflCode)
        if !symbolChar.isEmpty {
            dictionary.terms[index].symbol = symbolChar
            dictionary.terms[index].smuflCode = symbolInfo.smuflCode
            matched += 1
            if matched <= 30 || matched % 50 == 0 {
                print("[\(matched)] ✅ Matched: \(term.term) → \(symbolInfo.smuflCode)")
            }
        }
    }
}

print("\n📊 Results:")
print("   ✅ Terms with symbols: \(matched)")
print("   📝 Total terms: \(dictionary.terms.count)")

// Write updated dictionary
if let encoded = try? JSONEncoder().encode(dictionary) {
    try? encoded.write(to: URL(fileURLWithPath: jsonPath))
    print("\n✅ Updated dictionary saved to: musicDictionary.json")
} else {
    print("\n❌ Failed to encode dictionary")
    exit(1)
}
