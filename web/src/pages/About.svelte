<!-- Copyright (c) 2025 Oliver Tran -->
<script>
  import { reveal } from '../lib/reveal.js';
  import { APP_STORE_URL, CONTACT_EMAIL, appStoreBadge } from '../lib/links.js';

  export let navigate;
  export let darkMode = false;

  const values = [
    {
      title: 'Free',
      body: 'No subscriptions, no ads, no in-app purchases. Every feature is included from the first launch.'
    },
    {
      title: 'Private',
      body: 'Recordings and practice data live on your devices and in your own iCloud. There is no server on my side.'
    },
    {
      title: 'Yours',
      body: 'Choose recording formats, reorder the tabs, and keep your practice history as long as you like.'
    }
  ];
</script>

<section class="hero">
  <div class="page">
    <span class="eyebrow">About</span>
    <h1>A free app for musicians, made by one.</h1>
    <p class="lead">
      Claveo started as the practice tools I wanted in one place: a recorder that keeps full quality, a log that
      remembers what I worked on, and a metronome and tuner that open instantly.
    </p>
  </div>
</section>

<section class="values">
  <div class="page grid">
    {#each values as value, index}
      <article class="card card-hover value" use:reveal={{ delay: index * 80 }}>
        <h2>{value.title}</h2>
        <p>{value.body}</p>
      </article>
    {/each}
  </div>
</section>

<section class="section story">
  <div class="page prose" use:reveal>
    <h2>What Claveo offers</h2>
    <p>
      Record in Standard, High, Apple Lossless, or 24-bit WAV, then trim takes without re-encoding so an audition
      excerpt sounds exactly as it was played. Link recordings to pieces, tag them, and leave notes with measure
      numbers. The practice log tracks time, ratings, and streaks, and the metronome, tuner, exercises, chord and
      scale reference, and dictionary cover the rest of a session.
    </p>
    <p>
      Everything syncs live between iPhone and iPad through your iCloud account, with sync status visible in the
      app so you always know what has landed on the other device.
    </p>

    <h2>My commitment</h2>
    <p>
      Claveo will stay free and will not add tracking or advertising. I build it in the open, so if something is
      wrong or missing, you can tell me directly and watch it get fixed.
    </p>

    <h2>Privacy first</h2>
    <p>
      I do not collect, transmit, or have access to any of your data. The full details are in the
      <a href="/privacy-policy" class="link" on:click|preventDefault={() => navigate('/privacy-policy')}>privacy policy</a>.
    </p>

    <h2>Get in touch</h2>
    <p>
      Questions, bugs, or ideas: <a href={`mailto:${CONTACT_EMAIL}`} class="link">{CONTACT_EMAIL}</a>
    </p>

    <a href={APP_STORE_URL} target="_blank" rel="noopener noreferrer" class="badge">
      <img src={appStoreBadge(darkMode)} alt="Download on the App Store" width="166" height="55" />
    </a>
  </div>
</section>

<style>
  .hero {
    padding: clamp(56px, 8vw, 104px) 0 clamp(32px, 5vw, 56px);
  }

  .hero .page {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: 18px;
    max-width: calc(var(--page-max));
  }

  h1 {
    font-size: var(--text-h1);
    font-weight: 800;
    max-width: 18ch;
  }

  .hero .lead {
    max-width: 38rem;
  }

  .grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
    gap: 18px;
  }

  .value {
    padding: 28px 26px;
    background: color-mix(in srgb, var(--accent-soft) 50%, var(--surface));
  }

  .value h2 {
    font-size: 1.4rem;
    color: var(--accent-strong);
    margin-bottom: 10px;
  }

  .value p {
    color: var(--text-secondary);
    font-size: var(--text-small);
    line-height: 1.6;
  }

  .story {
    padding-top: clamp(56px, 8vw, 96px);
  }

  .badge {
    display: inline-block;
    margin-top: 2.2rem;
    border-radius: 12px;
    transition: transform 0.2s var(--ease-out);
  }

  .badge:hover {
    transform: translateY(-2px);
  }

  .badge img {
    width: 166px;
    height: auto;
  }
</style>
