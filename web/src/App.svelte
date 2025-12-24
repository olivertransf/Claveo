<!-- Copyright (c) 2025 Oliver Tran -->
<script>
  import { onMount } from 'svelte';
  import Home from './pages/Home.svelte';
  import PrivacyPolicy from './pages/PrivacyPolicy.svelte';
  import Roadmap from './pages/Roadmap.svelte';
  import About from './pages/About.svelte';
  import './styles.css';

  let currentPage = 'home';
  let darkMode = false;
  let mobileMenuOpen = false;

  function toggleMobileMenu() {
    mobileMenuOpen = !mobileMenuOpen;
    // Prevent body scroll when menu is open
    document.body.style.overflow = mobileMenuOpen ? 'hidden' : '';
  }

  function closeMobileMenu() {
    mobileMenuOpen = false;
    document.body.style.overflow = '';
  }

  // Load theme preference from localStorage
  onMount(() => {
    // Check URL to determine which page to show
    const path = window.location.pathname;
    if (path === '/privacy-policy.html' || path === '/privacy-policy') {
      currentPage = 'privacy';
    } else if (path === '/roadmap' || path === '/roadmap.html') {
      currentPage = 'roadmap';
    } else if (path === '/about' || path === '/about.html') {
      currentPage = 'about';
    } else {
      currentPage = 'home';
    }

    // Load dark mode preference
    const savedTheme = localStorage.getItem('claveo-theme');
    if (savedTheme === 'dark' || (!savedTheme && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
      darkMode = true;
      document.documentElement.classList.add('dark');
    }

    // Ensure styles apply immediately
    updateTheme();

    // Handle browser back/forward buttons
    window.addEventListener('popstate', () => {
      const path = window.location.pathname;
      if (path === '/privacy-policy.html' || path === '/privacy-policy') {
        currentPage = 'privacy';
      } else if (path === '/roadmap' || path === '/roadmap.html') {
        currentPage = 'roadmap';
      } else if (path === '/about' || path === '/about.html') {
        currentPage = 'about';
      } else {
        currentPage = 'home';
      }
    });
  });

  function toggleDarkMode() {
    darkMode = !darkMode;
    updateTheme();
    localStorage.setItem('claveo-theme', darkMode ? 'dark' : 'light');
  }

  function updateTheme() {
    if (darkMode) {
      document.documentElement.classList.add('dark');
      document.documentElement.style.backgroundColor = '#000000';
      document.body.style.backgroundColor = '#000000';
    } else {
      document.documentElement.classList.remove('dark');
      document.documentElement.style.backgroundColor = '#ffffff';
      document.body.style.backgroundColor = '#ffffff';
    }
    document.body.style.fontFamily = '"Inter", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';
  }

  function navigate(path) {
    closeMobileMenu();
    if (path === '/privacy-policy.html' || path === '/privacy-policy') {
      currentPage = 'privacy';
      window.history.pushState({}, '', path);
    } else if (path === '/roadmap' || path === '/roadmap.html') {
      currentPage = 'roadmap';
      window.history.pushState({}, '', path);
    } else if (path === '/about' || path === '/about.html') {
      currentPage = 'about';
      window.history.pushState({}, '', path);
    } else {
      currentPage = 'home';
      window.history.pushState({}, '', '/');
    }
  }
</script>

<nav class="navbar">
  <div class="navbar-brand">
    <img src="/icon.png" alt="Claveo" class="navbar-icon" />
    <span class="navbar-title">Claveo</span>
  </div>
  <div class="navbar-links">
    <a href="/" on:click|preventDefault={() => navigate('/')} class="navbar-link" class:active={currentPage === 'home'}>Home</a>
    <a href="/about" on:click|preventDefault={() => navigate('/about')} class="navbar-link" class:active={currentPage === 'about'}>About</a>
    <a href="/roadmap" on:click|preventDefault={() => navigate('/roadmap')} class="navbar-link" class:active={currentPage === 'roadmap'}>Roadmap</a>
  </div>
  <button class="mobile-menu-toggle" class:active={mobileMenuOpen} on:click={toggleMobileMenu} aria-label="Toggle menu">
    <span class="hamburger-line"></span>
    <span class="hamburger-line"></span>
    <span class="hamburger-line"></span>
  </button>
  <div class="mobile-menu" class:open={mobileMenuOpen}>
    <a href="/" on:click|preventDefault={() => navigate('/')} class="mobile-menu-link" class:active={currentPage === 'home'}>Home</a>
    <a href="/about" on:click|preventDefault={() => navigate('/about')} class="mobile-menu-link" class:active={currentPage === 'about'}>About</a>
    <a href="/roadmap" on:click|preventDefault={() => navigate('/roadmap')} class="mobile-menu-link" class:active={currentPage === 'roadmap'}>Roadmap</a>
    <div class="mobile-menu-theme">
      <button class="mobile-theme-toggle" on:click={toggleDarkMode} aria-label="Toggle dark mode">
        {#if darkMode}
          <svg class="theme-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="12" cy="12" r="5"></circle>
            <line x1="12" y1="1" x2="12" y2="3"></line>
            <line x1="12" y1="21" x2="12" y2="23"></line>
            <line x1="4.22" y1="4.22" x2="5.64" y2="5.64"></line>
            <line x1="18.36" y1="18.36" x2="19.78" y2="19.78"></line>
            <line x1="1" y1="12" x2="3" y2="12"></line>
            <line x1="21" y1="12" x2="23" y2="12"></line>
            <line x1="4.22" y1="19.78" x2="5.64" y2="18.36"></line>
            <line x1="18.36" y1="5.64" x2="19.78" y2="4.22"></line>
          </svg>
          <span>Light Mode</span>
        {:else}
          <svg class="theme-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path>
          </svg>
          <span>Dark Mode</span>
        {/if}
      </button>
    </div>
  </div>
  <div class="navbar-actions">
    <button class="theme-toggle" on:click={toggleDarkMode} aria-label="Toggle dark mode">
      {#if darkMode}
        <svg class="theme-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <circle cx="12" cy="12" r="5"></circle>
          <line x1="12" y1="1" x2="12" y2="3"></line>
          <line x1="12" y1="21" x2="12" y2="23"></line>
          <line x1="4.22" y1="4.22" x2="5.64" y2="5.64"></line>
          <line x1="18.36" y1="18.36" x2="19.78" y2="19.78"></line>
          <line x1="1" y1="12" x2="3" y2="12"></line>
          <line x1="21" y1="12" x2="23" y2="12"></line>
          <line x1="4.22" y1="19.78" x2="5.64" y2="18.36"></line>
          <line x1="18.36" y1="5.64" x2="19.78" y2="4.22"></line>
        </svg>
      {:else}
        <svg class="theme-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path>
        </svg>
      {/if}
    </button>
    <a href="https://apps.apple.com/us/app/claveo-music-companion/id6755795790" class="navbar-download">Download</a>
  </div>
</nav>

{#if currentPage === 'privacy'}
  <PrivacyPolicy navigate={navigate} />
{:else if currentPage === 'roadmap'}
  <Roadmap navigate={navigate} />
{:else if currentPage === 'about'}
  <About navigate={navigate} />
{:else}
  <Home navigate={navigate} darkMode={darkMode} />
{/if}
