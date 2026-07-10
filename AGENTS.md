# Claveo agent notes

## Localization

When adding or updating app languages, follow Apple’s agent localization workflow:
https://developer.apple.com/documentation/xcode/localizing-your-app-using-agents

1. Add the language to `knownRegions` in the Xcode project.
2. Ensure `Localizable.xcstrings` / `InfoPlist.xcstrings` exist and `SWIFT_EMIT_LOC_STRINGS` + `LOCALIZATION_PREFERS_STRING_CATALOGS` are enabled.
3. Build targets, then sync extracted `.stringsdata` into catalogs with `xcstringstool sync` if the CLI build does not update catalogs automatically.
4. Use localizable APIs: SwiftUI `Text`/`Button`/`Label` literals, and `String(localized:)` for plain `String` UI copy. Prefer explicit string literals in `switch` over `String.LocalizationValue(rawValue)` so keys extract at compile time.
5. Do not change enum raw values used for persistence; add `localizedName` for display.
6. Follow `TRANSLATION.md` for glossary and do-not-translate terms.
7. Mark agent translations with `"state": "translated"` in the string catalog.
