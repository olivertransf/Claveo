<!-- Copyright (c) 2025 Oliver Tran -->
<script>
  import { onMount, onDestroy } from "svelte";
  import img1343 from "../assets/appstorescreenshots/1343.jpg";
  import img1344 from "../assets/appstorescreenshots/1344.jpg";
  import img1346 from "../assets/appstorescreenshots/1346.jpg";
  import img1347 from "../assets/appstorescreenshots/1347.jpg";
  import img1348 from "../assets/appstorescreenshots/1348.jpg";
  import img1349 from "../assets/appstorescreenshots/1349.jpg";
  import img1350 from "../assets/appstorescreenshots/1350.jpg";
  import img1351 from "../assets/appstorescreenshots/1351.jpg";

  export let navigate;
  export let darkMode = false;

  const screenshots = [
    {
      label: "Recordings — Capture every practice session",
      src: img1344,
    },
    {
      label: "Recording details — Save pieces, tags, and measures",
      src: img1348,
    },
    {
      label: "Practice — Track time, streaks, and journal notes",
      src: img1350,
    },
    {
      label: "Metronome — Stay in rhythm",
      src: img1347,
    },
    {
      label: "Tuner & tone generator — Tune with precision",
      src: img1343,
    },
    {
      label: "Exercises — Note reading, keys, and intervals",
      src: img1349,
    },
    {
      label: "Music dictionary — Master music theory",
      src: img1346,
    },
    {
      label: "Settings — Tab order, appearance, and more",
      src: img1351,
    },
  ];

  function perPageForWidth(w) {
    if (w < 560) return 1;
    if (w < 900) return 2;
    if (w < 1200) return 3;
    return 4;
  }

  let startIndex = 0;
  let perPage = 4;
  let autoTimer;
  /** Viewport inner width (carousel strip between arrows); drives slide widths + transform. */
  let viewportWidth = 0;
  let windowWidth =
    typeof window !== "undefined" ? window.innerWidth : 1200;

  /** Must match `.screenshot-carousel-track` gap in styles.css (18 default, 12 ≤768px). */
  $: carouselGapPx = windowWidth <= 768 ? 12 : 18;

  /** First index of the visible window; advances one screenshot at a time. */
  $: maxStart = Math.max(0, screenshots.length - perPage);
  $: positionCount = maxStart + 1;
  $: slideWidthPx =
    viewportWidth > 0 && perPage > 0
      ? (viewportWidth - (perPage - 1) * carouselGapPx) / perPage
      : 0;
  $: trackOffsetPx = startIndex * (slideWidthPx + carouselGapPx);

  function syncPerPage() {
    if (typeof window === "undefined") return;
    windowWidth = window.innerWidth;
    const next = perPageForWidth(window.innerWidth);
    if (next !== perPage) {
      perPage = next;
      const ms = Math.max(0, screenshots.length - next);
      startIndex = Math.min(startIndex, ms);
      restartAuto();
    }
  }

  function go(delta) {
    const n = maxStart + 1;
    startIndex = (startIndex + delta + n) % n;
    restartAuto();
  }

  function goTo(i) {
    startIndex = Math.max(0, Math.min(maxStart, i));
    restartAuto();
  }

  function restartAuto() {
    if (autoTimer) clearInterval(autoTimer);
    autoTimer = setInterval(() => {
      const n = maxStart + 1;
      startIndex = (startIndex + 1) % n;
    }, 5500);
  }

  onMount(() => {
    windowWidth = window.innerWidth;
    perPage = perPageForWidth(window.innerWidth);
    startIndex = 0;
    const onResize = () => syncPerPage();
    window.addEventListener("resize", onResize);
    restartAuto();
    return () => window.removeEventListener("resize", onResize);
  });

  onDestroy(() => {
    if (autoTimer) clearInterval(autoTimer);
  });
</script>

