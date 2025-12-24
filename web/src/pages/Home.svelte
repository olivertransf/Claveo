<!-- Copyright (c) 2025 Oliver Tran -->
<script>
  export let navigate;
  export let darkMode = false;
</script>

<div class="container">
  <div class="section hero-section">
    <h1>Your complete music practice companion.</h1>
  </div>

  <!-- <div class="section device-showcase">
    <div class="device-mockups">
      <div class="device-frame ipad-frame">
        <img src="/screenshots/iPad Pro 11_ - M4 - Silver - Landscape.png" alt="iPad frame" class="device-outline" />
        <img src={darkMode ? "/screenshots/recordings-ipad-dark.png" : "/screenshots/recordings-ipad-light.png"} alt="Claveo on iPad" class="device-screenshot" />
      </div>
      <div class="device-frame iphone-frame">
        <img src="/screenshots/iPhone 15 Pro - Blue Titanium - Portrait.png" alt="iPhone frame" class="device-outline" />
        <img src={darkMode ? "/screenshots/recordings-iphone-dark.png" : "/screenshots/recordings-iphone-light.png"} alt="Claveo on iPhone" class="device-screenshot" />
      </div>
    </div>
  </div> -->

  <div class="section">
    <div class="features">
      <div class="feature-item feature-left">
        <div class="feature-device">
          <div class="device-frame feature-iphone-frame">
            <img src="/screenshots/iPhone 15 Pro - Blue Titanium - Portrait.png" alt="iPhone frame" class="device-outline" />
            <img src={darkMode ? "/screenshots/recordings-iphone-dark.png" : "/screenshots/recordings-iphone-light.png"} alt="Practice Recording" class="device-screenshot" />
          </div>
        </div>
        <div class="feature-content">
          <h3>Practice Recording</h3>
          <p>Record unlimited practice sessions with crystal-clear audio. Organize recordings with custom names, tags, and piece associations. All recordings sync seamlessly across your devices.</p>
          <p>Review your progress with detailed playback controls and waveform visualization. Export and share recordings with teachers and collaborators.</p>
        </div>
      </div>

      <div class="feature-item feature-right">
        <div class="feature-content">
          <h3>Practice Tracking</h3>
          <p>Track your daily practice sessions and build consistent habits. Log practice time, rate sessions, and add notes about your progress. Visualize streaks and weekly statistics at a glance.</p>
          <p>Monitor your consistency with a weekly calendar view and track key metrics like your current streak, total practice time, and average session rating.</p>
        </div>
        <div class="feature-device">
          <div class="device-frame feature-iphone-frame">
            <img src="/screenshots/iPhone 15 Pro - Blue Titanium - Portrait.png" alt="iPhone frame" class="device-outline" />
            <img src={darkMode ? "/screenshots/practice-phone-dark.png" : "/screenshots/practice-phone-light.png"} alt="Practice Tracking" class="device-screenshot" />
          </div>
        </div>
      </div>

      <div class="feature-item feature-left">
        <div class="feature-device">
          <div class="device-frame feature-iphone-frame">
            <img src="/screenshots/iPhone 15 Pro - Blue Titanium - Portrait.png" alt="iPhone frame" class="device-outline" />
            <img src={darkMode ? "/screenshots/metronome-iphone-dark.png" : "/screenshots/metronome-iphone-light.png"} alt="Advanced Metronome" class="device-screenshot" />
          </div>
        </div>
        <div class="feature-content">
          <h3>Advanced Metronome</h3>
          <p>Precise tempo control with tap tempo, customizable beat patterns, and support for all time signatures. Haptic feedback for silent practice.</p>
          <p>Save favorite tempos and time signatures as presets. Create complex rhythmic patterns with accent beats and subdivisions.</p>
        </div>
      </div>

      <div class="feature-item feature-right">
        <div class="feature-content">
          <h3>Precision Tuner</h3>
          <p>Real-time pitch detection with professional accuracy. Dual tuning meters with visual feedback. Works with any instrument and customizable A4 reference frequency.</p>
          <p>Get instant visual feedback with color-coded indicators. Fine-tune your instrument with precision down to the cent, with support for both chromatic and instrument-specific tuning modes.</p>
        </div>
        <div class="feature-device">
          <div class="device-frame feature-iphone-frame">
            <img src="/screenshots/iPhone 15 Pro - Blue Titanium - Portrait.png" alt="iPhone frame" class="device-outline" />
            <img src={darkMode ? "/screenshots/tuner-iphone-dark.png" : "/screenshots/tuner-iphone-light.png"} alt="Precision Tuner" class="device-screenshot" />
          </div>
        </div>
      </div>

      <div class="feature-item feature-left">
        <div class="feature-device">
          <div class="device-frame feature-iphone-frame">
            <img src="/screenshots/iPhone 15 Pro - Blue Titanium - Portrait.png" alt="iPhone frame" class="device-outline" />
            <img src={darkMode ? "/screenshots/dictionary-iphone-dark.png" : "/screenshots/dictionary-iphone-light.png"} alt="Music Dictionary" class="device-screenshot" />
          </div>
        </div>
        <div class="feature-content">
          <h3>Music Dictionary</h3>
          <p>Searchable database of music terms and definitions. Curated from Open Music Theory with musical symbols and detailed explanations.</p>
          <p>Look up any musical term instantly with fast, intuitive search. Each entry includes proper musical notation symbols, pronunciation guides, and comprehensive explanations.</p>
        </div>
      </div>
    </div>
  </div>
  <div class="divider"></div>

  <div class="section privacy-data-section">
    <h2>Privacy & Data</h2>
    <p>Your privacy is important. Claveo does not collect, transmit, or have access to any of your personal data. All recordings are stored locally on your device.</p>
    <p class="margin-top">
      <a href="/privacy-policy.html" on:click|preventDefault={() => navigate('/privacy-policy.html')} class="link-primary">Privacy Policy →</a>
    </p>
  </div>

  <div class="divider"></div>

  <div class="download-section">
    <h2 class="download-heading">Get Claveo</h2>
    <p class="download-description">
      Claveo is free to use. You can use Claveo on all your devices—your recordings sync seamlessly. Our app is available on iPhone and iPad.
    </p>
    <a href="https://apps.apple.com/us/app/claveo-music-companion/id6755795790" class="app-badge" target="_blank" rel="noopener noreferrer">
      <img src="https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/en-us?size=250x83&releaseDate=1289433600" alt="Download on the App Store" />
    </a>
  </div>

  <div class="divider"></div>

  <div class="contact-section">
    <p>Have questions or need help?</p>
    <p>
      <a href="mailto:claveo.app@gmail.com" class="link-primary">claveo.app@gmail.com</a>
    </p>
  </div>

  <footer>
    <p>&copy; 2025 Oliver Tran. All rights reserved.</p>
    <p class="margin-top">
      <a href="/privacy-policy.html" on:click|preventDefault={() => navigate('/privacy-policy.html')} class="link-secondary">Privacy Policy</a>
      <span class="footer-separator"> • </span>
      <a href="https://github.com/olivertransf/Claveo/blob/main/LICENSE" target="_blank" rel="noopener noreferrer" class="link-secondary">License</a>
    </p>
  </footer>
</div>
