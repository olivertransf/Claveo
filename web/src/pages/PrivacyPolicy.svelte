<!-- Copyright (c) 2025 Oliver Tran -->
<script>
  export let navigate;
</script>

<div class="page privacy">
  <div class="back-wrap">
    <a href="/" on:click|preventDefault={() => navigate('/')} class="back-link">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M15 5l-7 7 7 7"/></svg>
      Back to Home
    </a>
  </div>

  <header class="privacy-head">
    <span class="eyebrow">Legal</span>
    <h1>Privacy Policy</h1>
    <p class="last-updated">Last updated: October 2026</p>
  </header>

  <div class="prose">

  <div class="privacy-section">
    <h2>Introduction</h2>
    <p>I, Oliver Tran, develop Claveo and am committed to protecting your privacy. In this policy, "I," "me," and "my" refer to me as the developer. This Privacy Policy explains how your data is handled when you use the Claveo mobile application.</p>
    <p><strong>Important:</strong> I do not collect or have access to your personal data, and I do not run a server that receives it. Your recordings, photos, notes, and practice history stay on your device and in your personal iCloud account. Speech recognition, described below, is the only case where audio may leave your device, and then only to Apple.</p>
  </div>

  <div class="privacy-section">
    <h2>Data Storage</h2>
    <p>Claveo stores the following types of data locally on your device:</p>
    <ul>
      <li><strong>Audio Recordings:</strong> When you record practice sessions, audio files are stored locally on your device and optionally synced to your personal iCloud account.</li>
      <li><strong>Practice photos:</strong> Photos you take or choose of the edition you are practicing, stored with that practice entry.</li>
      <li><strong>Voice memos:</strong> Short recordings you attach to a practice entry, plus a transcript when speech recognition produces one.</li>
      <li><strong>Metadata:</strong> Information you provide about recordings, including names, tags, notes, piece information, and measure numbers.</li>
      <li><strong>Practice journal:</strong> Practice session entries (date, duration, notes, ratings, and links to recordings) stored like other app documents, optionally in iCloud.</li>
      <li><strong>App Settings:</strong> Your preferences and settings within the app, such as metronome tempo, tuner settings, tab order, and display preferences.</li>
    </ul>
    <p><strong>I do not collect this data.</strong> It is stored entirely on your device and in your personal iCloud account (if iCloud sync is enabled). I have no access to any of this information.</p>
  </div>

  <div class="privacy-section">
    <h2>How Your Data is Used</h2>
    <p>Your data is used solely by the app to:</p>
    <ul>
      <li>Provide app functionality (playing recordings, showing your journal, syncing across your devices)</li>
      <li>Store your recordings, photos, voice memos, transcripts, and metadata for your personal use</li>
      <li>Turn a voice memo into text when you ask the app to transcribe it</li>
      <li>Sync your data across your devices via your personal iCloud account</li>
    </ul>
    <p>I do not use your data for analytics, advertising, or any other purpose. I cannot access your data.</p>
  </div>

  <div class="privacy-section">
    <h2>Data Storage and Security</h2>
    <p>Audio recordings, practice photos, voice memos, transcripts, and metadata are stored:</p>
    <ul>
      <li>Locally on your device</li>
      <li>In your personal iCloud account (if iCloud is enabled)</li>
    </ul>
    <p><strong>I do not have access to any of your data.</strong> All data remains under your control and is subject to Apple's iCloud privacy and security policies. I do not operate a server that receives your recordings, photos, notes, or transcripts, and I do not send them to advertisers or analytics companies.</p>
  </div>

  <div class="privacy-section">
    <h2>Microphone Access</h2>
    <p>Claveo requires microphone access to:</p>
    <ul>
      <li>Record audio practice sessions</li>
      <li>Record voice memos on a practice entry</li>
      <li>Provide pitch detection for the tuner feature</li>
    </ul>
    <p>The app uses the microphone only while you are recording or using the tuner. I do not receive your audio. Recording and pitch detection run on your device.</p>
  </div>

  <div class="privacy-section">
    <h2>Camera and Photos</h2>
    <p>Claveo uses the camera only when you choose to photograph the edition you are practicing. You can also pick a photo you already have. The system photo picker lets you choose one image. It does not give the app access to your whole photo library.</p>
    <p>The photo is saved with that practice entry on your device and, if iCloud is on, in your iCloud account. I do not receive it.</p>
  </div>

  <div class="privacy-section">
    <h2>Speech Recognition</h2>
    <p>If you record a voice memo, Claveo can transcribe it with Apple's speech recognition and save the text with that practice entry. The transcript can be wrong. Transcription runs only for a memo you recorded in the app.</p>
    <p>When your device can recognize speech locally, the memo stays on the device. The first transcription may download an Apple speech model onto the device. That download is the model, not your recording.</p>
    <p>If on-device recognition is not available, Apple's speech recognition service may receive that memo's audio in order to return a transcript. I do not receive the audio or the transcript. You can refuse or turn off speech recognition in iOS Settings, under Privacy &amp; Security, and the memo will still be saved without a transcript.</p>
  </div>

  <div class="privacy-section">
    <h2>Analytics and Tracking</h2>
    <p>Claveo does not use any analytics services, tracking tools, or third-party data collection. I do not track your usage, collect crash reports, or gather any telemetry data.</p>
  </div>

  <div class="privacy-section">
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

  <div class="privacy-section">
    <h2>Data Sharing</h2>
    <p>I do not collect, share, sell, or distribute your personal information or recordings to anyone. Your data remains private and is only accessible to you through your device and iCloud account. I have no access to your data.</p>
  </div>

  <div class="privacy-section">
    <h2>Changes to This Privacy Policy</h2>
    <p>I may update this Privacy Policy from time to time. I will notify you of any changes by posting the new Privacy Policy on this page and updating the "Last updated" date.</p>
  </div>

  <div class="privacy-section">
    <h2>Contact</h2>
    <p>If you have any questions about this Privacy Policy, please contact me at:</p>
    <p><a href="mailto:claveo.app@gmail.com" class="link-primary">claveo.app@gmail.com</a></p>
  </div>

  <footer class="privacy-footer">
    <p>&copy; 2026 Oliver Tran. All rights reserved.</p>
  </footer>
  </div>
