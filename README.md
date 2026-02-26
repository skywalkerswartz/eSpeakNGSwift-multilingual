# eSpeakNGSwift — Multilingual Fork

> **This is a fork of [mlalma/eSpeakNGSwift](https://github.com/mlalma/eSpeakNGSwift) that extends language support beyond English.** See [What's Different in This Fork](#whats-different-in-this-fork) below. It is intended for use with [skywalkerswartz/kokoro-ios-multilingual](https://github.com/skywalkerswartz/kokoro-ios-multilingual).

A Swift wrapper for the eSpeakNG speech synthesizer and grapheme-to-phoneme (G2P) library for converting text to phonetic representations suitable for text-to-speech (TTS) engines.

## What's Different in This Fork

The upstream library exposes only English (US and GB) from the `Language` enum, even though the bundled eSpeak NG framework contains data for many more languages.

### Changes Made

- **`Language` enum** — Extended with seven new cases: `.es` (Spanish), `.frFR` (French), `.hi` (Hindi), `.it` (Italian), `.ptBR` (Brazilian Portuguese), `.zh` (Mandarin Chinese), `.ja` (Japanese).
- **`postProcessPhonemes`** — Made language-aware. English continues to use the full E2M substitution table (which includes English-specific mappings like `e→A` and `r→ɹ`). Non-English languages use a safe cross-language subset that only cleans up diphthong/affricate tie-markers, then applies Kokoro's required nasal vowel normalization (`œ̃→B`, `ɔ̃→C`, `ɑ̃→D`, `ɛ̃→E`). Applying the full English E2M table to other languages would corrupt their phonemes.
- **`init()` validation** — Relaxed from checking all `Language` enum cases at startup to only verifying English is present. Per-language availability is now checked lazily in `setLanguage()`, so adding new cases won't cause initialization to fail if a particular language's data is missing.

**Note on French:** The raw value is `"fr-fr"` not `"fr"`. The bundled xcframework registers French as `"fr-fr"` in its internal voice list (`espeak_ListVoices`). Using `"fr"` causes `languageNotFound` at runtime; `"fr-fr"` is the correct key. This was verified empirically by enumerating the framework's language map. Per-language availability is now checked lazily in `setLanguage()`, so adding new cases won't cause initialization to fail if a particular language's data is missing.

## Supported Platforms

- iOS 18.0+
- macOS 15.0+
- (Other Apple platforms may work as well)

## Installation

Add eSpeakNGSwift to your Swift Package Manager dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/mlalma/eSpeakNGSwift", from: "1.0.1")
]
```

## Features

- **Phonemization**: Convert text strings to phonetic representations
- **Language Support**: English (US and GB), Spanish, French, Hindi, Italian, Brazilian Portuguese, Mandarin Chinese, Japanese
- **Easy Integration**: Simple Swift API with comprehensive error handling
- **Pre-built Framework**: Includes pre-compiled eSpeakNG framework for easy integration

## Basic Usage

```swift
import eSpeakNGLib

do {
    // Create an instance of the eSpeakNG wrapper
    let espeak = try eSpeakNG()

    // Set the language (required before phonemizing)
    try espeak.setLanguage(language: .enUS)

    // Convert text to phonemes
    let phonemes = try espeak.phonemize(text: "Hello world!")
    print("Phonemes: \(phonemes)")

} catch {
    print("Error: \(error)")
}
```

## Language Options

| Case | Language |
|---|---|
| `.enUS` | English (United States) |
| `.enGB` | English (Great Britain) |
| `.es` | Spanish |
| `.frFR` | French (`fr-fr`) |
| `.hi` | Hindi |
| `.it` | Italian |
| `.ptBR` | Brazilian Portuguese |
| `.zh` | Mandarin Chinese |
| `.ja` | Japanese |

```swift
try espeak.setLanguage(language: .frFR)
let phonemes = try espeak.phonemize(text: "Bonjour le monde")
```

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

This library is built on top of the excellent [eSpeakNG](https://github.com/espeak-ng/espeak-ng) speech synthesizer library, which is licensed under GPL v3.
