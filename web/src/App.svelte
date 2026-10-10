<!-- Copyright (c) 2025 Oliver Tran -->
<script>
  import { onMount } from 'svelte';
  import Nav from './lib/Nav.svelte';
  import Footer from './lib/Footer.svelte';
  import Home from './pages/Home.svelte';
  import PrivacyPolicy from './pages/PrivacyPolicy.svelte';
  import Roadmap from './pages/Roadmap.svelte';
  import About from './pages/About.svelte';
  import './styles.css';

  const routes = {
    '/': 'home',
    '/about': 'about',
    '/about.html': 'about',
    '/roadmap': 'roadmap',
    '/roadmap.html': 'roadmap',
    '/privacy-policy': 'privacy',
    '/privacy-policy.html': 'privacy'
  };

  const titles = {
    home: 'Claveo — Music Practice Companion',
    about: 'About — Claveo',
    roadmap: 'Roadmap — Claveo',
    privacy: 'Privacy Policy — Claveo'
  };

  let currentPage = 'home';
  let darkMode = false;

  function pageFor(path) {
    return routes[path] ?? 'home';
  }

  function applyTheme() {
    document.documentElement.classList.toggle('dark', darkMode);
  }

  function toggleDarkMode() {
    darkMode = !darkMode;
    applyTheme();
    localStorage.setItem('claveo-theme', darkMode ? 'dark' : 'light');
  }

  function setPage(page) {
    currentPage = page;
    document.title = titles[page];
  }

  function navigate(path) {
    const page = pageFor(path);
    const target = page === 'home' ? '/' : path.replace(/\.html$/, '');
    if (window.location.pathname !== target) {
      window.history.pushState({}, '', target);
    }
    setPage(page);
    window.scrollTo({ top: 0, behavior: 'instant' });
  }

  onMount(() => {
    darkMode = document.documentElement.classList.contains('dark');
    setPage(pageFor(window.location.pathname));

    const onPopState = () => setPage(pageFor(window.location.pathname));
    window.addEventListener('popstate', onPopState);
    return () => window.removeEventListener('popstate', onPopState);
  });
</script>

<Nav {currentPage} {darkMode} {navigate} {toggleDarkMode} />

<main>
  {#if currentPage === 'privacy'}
    <PrivacyPolicy {navigate} />
  {:else if currentPage === 'roadmap'}
    <Roadmap />
  {:else if currentPage === 'about'}
    <About {navigate} {darkMode} />
  {:else}
    <Home {navigate} {darkMode} />
  {/if}
</main>

<Footer {navigate} />
