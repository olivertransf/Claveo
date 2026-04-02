<!-- Copyright (c) 2025 Oliver Tran -->
<script>
  export let navigate;
</script>

<div class="container privacy-container">
  <a href="/" on:click|preventDefault={() => navigate('/')} class="back-link">← Back to Home</a>
  
  <header>
    <h1>Privacy Policy</h1>
  </header>

  <p class="last-updated">Last updated: April 2026</p>

  <div class="section privacy-section">
    <h2>Introduction</h2>
    <p>I, Oliver Tran, develop Claveo and am committed to protecting your privacy. In this policy, "I," "me," and "my" refer to me as the developer. This Privacy Policy explains how your data is handled when you use the Claveo mobile application.</p>
    <p><strong>Important:</strong> I do not collect, transmit, or have access to any of your personal data. All data remains on your device and in your personal iCloud account.</p>
  </div>

  <div class="section privacy-section">
    <h2>Data Storage</h2>
    <p>Claveo stores the following types of data locally on your device:</p>
    <ul>
      <li><strong>Audio Recordings:</strong> When you record practice sessions, audio files are stored locally on your device and optionally synced to your personal iCloud account.</li>
      <li><strong>Metadata:</strong> Information you provide about recordings, including names, tags, notes, piece information, and measure numbers.</li>
      <li><strong>Practice journal:</strong> Practice session entries (duration, notes, ratings, links to recordings) stored like other app documents, optionally in iCloud.</li>
      <li><strong>App Settings:</strong> Your preferences and settings within the app, such as metronome tempo, tuner settings, tab order, and display preferences.</li>
    </ul>
    <p><strong>I do not collect this data.</strong> It is stored entirely on your device and in your personal iCloud account (if iCloud sync is enabled). I have no access to any of this information.</p>
  </div>

  <div class="section privacy-section">
    <h2>How Your Data is Used</h2>
    <p>Your data is used solely by the app to:</p>
    <ul>
      <li>Provide app functionality (playing recordings, syncing across your devices)</li>
      <li>Store your recordings and metadata for your personal use</li>
      <li>Sync your data across your devices via your personal iCloud account</li>
    </ul>
    <p>I do not use your data for analytics, advertising, or any other purpose. I cannot access your data.</p>
  </div>

  <div class="section privacy-section">
    <h2>Data Storage and Security</h2>
    <p>All audio recordings and metadata are stored:</p>
    <ul>
      <li>Locally on your device</li>
      <li>In your personal iCloud account (if iCloud is enabled)</li>
    </ul>
    <p><strong>I do not have access to any of your data.</strong> All data remains under your control and is subject to Apple's iCloud privacy and security policies. I do not transmit data to any external servers or third parties.</p>
  </div>

  <div class="section privacy-section">
    <h2>Microphone Access</h2>
    <p>Claveo requires microphone access to:</p>
    <ul>
      <li>Record audio practice sessions</li>
      <li>Provide pitch detection for the tuner feature</li>
    </ul>
    <p>The app uses the microphone only when you use recording or the tuner. I do not receive your audio; recording and pitch detection run on your device.</p>
  </div>

  <div class="section privacy-section">
    <h2>Analytics and Tracking</h2>
    <p>Claveo does not use any analytics services, tracking tools, or third-party data collection. I do not track your usage, collect crash reports, or gather any telemetry data.</p>
  </div>

  <div class="section privacy-section">
    <h2>Third-Party Libraries</h2>
    <p>Claveo includes the following open-source libraries (via Swift Package Manager). They run on your device only—I do not use them to collect or send your data to servers.</p>
    <ul>
      <li>
        <strong>Tuna</strong> (<a href="https://github.com/alladinian/Tuna" class="link-primary" target="_blank" rel="noopener noreferrer">GitHub</a>) — MIT License. Pitch detection for the tuner; microphone audio is analyzed locally and is not sent to me or to third parties.
      </li>
      <li>
        <strong>VexFoundation</strong> (<a href="https://github.com/migueldeicaza/VexFoundation" class="link-primary" target="_blank" rel="noopener noreferrer">GitHub</a>) — MIT License (based on Vex Flow). Renders staff notation in exercise features (for example note reading). Rendering happens on device; it does not upload your scores or practice content.
      </li>
    </ul>
    <p>If I add or replace libraries in a future version, I will update this list so it stays accurate.</p>
  </div>

  <div class="section privacy-section">
    <h2>Data Sharing</h2>
    <p>I do not collect, share, sell, or distribute your personal information or recordings to anyone. Your data remains private and is only accessible to you through your device and iCloud account. I have no access to your data.</p>
  </div>

  <div class="section privacy-section">
    <h2>Changes to This Privacy Policy</h2>
    <p>I may update this Privacy Policy from time to time. I will notify you of any changes by posting the new Privacy Policy on this page and updating the "Last updated" date.</p>
  </div>

  <div class="section privacy-section">
    <h2>Contact</h2>
    <p>If you have any questions about this Privacy Policy, please contact me at:</p>
    <p><a href="mailto:claveo.app@gmail.com" class="link-primary">claveo.app@gmail.com</a></p>
  </div>

  <footer class="privacy-footer">
    <p>&copy; 2025 Oliver Tran. All rights reserved.</p>
  </footer>
</div>
