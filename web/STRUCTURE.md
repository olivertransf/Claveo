# Website structure

Svelte 5 + Vite 7, plain CSS, no router (pushState switch in `App.svelte`). Deployed on Vercel from `web/dist/`.

```
web/
├── index.html                  Vite entry: meta, OG/Twitter, JSON-LD, Inter 400-800, theme bootstrap
├── src/
│   ├── main.js                 Mounts App
│   ├── App.svelte              Routing (pushState + popstate), theme state, page switch
│   ├── styles.css              Design tokens (light/dark), base, type scale, buttons, cards, prose, reveal
│   ├── lib/
│   │   ├── Nav.svelte          Sticky frosted nav, pill links, theme toggle, Download, mobile sheet
│   │   ├── Footer.svelte       Product / Legal / Contact columns + copyright
│   │   ├── Hero.svelte         Headline, App Store badge, fact chips, two DeviceFrames with blue glow
│   │   ├── DeviceFrame.svelte  CSS-only phone bezel (`size`: sm | md | lg)
│   │   ├── FeatureGrid.svelte  8 feature cards with inline SVG icon chips
│   │   ├── Showcase.svelte     Scroll-snap strip of DeviceFrames, prev/next, dots
│   │   ├── CtaBand.svelte      Blue gradient download panel with privacy link and contact
│   │   ├── icons.js            SVG path strings for FeatureGrid
│   │   ├── links.js            App Store, GitHub, license, contact, badge URL helper
│   │   ├── reveal.js           IntersectionObserver action (`use:reveal`), reduced-motion aware
│   │   └── screens.js          Light/dark screenshot pairs from public/screenshots
│   ├── pages/
│   │   ├── Home.svelte         Hero → FeatureGrid → Showcase → CtaBand
│   │   ├── About.svelte        Compact hero, Free / Private / Yours cards, prose
│   │   ├── Roadmap.svelte      Timeline cards with Shipped / Next release / Planned pills
│   │   └── PrivacyPolicy.svelte  Policy text in a prose container with sticky back link
│   └── assets/appstorescreenshots/  App Store marketing JPGs (not currently rendered)
├── public/
│   ├── icon.png                App icon (favicon, nav, footer)
│   ├── og-image.png            1200x630 social card
│   ├── screenshots/            Clean iPhone/iPad PNGs used by Hero and Showcase
│   ├── AppStoreScreenshots/    App Store JPGs
│   ├── robots.txt
│   └── sitemap.xml
├── dist/                       Build output (ignored)
├── package.json
├── vite.config.js              Builds to dist/, publicDir public/
└── svelte.config.js            vitePreprocess
```

## Theme

`:root.dark` toggles dark tokens. Preference is stored in `localStorage` under `claveo-theme`; `index.html` applies it before paint and falls back to `prefers-color-scheme`.

## Run

```bash
cd web
npm install
npm run dev
npm run build
npm run preview
```
