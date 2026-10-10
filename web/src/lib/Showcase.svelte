<!-- Copyright (c) 2025 Oliver Tran -->
<script>
  import { onMount } from 'svelte';
  import DeviceFrame from './DeviceFrame.svelte';
  import { reveal } from './reveal.js';
  import { screens, screenSrc } from './screens.js';

  export let darkMode = false;

  const slides = [
    { screen: screens.recordings, title: 'Recordings', caption: 'Every take with tags, pieces, and playback speed.' },
    { screen: screens.recordingDetails, title: 'Recording details', caption: 'Notes, measures, and trim without re-encoding.' },
    { screen: screens.practice, title: 'Practice log', caption: 'Sessions, streaks, and ratings at a glance.' },
    { screen: screens.metronome, title: 'Metronome', caption: 'Tap tempo, beat patterns, and favorite tempos.' },
    { screen: screens.tuner, title: 'Tuner', caption: 'Live pitch, cents, and your own A4.' },
    { screen: screens.dictionary, title: 'Dictionary', caption: 'Terms and forms, searchable offline.' },
    { screen: screens.dictionaryDetails, title: 'Term details', caption: 'Clear definitions with related entries.' }
  ];

  let strip;
  let active = 0;
  let items = [];

  function scrollToIndex(index) {
    const clamped = Math.max(0, Math.min(slides.length - 1, index));
    const target = items[clamped];
    if (!target || !strip) return;
    const left = target.offsetLeft - (strip.clientWidth - target.clientWidth) / 2;
    strip.scrollTo({ left, behavior: 'smooth' });
  }

  function step(delta) {
    scrollToIndex(active + delta);
  }

  function updateActive() {
    if (!strip) return;
    const center = strip.scrollLeft + strip.clientWidth / 2;
    let best = 0;
    let bestDistance = Infinity;
    items.forEach((item, index) => {
      if (!item) return;
      const distance = Math.abs(item.offsetLeft + item.clientWidth / 2 - center);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = index;
      }
    });
    active = best;
  }

  onMount(() => {
    let frame = 0;
    const onScroll = () => {
      cancelAnimationFrame(frame);
      frame = requestAnimationFrame(updateActive);
    };
    updateActive();
    strip.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', onScroll);
    return () => {
      cancelAnimationFrame(frame);
      strip.removeEventListener('scroll', onScroll);
      window.removeEventListener('resize', onScroll);
    };
  });
</script>

<section class="section showcase" id="screens">
  <div class="page head" use:reveal>
    <div class="section-head">
      <span class="eyebrow">A closer look</span>
      <h2>Designed to disappear while you play.</h2>
      <p>Big targets, clear type, and nothing between you and the next repetition.</p>
    </div>
  </div>

  <div class="strip-wrap" use:reveal>
    <div class="strip" bind:this={strip} tabindex="-1">
      {#each slides as slide, index}
        <figure class="slide" class:active={active === index} bind:this={items[index]}>
          <DeviceFrame src={screenSrc(slide.screen, darkMode)} alt={`${slide.title} screen in Claveo`} size="sm" />
          <figcaption>
            <strong>{slide.title}</strong>
            <span>{slide.caption}</span>
          </figcaption>
        </figure>
      {/each}
    </div>
  </div>

  <div class="page controls">
    <button class="arrow" on:click={() => step(-1)} aria-label="Previous screen" disabled={active === 0}>
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M15 5l-7 7 7 7"/></svg>
    </button>
    <div class="dots" role="tablist" aria-label="Screens">
      {#each slides as slide, index}
        <button
          class="dot"
          class:active={active === index}
          role="tab"
          aria-selected={active === index}
          aria-label={slide.title}
          on:click={() => scrollToIndex(index)}></button>
      {/each}
    </div>
    <button class="arrow" on:click={() => step(1)} aria-label="Next screen" disabled={active === slides.length - 1}>
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M9 5l7 7-7 7"/></svg>
    </button>
  </div>
</section>

<style>
  .showcase {
    background: var(--bg-elevated);
    overflow: hidden;
  }

  .section-head {
    margin-bottom: 40px;
  }

  .section-head h2 {
    margin-top: 16px;
  }

  .strip-wrap {
    position: relative;
  }

  .strip {
    display: flex;
    gap: 36px;
    padding: 24px calc(50vw - 110px) 32px;
    overflow-x: auto;
    scroll-snap-type: x mandatory;
    scrollbar-width: none;
    -webkit-overflow-scrolling: touch;
  }

  .strip::-webkit-scrollbar {
    display: none;
  }

  .slide {
    margin: 0;
    scroll-snap-align: center;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 18px;
    flex: none;
    transition: transform 0.5s var(--ease-out), opacity 0.5s ease;
    opacity: 0.55;
    transform: scale(0.94);
  }

  .slide.active {
    opacity: 1;
    transform: scale(1);
  }

  figcaption {
    text-align: center;
    display: flex;
    flex-direction: column;
    gap: 4px;
    max-width: 220px;
  }

  figcaption strong {
    font-size: 1rem;
    letter-spacing: -0.01em;
  }

  figcaption span {
    font-size: var(--text-small);
    color: var(--text-secondary);
  }

  .controls {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 20px;
    margin-top: 8px;
  }

  .arrow {
    width: 42px;
    height: 42px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    border-radius: var(--radius-pill);
    border: 1px solid var(--border);
    background: var(--surface);
    color: var(--text);
    cursor: pointer;
    transition: border-color 0.2s ease, transform 0.18s var(--ease-out), opacity 0.2s ease;
  }

  .arrow:hover:not(:disabled) {
    border-color: var(--accent);
    color: var(--accent-strong);
    transform: translateY(-1px);
  }

  .arrow:disabled {
    opacity: 0.35;
    cursor: default;
  }

  .dots {
    display: flex;
    gap: 8px;
  }

  .dot {
    width: 8px;
    height: 8px;
    padding: 0;
    border-radius: var(--radius-pill);
    border: none;
    background: var(--border-strong);
    cursor: pointer;
    transition: width 0.3s var(--ease-out), background-color 0.3s ease;
  }

  .dot.active {
    width: 26px;
    background: var(--accent);
  }

  @media (max-width: 600px) {
    .strip {
      gap: 24px;
    }
  }
</style>
