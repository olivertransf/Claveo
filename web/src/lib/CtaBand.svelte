<!-- Copyright (c) 2025 Oliver Tran -->
<script>
  import { APP_STORE_URL, CONTACT_EMAIL, appStoreBadge } from './links.js';
  import { reveal } from './reveal.js';

  export let navigate;
</script>

<section class="section cta-section" id="download">
  <div class="page">
    <div class="band" use:reveal>
      <div class="band-glow" aria-hidden="true"></div>
      <div class="content">
        <span class="pill">Free, no ads, no account</span>
        <h2>Get Claveo</h2>
        <p>
          Your recordings and practice log stay on your devices and in your own iCloud. Nothing is sent to me.
          <a href="/privacy-policy" on:click|preventDefault={() => navigate('/privacy-policy')}>Read the privacy policy</a>.
        </p>
        <div class="actions">
          <a href={APP_STORE_URL} target="_blank" rel="noopener noreferrer" class="badge">
            <img src={appStoreBadge(true)} alt="Download on the App Store" width="166" height="55" />
          </a>
          <a href={`mailto:${CONTACT_EMAIL}`} class="contact">Questions? {CONTACT_EMAIL}</a>
        </div>
      </div>
    </div>
  </div>
</section>

<style>
  .band {
    position: relative;
    overflow: hidden;
    padding: clamp(44px, 7vw, 80px) clamp(24px, 6vw, 72px);
    border-radius: var(--radius-xl);
    background: linear-gradient(135deg, var(--accent-deep) 0%, var(--accent) 60%, #6fb0ff 100%);
    color: #fff;
    box-shadow: var(--shadow-lg);
  }

  .band-glow {
    position: absolute;
    inset: auto -20% -60% auto;
    width: 60%;
    aspect-ratio: 1;
    border-radius: 50%;
    background: radial-gradient(circle, rgba(255, 255, 255, 0.28) 0%, transparent 70%);
    pointer-events: none;
  }

  .content {
    position: relative;
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: 16px;
    max-width: 38rem;
  }

  .pill {
    padding: 6px 14px;
    border-radius: var(--radius-pill);
    background: rgba(255, 255, 255, 0.18);
    font-size: var(--text-xs);
    font-weight: 600;
    letter-spacing: 0.02em;
    text-transform: uppercase;
  }

  h2 {
    color: #fff;
    font-size: var(--text-h1);
    font-weight: 800;
  }

  p {
    font-size: var(--text-lead);
    line-height: 1.6;
    color: rgba(255, 255, 255, 0.86);
  }

  p a {
    color: #fff;
    font-weight: 600;
    text-decoration: underline;
    text-underline-offset: 3px;
  }

  .actions {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 22px;
    margin-top: 10px;
  }

  .badge {
    display: inline-block;
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

  .contact {
    color: #fff;
    font-weight: 500;
    font-size: var(--text-small);
    text-decoration: none;
    border-bottom: 1px solid rgba(255, 255, 255, 0.4);
    transition: border-color 0.2s ease;
  }

  .contact:hover {
    border-bottom-color: #fff;
  }

  .cta-section :global(:focus-visible) {
    outline-color: #fff;
  }
</style>
