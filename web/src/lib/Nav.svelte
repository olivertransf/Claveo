<!-- Copyright (c) 2025 Oliver Tran -->
<script>
  import { onMount } from 'svelte';
  import { APP_STORE_URL } from './links.js';

  export let currentPage = 'home';
  export let darkMode = false;
  export let navigate;
  export let toggleDarkMode;

  const links = [
    { path: '/', page: 'home', label: 'Home' },
    { path: '/about', page: 'about', label: 'About' },
    { path: '/roadmap', page: 'roadmap', label: 'Roadmap' }
  ];

  let menuOpen = false;
  let scrolled = false;
  let previousOverflow = null;

  function lockScroll() {
    if (previousOverflow === null) previousOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
  }

  function unlockScroll() {
    document.body.style.overflow = previousOverflow ?? '';
    previousOverflow = null;
  }

  export function closeMenu() {
    if (!menuOpen) return;
    menuOpen = false;
    unlockScroll();
  }

  function toggleMenu() {
    menuOpen = !menuOpen;
    menuOpen ? lockScroll() : unlockScroll();
  }

  function go(path) {
    closeMenu();
    navigate(path);
  }

  onMount(() => {
    const onScroll = () => {
      scrolled = window.scrollY > 8;
    };
    const onKey = (event) => {
      if (event.key === 'Escape') closeMenu();
    };
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('keydown', onKey);
    return () => {
      window.removeEventListener('scroll', onScroll);
      window.removeEventListener('keydown', onKey);
      unlockScroll();
    };
  });
</script>

