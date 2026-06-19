# Claveo

A free music practice companion for **iPhone** and **iPad**: record sessions, run a metronome and tuner, journal practice time, and use theory tools—all in one app. No ads; optional **iCloud** sync across your devices.

[![App Store](https://img.shields.io/badge/App%20Store-Download-0D96F6?logo=app-store)](https://apps.apple.com/us/app/claveo-music-companion/id6755795790)

## Features

- **Recording** — Practice takes with a piece library, tags, non-destructive trim, playback speed, search, and export/share  
- **Practice journal** — Minutes, notes, ratings, streaks, and stats; optional links to recordings  
- **Metronome** — Tap tempo, standard and custom time signatures, accents, saved tempos, optional haptics, reference tone  
- **Tuner** — Live pitch from the mic; custom A4 and optional Hz readout  
- **Exercises** — Note reading on the staff, key signatures, interval ear training  
- **Chord & scale reference** — Diatonic chords and scales by root  
- **Music dictionary** — Searchable terms and definitions  
- **Layout** — Reorder tabs (four on the bar, rest in More), accent colors, light/dark mode  
- **OMR (beta)** — Scan sheet music from photos or PDFs for experimental digitization workflows  

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
| App | Swift, SwiftUI, AVFoundation, CoreML (OMR) |
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