<div class="container">
  <div class="hero-section">
    <h1>Your complete music practice companion.</h1>
    <p class="hero-tagline">Record, track, and improve. All in one app.</p>
  </div>

  <div class="features-block">
    <div class="features-grid">
      <div class="feature-card">
        <h3>Practice Recording</h3>
        <p>Pieces, tags, and non-destructive trim. Playback speed, search, export.</p>
      </div>
      <div class="feature-card">
        <h3>Practice Tracking</h3>
        <p>Time, notes, ratings, streaks, and weekly totals. Link takes to a session.</p>
      </div>
      <div class="feature-card">
        <h3>Metronome</h3>
        <p>Tap tempo, custom meters, accents, saved tempos, haptics, reference tone.</p>
      </div>
      <div class="feature-card">
        <h3>Precision Tuner</h3>
        <p>Live pitch from the mic—quick and fine views. Custom A4, optional Hz.</p>
      </div>
      <div class="feature-card">
        <h3>Exercises</h3>
        <p>Staff reading, key signatures, and interval ear training.</p>
      </div>
      <div class="feature-card">
        <h3>Chord &amp; Scale Reference</h3>
        <p>Scales and diatonic chords by root—sharp or flat spelling when you need it.</p>
      </div>
      <div class="feature-card">
        <h3>Music Dictionary</h3>
        <p>Search terms across theory, notation, tempo, and dynamics.</p>
      </div>
      <div class="feature-card">
        <h3>Your layout</h3>
        <p>Four tabs plus More. One Settings screen—accent color and light or dark mode.</p>
      </div>
      <div class="feature-card feature-card-beta">
        <h3>Optical Music Recognition <span class="beta-badge">BETA</span></h3>
        <p>Scan photos or PDFs toward editable sheet music.</p>
      </div>
    </div>
  </div>

  <section class="screenshot-gallery" aria-label="App Store screenshots">
    <h2 class="screenshot-gallery-title">Screenshots</h2>
    <p class="screenshot-gallery-lead">Your complete music practice companion—on the App Store and on your device.</p>

    <div class="screenshot-carousel">
      <button type="button" class="screenshot-carousel-btn screenshot-carousel-btn-prev" aria-label="Previous screenshot" on:click={() => go(-1)}>
        ‹
      </button>
      <div class="screenshot-carousel-viewport" bind:clientWidth={viewportWidth}>
        <div
          class="screenshot-carousel-track"
          style="transform: translate3d(-{trackOffsetPx}px, 0, 0);"
        >
          {#each screenshots as shot (shot.src)}
            <figure
              class="screenshot-gallery-item screenshot-carousel-slide"
              style={slideWidthPx > 0
                ? `flex:0 0 ${slideWidthPx}px;width:${slideWidthPx}px;min-width:${slideWidthPx}px`
                : undefined}
            >
              <div class="screenshot-gallery-frame">
                <img src={shot.src} alt={shot.label} loading="lazy" decoding="async" />
              </div>
              <figcaption>{shot.label}</figcaption>
            </figure>
          {/each}
        </div>
      </div>
      <button type="button" class="screenshot-carousel-btn screenshot-carousel-btn-next" aria-label="Next screenshot" on:click={() => go(1)}>
        ›
      </button>
    </div>

    {#if positionCount > 1}
      <div class="screenshot-carousel-dots" role="tablist" aria-label="Screenshot positions">
        {#each Array.from({ length: positionCount }, (_, i) => i) as dotIndex}
          <button
            type="button"
            role="tab"
            class="screenshot-carousel-dot"
            class:active={dotIndex === startIndex}
            aria-selected={dotIndex === startIndex}
            aria-label="Screenshot {dotIndex + 1} of {positionCount}"
            on:click={() => goTo(dotIndex)}
          ></button>
        {/each}
      </div>
    {/if}
  </section>

  <div class="divider"></div>

  <div class="privacy-section">
    <h2>Privacy first</h2>
    <p>No ads. Your recordings and practice data stay under your control—on device, and optionally synced with iCloud when you use the same Apple ID. See the policy for details.</p>
    <a href="/privacy-policy.html" on:click|preventDefault={() => navigate('/privacy-policy.html')} class="link-primary">Privacy Policy →</a>
  </div>

  <div class="divider"></div>

  <div class="download-section">
    <h2>Get Claveo</h2>
    <p>Free on iPhone and iPad. Recordings and practice logs can stay in sync across your devices with iCloud.</p>
    <a href="https://apps.apple.com/us/app/claveo-music-companion/id6755795790" class="app-badge" target="_blank" rel="noopener noreferrer">
      <img src={darkMode ? "https://tools.applemediaservices.com/api/badges/download-on-the-app-store/white/en-us?size=250x83&releaseDate=1289433600" : "https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/en-us?size=250x83&releaseDate=1289433600"} alt="Download on the App Store" />
    </a>
  </div>

  <div class="divider"></div>

  <div class="contact-section">
    <p>Have questions or need help?</p>
    <p><a href="mailto:claveo.app@gmail.com" class="link-primary">claveo.app@gmail.com</a></p>
  </div>

  <footer>
    <p>&copy; 2025 Oliver Tran</p>
    <p>
      <a href="/privacy-policy.html" on:click|preventDefault={() => navigate('/privacy-policy.html')} class="link-secondary">Privacy</a>
      <span class="footer-separator">·</span>
      <a href="https://github.com/olivertransf/Claveo" target="_blank" rel="noopener noreferrer" class="link-secondary">GitHub</a>
      <span class="footer-separator">·</span>
      <a href="https://github.com/olivertransf/Claveo/blob/main/LICENSE" target="_blank" rel="noopener noreferrer" class="link-secondary">License</a>
    </p>
  </footer>
</div>
