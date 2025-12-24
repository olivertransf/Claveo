# Claveo

A complete music practice companion app for iPhone and iPad, featuring practice recording, metronome, tuner, and music dictionary.

[![App Store](https://img.shields.io/badge/App%20Store-Available-blue)](https://apps.apple.com/us/app/claveo-music-companion/id6755795790)

## About

Claveo is a free, comprehensive music practice app designed for musicians of all levels. The app provides essential tools for practice, learning, and improvement.

### Features

- **Practice Recording**: Record unlimited sessions with crystal-clear audio quality
- **Advanced Metronome**: Precise tempo control with customizable beat patterns and time signatures
- **Precision Tuner**: Real-time pitch detection with professional accuracy
- **Music Dictionary**: Searchable database of music terms and definitions
- **Practice Journal**: Track your practice sessions with detailed entries and statistics
- **Habit Tracking**: Monitor your practice consistency and build better habits

### Upcoming Features

- **Optical Music Recognition (OMR)**: Scan and digitize sheet music from photos (Beta - January 2026)

## Project Structure

This repository contains both the iOS app and the official website:

```
Claveo/
├── Claveo/              # iOS app (Swift/SwiftUI)
│   ├── Models/          # Data models
│   ├── Services/        # Business logic and services
│   └── Views/           # SwiftUI views
└── web/                 # Official website (Svelte)
    ├── src/
    │   ├── pages/       # Website pages
    │   └── styles.css   # Global styles
    └── public/          # Static assets
```

## Tech Stack

### iOS App
- **Language**: Swift
- **Framework**: SwiftUI
- **Dependencies**:
  - **Tuna**: Pitch detection library by [alladinian](https://github.com/alladinian/Tuna)

### Website
- **Framework**: Svelte
- **Build Tool**: Vite
- **Deployment**: Netlify

## Development

### iOS App

Open `Claveo.xcodeproj` in Xcode to build and run the app.

### Website

```bash
cd web
npm install
npm run dev    # Development server (http://localhost:5173)
npm run build  # Production build
```

## License

Copyright (c) 2025 Oliver Tran. All rights reserved.

See [LICENSE](LICENSE) for more information.

## Contact

For questions, feedback, or licensing inquiries: **claveo.app@gmail.com**

## Links

- [App Store](https://apps.apple.com/us/app/claveo-music-companion/id6755795790)
- [Official Website](https://claveo.netlify.app/)

