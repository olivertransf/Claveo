<!-- Copyright (c) 2025 Oliver Tran -->
<script>
  import { CONTACT_EMAIL, GITHUB_URL, LICENSE_URL } from './links.js';

  export let navigate;

  const year = new Date().getFullYear();
</script>

<footer class="footer">
  <div class="page grid">
    <div class="brand">
      <img src="/icon.png" alt="" width="40" height="40" />
      <div>
        <strong>Claveo</strong>
        <p>Your music practice companion for iPhone and iPad.</p>
      </div>
    </div>

    <div class="col">
      <h3>Product</h3>
      <a href="/about" on:click|preventDefault={() => navigate('/about')}>About</a>
      <a href="/roadmap" on:click|preventDefault={() => navigate('/roadmap')}>Roadmap</a>
    </div>

    <div class="col">
      <h3>Legal</h3>
      <a href="/privacy-policy" on:click|preventDefault={() => navigate('/privacy-policy')}>Privacy</a>
      <a href={LICENSE_URL} target="_blank" rel="noopener noreferrer">License</a>
    </div>

    <div class="col">
      <h3>Contact</h3>
      <a href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a>
      <a href={GITHUB_URL} target="_blank" rel="noopener noreferrer">GitHub</a>
    </div>
  </div>
  <div class="page legal">
    <p>&copy; {year} Oliver Tran</p>
  </div>
</footer>

<style>
  .footer {
    margin-top: auto;
    border-top: 1px solid var(--border);
    background: var(--bg-elevated);
    padding: 56px 0 28px;
  }

  .grid {
    display: grid;
    grid-template-columns: 1.6fr repeat(3, 1fr);
    gap: 32px;
  }

  .brand {
    display: flex;
    gap: 14px;
    align-items: flex-start;
  }

  .brand img {
    border-radius: 10px;
    box-shadow: var(--shadow-sm);
  }

  .brand strong {
    display: block;
    font-size: 1.05rem;
    letter-spacing: -0.02em;
    margin-bottom: 4px;
  }

  .brand p {
    font-size: var(--text-small);
    color: var(--text-secondary);
    max-width: 22rem;
  }

  .col {
    display: flex;
    flex-direction: column;
    gap: 10px;
  }

  .col h3 {
    font-size: var(--text-xs);
    font-weight: 600;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    color: var(--text-tertiary);
    margin-bottom: 4px;
  }

  .col a {
    font-size: var(--text-small);
    color: var(--text-secondary);
    text-decoration: none;
    width: fit-content;
    transition: color 0.2s ease;
  }

  .col a:hover {
    color: var(--accent-strong);
  }

  .legal {
    margin-top: 40px;
    padding-top: 20px;
    border-top: 1px solid var(--border);
    font-size: var(--text-xs);
    color: var(--text-tertiary);
  }

  @media (max-width: 760px) {
    .grid {
      grid-template-columns: 1fr 1fr;
    }

    .brand {
      grid-column: 1 / -1;
    }
  }
</style>
