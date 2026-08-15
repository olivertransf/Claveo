# Claveo

A free music practice companion for **iPhone** and **iPad**: record sessions, run a metronome and tuner, journal practice time, and use theory tools—all in one app. No ads; optional **iCloud** sync across your devices.

[![App Store](https://img.shields.io/badge/App%20Store-Download-0D96F6?logo=app-store)](https://apps.apple.com/us/app/claveo-music-companion/id6755795790)

## Features

- **Recording** — Practice takes with live waveform, piece library, tags, non-destructive trim, variable playback speed (0.5x–2x), search/filter, bulk export, and share
- **Live Activity** — Dynamic Island and lock screen status while recording
- **Practice journal** — Minutes, notes, 1–5 star ratings, streaks, week calendar, stats; link entries to recordings; daily reminder notifications
- **Metronome** — Tap tempo, standard and custom time signatures, per-beat accents, subdivisions (eighths, triplets, sixteenths, dotted), saved tempos, haptics, reference tone generator
- **Tuner** — Live mic pitch detection; cents deviation display; custom A4 reference (400–480 Hz)
- **Exercises** — Note reading on the staff (treble/bass/alto/tenor), key signature ID, interval ear training
- **Chord & scale reference** — Diatonic chords and scales by root; major and relative minor
- **Music dictionary** — Searchable terms with SMuFL notation symbols, browsable by category
- **Layout** — Reorder eight tabs (four on bar + More on iPhone), accent colors, light/dark mode
- **Sync** — Optional iCloud Drive sync across iPhone and iPad, or device-only storage

Roadmap and web copy live in the repo; see the [site roadmap](https://claveo-app.vercel.app/roadmap) for planned work.

## Repository layout

```
Claveo/
├── Claveo/                 # iOS app (Swift / SwiftUI)
│   ├── Models/
│   ├── Services/
│   └── Views/
├── web/                    # Marketing site (Svelte + Vite)
│   ├── src/
│   │   ├── pages/          # Home, About, Roadmap, Privacy
│   │   └── assets/         # Bundled App Store screenshots (carousel)
│   ├── public/             # Static assets (icon, screenshots, etc.)
│   └── package.json
├── Claveo.xcodeproj
├── netlify.toml            # Build: cd web && npm install && npm run build → web/dist
└── LICENSE
```

## Requirements

- **iOS app**: Xcode 16+ recommended, deployment target **iOS 17.6**  
- **Website**: Node.js 18+ (for local dev and Netlify builds)

## Development

### iOS

Open `Claveo.xcodeproj` in Xcode, select an iPhone or iPad simulator (or device), and run.

### Website

```bash
cd web
npm install
npm run dev     # http://localhost:5173
npm run build   # output: web/dist/
```

Production deploys use the root **`netlify.toml`** (publish `web/dist`, SPA fallback to `index.html`).

## Tech stack

| Area | Stack |
|------|--------|
| App | Swift, SwiftUI, AVFoundation |
| Packages (SPM) | [Tuna](https://github.com/alladinian/Tuna) (pitch detection), [VexFoundation](https://github.com/migueldeicaza/VexFoundation) (staff rendering in exercises) |
| Site | Svelte, Vite |

## License

Copyright (c) 2025 Oliver Tran. See [LICENSE](LICENSE).

## Contact

**claveo.app@gmail.com** — questions, feedback, or licensing.

## Links

- **Website** — [claveo-app.vercel.app](https://claveo-app.vercel.app/)  
- **App Store** — [Claveo](https://apps.apple.com/us/app/claveo-music-companion/id6755795790)  
- **Privacy policy** — [claveo-app.vercel.app/privacy-policy](https://claveo-app.vercel.app/privacy-policy.html)  
- **Source** — [github.com/olivertransf/Claveo](https://github.com/olivertransf/Claveo)