<header class="nav" class:scrolled class:menu-open={menuOpen}>
  <div class="nav-inner page">
    <a href="/" class="brand" on:click|preventDefault={() => go('/')} aria-label="Claveo home">
      <img src="/icon.png" alt="" width="34" height="34" />
      <span>Claveo</span>
    </a>

    <nav class="links" aria-label="Primary">
      {#each links as link}
        <a
          href={link.path}
          class="pill"
          class:active={currentPage === link.page}
          aria-current={currentPage === link.page ? 'page' : undefined}
          on:click|preventDefault={() => go(link.path)}>{link.label}</a>
      {/each}
    </nav>

    <div class="actions">
      <button class="icon-btn" on:click={toggleDarkMode} aria-label={darkMode ? 'Switch to light mode' : 'Switch to dark mode'}>
        {#if darkMode}
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <circle cx="12" cy="12" r="4"></circle>
            <path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41"></path>
          </svg>
        {:else}
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path>
          </svg>
        {/if}
      </button>
      <a href={APP_STORE_URL} class="btn btn-primary download" target="_blank" rel="noopener noreferrer">Download</a>
      <button
        class="icon-btn menu-btn"
        class:open={menuOpen}
        on:click={toggleMenu}
        aria-label={menuOpen ? 'Close menu' : 'Open menu'}
        aria-expanded={menuOpen}
        aria-controls="mobile-menu">
        <span></span>
        <span></span>
      </button>
    </div>
  </div>

  <div id="mobile-menu" class="sheet" class:open={menuOpen} aria-hidden={!menuOpen}>
    <nav aria-label="Mobile">
      {#each links as link}
        <a
          href={link.path}
          class:active={currentPage === link.page}
          tabindex={menuOpen ? 0 : -1}
          on:click|preventDefault={() => go(link.path)}>{link.label}</a>
      {/each}
    </nav>
    <div class="sheet-actions">
      <button class="btn btn-secondary" tabindex={menuOpen ? 0 : -1} on:click={toggleDarkMode}>
        {darkMode ? 'Light mode' : 'Dark mode'}
      </button>
      <a href={APP_STORE_URL} class="btn btn-primary" tabindex={menuOpen ? 0 : -1} target="_blank" rel="noopener noreferrer">Download</a>
    </div>
  </div>
</header>

<style>
  .nav {
    position: sticky;
    top: 0;
    z-index: 50;
    background: color-mix(in srgb, var(--bg) 72%, transparent);
    backdrop-filter: saturate(180%) blur(18px);
    -webkit-backdrop-filter: saturate(180%) blur(18px);
    border-bottom: 1px solid transparent;
    transition: border-color 0.3s ease, background-color 0.3s ease;
  }

  .nav.scrolled,
  .nav.menu-open {
    border-bottom-color: var(--border);
  }

  .nav-inner {
    height: var(--nav-height);
    display: grid;
    grid-template-columns: 1fr auto 1fr;
    align-items: center;
    gap: 16px;
  }

  .brand {
    display: inline-flex;
    align-items: center;
    gap: 10px;
    text-decoration: none;
    font-weight: 700;
    font-size: 1.1rem;
    letter-spacing: -0.02em;
    color: var(--text);
    justify-self: start;
  }

  .brand img {
    width: 34px;
    height: 34px;
    border-radius: 9px;
    box-shadow: var(--shadow-sm);
  }

  .links {
    display: inline-flex;
    gap: 4px;
    padding: 4px;
    border-radius: var(--radius-pill);
    background: var(--bg-elevated);
    border: 1px solid var(--border);
  }

  .pill {
    padding: 7px 16px;
    border-radius: var(--radius-pill);
    font-size: var(--text-small);
    font-weight: 600;
    color: var(--text-secondary);
    text-decoration: none;
    transition: color 0.2s ease, background-color 0.2s ease;
  }

  .pill:hover {
    color: var(--text);
  }

  .pill.active {
    background: var(--surface);
    color: var(--text);
    box-shadow: var(--shadow-sm);
  }

  .actions {
    display: inline-flex;
    align-items: center;
    gap: 10px;
    justify-self: end;
  }

  .icon-btn {
    width: 40px;
    height: 40px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    border-radius: var(--radius-pill);
    border: 1px solid var(--border);
    background: var(--surface);
    color: var(--text);
    cursor: pointer;
    transition: border-color 0.2s ease, background-color 0.2s ease, transform 0.18s var(--ease-out);
  }

  .icon-btn:hover {
    border-color: var(--border-strong);
    transform: translateY(-1px);
  }

  .download {
    padding: 10px 18px;
  }

  .menu-btn {
    display: none;
    flex-direction: column;
    gap: 6px;
  }

  .menu-btn span {
    display: block;
    width: 18px;
    height: 2px;
    border-radius: 2px;
    background: currentColor;
    transition: transform 0.3s var(--ease-out);
  }

  .menu-btn.open span:first-child {
    transform: translateY(4px) rotate(45deg);
  }

  .menu-btn.open span:last-child {
    transform: translateY(-4px) rotate(-45deg);
  }

  .sheet {
    display: none;
  }

  @media (max-width: 760px) {
    .nav-inner {
      grid-template-columns: 1fr auto;
    }

    .links,
    .download {
      display: none;
    }

    .menu-btn {
      display: inline-flex;
    }

    .sheet {
      display: flex;
      flex-direction: column;
      gap: 24px;
      position: fixed;
      inset: var(--nav-height) 0 auto 0;
      padding: 24px var(--gutter) 32px;
      background: var(--bg);
      border-bottom: 1px solid var(--border);
      box-shadow: var(--shadow-lg);
      opacity: 0;
      visibility: hidden;
      transform: translateY(-12px);
      transition: opacity 0.25s ease, transform 0.3s var(--ease-out), visibility 0.3s;
    }

    .sheet.open {
      opacity: 1;
      visibility: visible;
      transform: none;
    }

    .sheet nav {
      display: flex;
      flex-direction: column;
    }

    .sheet nav a {
      padding: 14px 4px;
      font-size: 1.25rem;
      font-weight: 600;
      text-decoration: none;
      color: var(--text-secondary);
      border-bottom: 1px solid var(--border);
    }

    .sheet nav a.active {
      color: var(--accent-strong);
    }

    .sheet-actions {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 12px;
    }
  }
</style>