</div>

<style>
  .privacy {
    padding-top: 24px;
    padding-bottom: clamp(64px, 8vw, 112px);
  }

  .back-wrap {
    position: sticky;
    top: calc(var(--nav-height) + 12px);
    z-index: 5;
    max-width: var(--prose-max);
    margin: 0 auto;
    display: flex;
  }

  .back-link {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 8px 14px 8px 10px;
    border-radius: var(--radius-pill);
    border: 1px solid var(--border);
    background: color-mix(in srgb, var(--bg) 85%, transparent);
    backdrop-filter: blur(12px);
    -webkit-backdrop-filter: blur(12px);
    font-size: var(--text-small);
    font-weight: 600;
    color: var(--text-secondary);
    text-decoration: none;
    transition: color 0.2s ease, border-color 0.2s ease;
  }

  .back-link:hover {
    color: var(--accent-strong);
    border-color: var(--accent);
  }

  .privacy-head {
    max-width: var(--prose-max);
    margin: 40px auto 40px;
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: 14px;
    padding-bottom: 32px;
    border-bottom: 1px solid var(--border);
  }

  .privacy-head h1 {
    font-size: var(--text-h1);
    font-weight: 800;
  }

  .last-updated {
    font-size: var(--text-small);
    color: var(--text-tertiary);
  }

  .privacy-section + .privacy-section {
    margin-top: 2.5rem;
  }

  .privacy-footer {
    margin-top: 3.5rem;
    padding-top: 1.5rem;
    border-top: 1px solid var(--border);
    font-size: var(--text-small);
    color: var(--text-tertiary);
  }

  .privacy-footer p {
    font-size: var(--text-small);
    color: var(--text-tertiary);
  }
</style>
