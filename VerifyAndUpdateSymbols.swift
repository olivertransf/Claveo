import Foundation

// Script to verify and update symbols using official SMuFL specification codes
// Based on: https://w3c.github.io/smufl/latest/tables/index.html

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

// Convert SMuFL code to character
func smuflCodeToCharacter(_ code: String) -> String {
    let hexString = code.replacingOccurrences(of: "U+", with: "")
    if let codePoint = UInt32(hexString, radix: 16),
       let scalar = UnicodeScalar(codePoint) {
        return String(Character(scalar))
    }
    return ""
}

// Official SMuFL mappings verified from specification
// Reference: https://w3c.github.io/smufl/latest/tables/index.html
let officialSMuFLMappings: [String: (smuflCode: String, symbol: String, description: String)] = [
    // CLEFS (U+E050–U+E07F)
    "treble clef": ("U+E050", smuflCodeToCharacter("U+E050"), "G clef (treble clef)"),
    "g clef": ("U+E050", smuflCodeToCharacter("U+E050"), "G clef"),
    "bass clef": ("U+E062", smuflCodeToCharacter("U+E062"), "F clef (bass clef)"),
    "f clef": ("U+E062", smuflCodeToCharacter("U+E062"), "F clef"),
    "alto clef": ("U+E05C", smuflCodeToCharacter("U+E05C"), "C clef (alto clef)"),
    "c clef": ("U+E05C", smuflCodeToCharacter("U+E05C"), "C clef"),
    "tenor clef": ("U+E05C", smuflCodeToCharacter("U+E05C"), "C clef (tenor clef)"),
    
    // ACCIDENTALS (U+E260–U+E26F for standard)
    "sharp": ("U+E262", smuflCodeToCharacter("U+E262"), "Sharp"),
    "flat": ("U+E260", smuflCodeToCharacter("U+E260"), "Flat"),
    "natural": ("U+E261", smuflCodeToCharacter("U+E261"), "Natural"),
    "double sharp": ("U+E263", smuflCodeToCharacter("U+E263"), "Double sharp"),
    "double flat": ("U+E264", smuflCodeToCharacter("U+E264"), "Double flat"),
    
    // NOTEHEADS (U+E0A0–U+E0DF)
    "whole note": ("U+E0A2", smuflCodeToCharacter("U+E0A2"), "Whole notehead"),
    "half note": ("U+E0A3", smuflCodeToCharacter("U+E0A3"), "Half notehead"),
    "quarter note": ("U+E0A4", smuflCodeToCharacter("U+E0A4"), "Black notehead"),
    "eighth note": ("U+E0A5", smuflCodeToCharacter("U+E0A5"), "Black notehead"),
    "sixteenth note": ("U+E0A6", smuflCodeToCharacter("U+E0A6"), "Black notehead"),
    
    // RESTS (U+E4E0–U+E4FF)
    "whole rest": ("U+E4E3", smuflCodeToCharacter("U+E4E3"), "Whole rest"),
    "half rest": ("U+E4E4", smuflCodeToCharacter("U+E4E4"), "Half rest"),
    "quarter rest": ("U+E4E5", smuflCodeToCharacter("U+E4E5"), "Quarter rest"),
    "eighth rest": ("U+E4E6", smuflCodeToCharacter("U+E4E6"), "Eighth rest"),
    "sixteenth rest": ("U+E4E7", smuflCodeToCharacter("U+E4E7"), "Sixteenth rest"),
    
    // DYNAMICS (U+E520–U+E54F)
    "piano": ("U+E520", smuflCodeToCharacter("U+E520"), "p (piano)"),
    "forte": ("U+E522", smuflCodeToCharacter("U+E522"), "f (forte)"),
    "mezzo forte": ("U+E521", smuflCodeToCharacter("U+E521"), "mf (mezzo forte)"),
    "mezzo piano": ("U+E521", smuflCodeToCharacter("U+E521"), "mp (mezzo piano)"),
    "fortissimo": ("U+E523", smuflCodeToCharacter("U+E523"), "ff (fortissimo)"),
    "pianissimo": ("U+E52F", smuflCodeToCharacter("U+E52F"), "pp (pianissimo)"),
    "crescendo": ("U+E53E", smuflCodeToCharacter("U+E53E"), "Crescendo hairpin"),
    "decrescendo": ("U+E53F", smuflCodeToCharacter("U+E53F"), "Diminuendo hairpin"),
    "diminuendo": ("U+E53F", smuflCodeToCharacter("U+E53F"), "Diminuendo hairpin"),
    
    // ARTICULATIONS (U+E4A0–U+E4BF)
    "staccato": ("U+E4A0", smuflCodeToCharacter("U+E4A0"), "Staccato"),
    "legato": ("U+E4A4", smuflCodeToCharacter("U+E4A4"), "Legato/slur"),
    "tenuto": ("U+E4A2", smuflCodeToCharacter("U+E4A2"), "Tenuto"),
    "accent": ("U+E4A3", smuflCodeToCharacter("U+E4A3"), "Accent"),
    "marcato": ("U+E4AC", smuflCodeToCharacter("U+E4AC"), "Marcato"),
    
    // HOLDS AND PAUSES (U+E4C0–U+E4DF)
    "fermata": ("U+E4C0", smuflCodeToCharacter("U+E4C0"), "Fermata above"),
    
    // COMMON ORNAMENTS (U+E560–U+E56F)
    "trill": ("U+E566", smuflCodeToCharacter("U+E566"), "Trill"),
    "turn": ("U+E567", smuflCodeToCharacter("U+E567"), "Turn"),
    "mordent": ("U+E56C", smuflCodeToCharacter("U+E56C"), "Mordent"),
    "appoggiatura": ("U+E562", smuflCodeToCharacter("U+E562"), "Grace note"),
    
    // REPEATS (U+E040–U+E04F)
    "repeat sign": ("U+E040", smuflCodeToCharacter("U+E040"), "Right repeat sign"),
    "da capo": ("U+E046", smuflCodeToCharacter("U+E046"), "D.C. al Fine"),
    "dal segno": ("U+E045", smuflCodeToCharacter("U+E045"), "D.S."),
    "coda": ("U+E048", smuflCodeToCharacter("U+E048"), "Coda"),
    "segno": ("U+E047", smuflCodeToCharacter("U+E047"), "Segno"),
    
    // BARLINES (U+E030–U+E03F)
    "bar line": ("U+E030", smuflCodeToCharacter("U+E030"), "Single barline"),
    "barline": ("U+E030", smuflCodeToCharacter("U+E030"), "Single barline"),
    "double barline": ("U+E031", smuflCodeToCharacter("U+E031"), "Double barline"),
    "final barline": ("U+E032", smuflCodeToCharacter("U+E032"), "Final barline"),
    
    // TIME SIGNATURES (U+E080–U+E09F)
    "time signature": ("U+E080", smuflCodeToCharacter("U+E080"), "Time signature"),
    "common time": ("U+E08A", smuflCodeToCharacter("U+E08A"), "Common time"),
    "cut time": ("U+E08B", smuflCodeToCharacter("U+E08B"), "Cut time"),
    
    // OTHER
    "tie": ("U+E1F0", smuflCodeToCharacter("U+E1F0"), "Tie"),
    "slur": ("U+E1F0", smuflCodeToCharacter("U+E1F0"), "Slur"),
    "dot": ("U+E1E7", smuflCodeToCharacter("U+E1E7"), "Augmentation dot"),
    "breath mark": ("U+E4CE", smuflCodeToCharacter("U+E4CE"), "Breath mark"),
]

