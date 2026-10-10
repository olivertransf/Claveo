<!-- Copyright (c) 2025 Oliver Tran -->
<script>
  import { icons } from './icons.js';
  import { reveal } from './reveal.js';

  const features = [
    {
      icon: 'waveform',
      title: 'Recordings',
      body: 'Standard, High, Apple Lossless, or 24-bit WAV. Trim without re-encoding, tag takes, and link them to pieces.'
    },
    {
      icon: 'journal',
      title: 'Practice log',
      body: 'Track time, notes, and ratings. Keep your streak going and jump straight to the takes you linked.'
    },
    {
      icon: 'metronome',
      title: 'Metronome',
      body: 'Tap tempo, any meter, accents, subdivisions, and a reference tone that sits right beside the click.'
    },
    {
      icon: 'tuner',
      title: 'Tuner',
      body: 'Live pitch with cents offset and a custom A4, so you can tune to the ensemble instead of the default.'
    },
    {
      icon: 'exercises',
      title: 'Exercises',
      body: 'Drill note reading, key signatures, and intervals with quick feedback that fits between repetitions.'
    },
    {
      icon: 'chords',
      title: 'Chords and scales',
      body: 'A fast reference for every chord quality and scale in any key, with the notes spelled out.'
    },
    {
      icon: 'dictionary',
      title: 'Dictionary',
      body: 'Hundreds of musical terms, forms, and markings explained in plain language and searchable offline.'
    },
    {
      icon: 'cloud',
      title: 'iCloud sync',
      body: 'Live across iPhone and iPad with sync status, so a take recorded on one shows up on the other.'
    }
  ];
</script>

<section class="section features" id="features">
  <div class="page">
    <div class="section-head" use:reveal>
      <span class="eyebrow">What you get</span>
      <h2>Every tool a practice room needs.</h2>
      <p>Built around the daily routine: record a take, log the session, check pitch and tempo, and look something up.</p>
    </div>

    <div class="grid">
      {#each features as feature, index}
        <article class="card card-hover feature" use:reveal={{ delay: (index % 4) * 70 }}>
          <div class="chip" aria-hidden="true">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
              {@html icons[feature.icon]}
            </svg>
          </div>
          <h3>{feature.title}</h3>
          <p>{feature.body}</p>
        </article>
      {/each}
    </div>
  </div>
</section>

<style>
  .section-head h2 {
    margin-top: 16px;
  }

  .grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
    gap: 18px;
  }

  .feature {
    padding: 26px 24px 28px;
    background: color-mix(in srgb, var(--accent-soft) 45%, var(--surface));
  }

  .chip {
    width: 46px;
    height: 46px;
    display: grid;
    place-items: center;
    border-radius: 14px;
    background: var(--accent-soft);
    color: var(--accent-strong);
    margin-bottom: 18px;
  }

  .feature h3 {
    font-size: var(--text-h3);
    margin-bottom: 8px;
  }

  .feature p {
    font-size: var(--text-small);
    line-height: 1.6;
    color: var(--text-secondary);
  }
</style>
