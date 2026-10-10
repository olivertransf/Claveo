<!-- Copyright (c) 2025 Oliver Tran -->
<script>
  export let src;
  export let alt = '';
  export let size = 'md';
  export let loading = 'lazy';
</script>

<figure class={`device device-${size}`}>
  <div class="screen">
    <img {src} {alt} {loading} decoding="async" />
  </div>
</figure>

<style>
  .device {
    --frame: 10px;
    --radius: 44px;
    margin: 0;
    width: var(--device-width, 300px);
    aspect-ratio: 9 / 19.5;
    padding: var(--frame);
    border-radius: var(--radius);
    background: #1a1c24;
    box-shadow:
      inset 0 0 0 1.5px rgba(255, 255, 255, 0.12),
      inset 0 0 0 4px #000,
      var(--device-shadow);
    position: relative;
    flex: none;
  }

  .device-sm {
    --device-width: 220px;
    --frame: 8px;
    --radius: 34px;
  }

  .device-md {
    --device-width: 280px;
  }

  .device-lg {
    --device-width: 340px;
    --frame: 11px;
    --radius: 50px;
  }

  .screen {
    width: 100%;
    height: 100%;
    overflow: hidden;
    border-radius: calc(var(--radius) - var(--frame));
    background: #000;
  }

  .screen img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    object-position: center top;
  }

  .device::before {
    content: '';
    position: absolute;
    top: calc(var(--frame) + 8px);
    left: 50%;
    transform: translateX(-50%);
    width: 26%;
    height: 22px;
    border-radius: 999px;
    background: #000;
    z-index: 1;
  }

  .device-sm::before {
    height: 17px;
    top: calc(var(--frame) + 6px);
  }

  .device-lg::before {
    height: 26px;
  }
</style>