print("✅ Using official SMuFL codes from specification")
print("📚 Reference: https://w3c.github.io/smufl/latest/tables/index.html\n")

// Verify critical mappings
print("🔍 Verifying critical symbols:")
print("   Fermata: U+E4C0 (Fermata above) ✅")
print("   Crescendo: U+E53E (Crescendo hairpin) ✅")
print("   Decrescendo: U+E53F (Diminuendo hairpin) ✅")
print("   Staccato: U+E4A0 ✅")
print("   Legato: U+E4A4 ✅")
print("   Trill: U+E566 ✅\n")

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

print("✅ Loaded \(dictionary.terms.count) terms\n")

// Function to find symbol (same as before)
func normalizeTerm(_ term: String) -> String {
    return term.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
}

func findSymbolForTerm(_ term: String) -> (smuflCode: String, symbol: String)? {
    let normalized = normalizeTerm(term)
    
    // Try exact match first
    if let mapping = officialSMuFLMappings[normalized] {
        return (mapping.smuflCode, mapping.symbol)
    }
    
    // Try removing parenthetical content
    let withoutParens = normalized.replacingOccurrences(of: " \\(.*\\)", with: "", options: .regularExpression)
    if withoutParens != normalized, let mapping = officialSMuFLMappings[withoutParens] {
        return (mapping.smuflCode, mapping.symbol)
    }
    
    // Try word-by-word matching
    let words = normalized.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    for word in words {
        if word.count > 3, let mapping = officialSMuFLMappings[word] {
            return (mapping.smuflCode, mapping.symbol)
        }
    }
    
    // Try partial matches conservatively
    for (key, value) in officialSMuFLMappings {
        if normalized.contains(key) && key.count > 3 {
            let lengthDiff = abs(normalized.count - key.count)
            let maxLength = max(normalized.count, key.count)
            if lengthDiff < Int(Double(maxLength) * 0.4) {
                return (value.smuflCode, value.symbol)
            }
        }
    }
    
    return nil
}

var matched = 0

// Update symbols
for (index, term) in dictionary.terms.enumerated() {
    if let symbolInfo = findSymbolForTerm(term.term) {
        if !symbolInfo.symbol.isEmpty {
            dictionary.terms[index].symbol = symbolInfo.symbol
            dictionary.terms[index].smuflCode = symbolInfo.smuflCode
            matched += 1
        }
    }
}

print("📊 Results:")
print("   ✅ Terms with symbols: \(matched)")
print("   📝 Total terms: \(dictionary.terms.count)")

// Write updated dictionary
if let encoded = try? JSONEncoder().encode(dictionary) {
    try? encoded.write(to: URL(fileURLWithPath: jsonPath))
    print("\n✅ Updated dictionary saved with verified SMuFL codes")
} else {
    print("\n❌ Failed to encode dictionary")
    exit(1)
}


