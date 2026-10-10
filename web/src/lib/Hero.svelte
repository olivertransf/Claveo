<!-- Copyright (c) 2025 Oliver Tran -->
<script>
  import DeviceFrame from './DeviceFrame.svelte';
  import { APP_STORE_URL, appStoreBadge } from './links.js';
  import { screens, screenSrc } from './screens.js';

  export let darkMode = false;

  $: heroFront = screenSrc(screens.recordings, darkMode);
  $: heroBack = screenSrc(screens.practice, darkMode);

  const facts = ['No ads', 'Lossless recording', 'iCloud sync'];
</script>

<section class="hero">
  <div class="page grid">
    <div class="copy">
      <span class="eyebrow">Free on iPhone and iPad</span>
      <h1>Practice with everything in one place.</h1>
      <p class="lead">
        Record every take in full quality, keep a practice log, and tune up with a metronome and tuner that stay out of your way.
      </p>
      <div class="actions">
        <a href={APP_STORE_URL} target="_blank" rel="noopener noreferrer" class="badge">
          <img src={appStoreBadge(darkMode)} alt="Download on the App Store" width="166" height="55" />
        </a>
        <ul class="facts" aria-label="Highlights">
          {#each facts as fact}
            <li>
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                <path d="M5 12.5l4.5 4.5L19 7.5"></path>
              </svg>
              {fact}
            </li>
          {/each}
        </ul>
      </div>
    </div>

    <div class="devices" aria-hidden="true">
      <div class="device back">
        <DeviceFrame src={heroBack} size="sm" loading="eager" />
      </div>
      <div class="device front">
        <DeviceFrame src={heroFront} size="md" loading="eager" />
      </div>
    </div>
  </div>
</section>

<style>
  .hero {
    position: relative;
    overflow: hidden;
    padding: clamp(48px, 8vw, 112px) 0 clamp(56px, 8vw, 96px);
  }

  .grid {
    position: relative;
    display: grid;
    grid-template-columns: 1fr;
    gap: 56px;
    align-items: center;
  }

  .copy {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: 22px;
    max-width: 36rem;
  }

  h1 {
    font-size: var(--text-display);
    font-weight: 800;
    letter-spacing: -0.04em;
    line-height: 1.02;
  }

  .actions {
    display: flex;
    flex-direction: column;
    gap: 20px;
    margin-top: 6px;
  }

  .badge {
    display: inline-block;
    border-radius: 12px;
    transition: transform 0.2s var(--ease-out), filter 0.2s ease;
  }

  .badge:hover {
    transform: translateY(-2px);
    filter: brightness(1.05);
  }

  .badge img {
    width: 166px;
    height: auto;
  }

  .facts {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-wrap: wrap;
    gap: 10px;
  }

  .facts li {
    display: inline-flex;
    align-items: center;
    gap: 7px;
    padding: 7px 13px;
    border-radius: var(--radius-pill);
    border: 1px solid var(--border);
    background: var(--surface);
    color: var(--text-secondary);
    font-size: var(--text-small);
    font-weight: 500;
  }

  .facts svg {
    color: var(--accent);
  }

  .devices {
    position: relative;
    display: flex;
    justify-content: center;
    min-height: 420px;
  }

  .device {
    position: absolute;
  }

  .device.front {
    transform: rotate(-4deg);
    z-index: 2;
    animation: float 9s ease-in-out infinite;
  }

  .device.back {
    transform: translate(130px, 70px) rotate(6deg);
    opacity: 0.92;
    z-index: 1;
    animation: float-back 11s ease-in-out infinite;
  }

  @keyframes float {
    0%,
    100% {
      transform: rotate(-4deg) translateY(0);
    }
    50% {
      transform: rotate(-4deg) translateY(-10px);
    }
  }

  @keyframes float-back {
    0%,
    100% {
      transform: translate(130px, 70px) rotate(6deg);
    }
    50% {
      transform: translate(130px, 60px) rotate(6deg);
    }
  }

  @media (max-width: 959px) {
    .devices {
      min-height: 0;
      height: 680px;
      align-items: flex-start;
      margin-top: -12px;
    }
  }

  @media (max-width: 480px) {
    .device.back {
      transform: translate(105px, 70px) rotate(6deg);
    }

    @keyframes float-back {
      0%,
      100% {
        transform: translate(105px, 70px) rotate(6deg);
      }
      50% {
        transform: translate(105px, 60px) rotate(6deg);
      }
    }
  }

  @media (min-width: 960px) {
    .grid {
      grid-template-columns: 1.05fr 0.95fr;
      gap: 32px;
    }

    .devices {
      min-height: 620px;
      justify-content: flex-end;
      padding-right: 60px;
    }

    .device.front {
      right: 150px;
    }

    .device.back {
      right: 150px;
    }
  }

  @media (prefers-reduced-motion: reduce) {
    .device.front,
    .device.back {
      animation: none;
    }
  }
</style>
