<!-- Copyright (c) 2025 Oliver Tran -->
<script>
  import { reveal } from '../lib/reveal.js';
  import { CONTACT_EMAIL } from '../lib/links.js';

  const statusLabel = {
    shipped: 'Shipped',
    next: 'Next release',
    planned: 'Planned'
  };

  const timeline = [
    {
      status: 'shipped',
      title: 'Exercises and theory tools',
      body: 'Note reading, key signatures, and interval drills, plus the chord and scale reference and the music dictionary.'
    },
    {
      status: 'shipped',
      title: 'Recording and practice polish',
      body: 'Pieces linked to takes, measure notes, tags, playback speed, and a practice journal with streaks.'
    },
    {
      status: 'next',
      title: 'iOS 18 shell and motion',
      body: 'A native tab bar, a shared design system, and subtle state-change animation across the app.'
    },
    {
      status: 'next',
      title: 'Recording quality presets',
      body: 'Standard, High, Apple Lossless, and 24-bit WAV, with trimming that never re-encodes the audio.'
    },
    {
      status: 'next',
      title: 'Live iCloud sync',
      body: 'Per-record metadata that merges cleanly between devices, with sync status shown in the app.'
    },
    {
      status: 'planned',
      title: 'Practice analytics',
      body: 'Trends over weeks and months, time per piece, and a clearer picture of what is improving.'
    },
    {
      status: 'planned',
      title: 'Collaboration',
      body: 'Share a take or a practice log entry with a teacher or ensemble partner.'
    }
  ];
</script>

<section class="hero">
  <div class="page">
    <span class="eyebrow">Roadmap</span>
    <h1>Where Claveo is headed.</h1>
    <p class="lead">What has shipped, what is in the next release, and what is still being shaped. Dates are intentionally absent; items move when they are ready.</p>
  </div>
</section>

<section class="section timeline-section">
  <div class="page">
    <ol class="timeline">
      {#each timeline as item, index}
        <li class={`entry ${item.status}`} use:reveal={{ delay: Math.min(index, 4) * 60 }}>
          <span class="marker" aria-hidden="true"></span>
          <article class="card card-hover">
            <span class={`status ${item.status}`}>{statusLabel[item.status]}</span>
            <h2>{item.title}</h2>
            <p>{item.body}</p>
          </article>
        </li>
      {/each}
    </ol>

    <div class="suggest card" use:reveal>
      <div>
        <h2>Have a suggestion?</h2>
        <p>Tell me what would make your practice easier. The roadmap is built from these messages.</p>
      </div>
      <a href={`mailto:${CONTACT_EMAIL}`} class="btn btn-primary">Email {CONTACT_EMAIL}</a>
    </div>
  </div>
</section>

<style>
  .hero {
    padding: clamp(56px, 8vw, 104px) 0 clamp(24px, 4vw, 40px);
  }

  .hero .page {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: 18px;
  }

  h1 {
    font-size: var(--text-h1);
    font-weight: 800;
  }

  .hero .lead {
    max-width: 38rem;
  }

  .timeline-section {
    padding-top: clamp(32px, 5vw, 56px);
  }

  .timeline {
    list-style: none;
    margin: 0 auto;
    padding: 0;
    max-width: 760px;
    position: relative;
  }

  .timeline::before {
    content: '';
    position: absolute;
    left: 11px;
    top: 12px;
    bottom: 12px;
    width: 2px;
    background: var(--border-strong);
  }

  .entry {
    position: relative;
    padding-left: 44px;
  }

  .entry + .entry {
    margin-top: 18px;
  }

  .marker {
    position: absolute;
    left: 4px;
    top: 26px;
    width: 16px;
    height: 16px;
    border-radius: 50%;
    background: var(--bg);
    border: 3px solid var(--border-strong);
  }

  .entry.shipped .marker {
    border-color: var(--success);
    background: var(--success);
  }

  .entry.next .marker {
    border-color: var(--accent);
    background: var(--accent);
    box-shadow: 0 0 0 6px var(--accent-soft);
  }

  .entry .card {
    padding: 24px 26px;
  }

  .status {
    display: inline-flex;
    align-items: center;
    padding: 4px 11px;
    border-radius: var(--radius-pill);
    font-size: var(--text-xs);
    font-weight: 600;
    letter-spacing: 0.02em;
    margin-bottom: 12px;
  }

  .status.shipped {
    background: var(--success-soft);
    color: var(--success);
  }

  .status.next {
    background: var(--accent-soft);
    color: var(--accent-strong);
  }

  .status.planned {
    border: 1px solid var(--border-strong);
    color: var(--text-secondary);
  }

  .entry h2 {
    font-size: 1.25rem;
    margin-bottom: 8px;
  }

  .entry p {
    font-size: var(--text-small);
    color: var(--text-secondary);
    line-height: 1.6;
  }

  .suggest {
    max-width: 760px;
    margin: 56px auto 0;
    padding: 28px 30px;
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    justify-content: space-between;
    gap: 20px;
    background: color-mix(in srgb, var(--accent-soft) 50%, var(--surface));
  }

  .suggest h2 {
    font-size: 1.3rem;
    margin-bottom: 6px;
  }

  .suggest p {
    color: var(--text-secondary);
    font-size: var(--text-small);
    max-width: 30rem;
  }

  .suggest .btn {
    flex: none;
  }
</style>
