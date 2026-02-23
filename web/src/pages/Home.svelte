<!-- Copyright (c) 2025 Oliver Tran -->
<script>
  export let navigate;
  export let darkMode = false;

  const screenshots = [
    { label: "Practice Recording", light: "/screenshots/recordings-iphone-light.png", dark: "/screenshots/recordings-iphone-dark.png" },
    { label: "Practice Tracking", light: "/screenshots/practice-phone-light.png", dark: "/screenshots/practice-phone-dark.png" },
    { label: "Metronome", light: "/screenshots/metronome-iphone-light.png", dark: "/screenshots/metronome-iphone-dark.png" },
    { label: "Tuner", light: "/screenshots/tuner-iphone-light.png", dark: "/screenshots/tuner-iphone-dark.png" },
    { label: "Music Dictionary", light: "/screenshots/dictionary-iphone-light.png", dark: "/screenshots/dictionary-iphone-dark.png" },
  ];

  let currentSlide = 0;
  let interval;

  function nextSlide() {
    currentSlide = (currentSlide + 1) % screenshots.length;
    resetInterval();
  }

  function resetInterval() {
    if (interval) clearInterval(interval);
    interval = setInterval(nextSlide, 4000);
  }

  import { onMount, onDestroy } from "svelte";
  onMount(() => {
    interval = setInterval(nextSlide, 4000);
  });
  onDestroy(() => {
    if (interval) clearInterval(interval);
  });
</script>

<div class="container">
  <div class="hero-section">
    <h1>Your complete music practice companion.</h1>
    <p class="hero-tagline">Record, track, and improve. All in one app.</p>
  </div>

  <div class="features-gallery-row">
    <div class="features-grid">
      <div class="feature-card">
        <h3>Practice Recording</h3>
        <p>Record unlimited sessions, organize with names and tags. Waveform playback and export to teachers.</p>
      </div>
      <div class="feature-card">
        <h3>Practice Tracking</h3>
        <p>Log sessions, rate yourself, track streaks. Weekly calendar and progress metrics at a glance.</p>
      </div>
      <div class="feature-card">
        <h3>Metronome</h3>
        <p>Tap tempo, custom beat patterns, all time signatures. Haptic feedback for silent practice.</p>
      </div>
      <div class="feature-card">
        <h3>Precision Tuner</h3>
        <p>Real-time pitch detection. Dual meters, customizable A4, chromatic or instrument-specific.</p>
      </div>
      <div class="feature-card">
        <h3>Music Dictionary</h3>
        <p>650+ terms with symbols and definitions. Search from Open Music Theory.</p>
      </div>
      <div class="feature-card feature-card-beta">
        <h3>Optical Music Recognition <span class="beta-badge">BETA</span></h3>
        <p>Scan and digitize sheet music from photos. Convert printed scores into editable digital formats.</p>
      </div>
    </div>
    <div class="gallery-section">
      <div class="gallery-wrapper">
        <div class="gallery-track">
          {#each screenshots as slide, i}
            <div class="gallery-slide" class:active={i === currentSlide}>
              <div class="device-mockup">
                <img src="/screenshots/iPhone 15 Pro - Blue Titanium - Portrait.png" alt="" class="device-frame" />
                <img src={darkMode ? slide.dark : slide.light} alt={slide.label} class="device-screen" />
              </div>
            </div>
          {/each}
        </div>
      </div>
    </div>
  </div>

  <div class="divider"></div>

  <div class="privacy-section">
    <h2>Privacy first</h2>
    <p>Claveo stores everything locally. No data collection, no cloud—your recordings stay on your device.</p>
    <a href="/privacy-policy.html" on:click|preventDefault={() => navigate('/privacy-policy.html')} class="link-primary">Privacy Policy →</a>
  </div>

  <div class="divider"></div>

  <div class="download-section">
    <h2>Get Claveo</h2>
    <p>Free on iPhone and iPad. Recordings sync across your devices.</p>
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
      <a href="https://github.com/olivertransf/Claveo/blob/main/LICENSE" target="_blank" rel="noopener noreferrer" class="link-secondary">License</a>
    </p>
  </footer>
</div>
