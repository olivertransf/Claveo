// Copyright (c) 2025 Oliver Tran

/**
 * Svelte action: adds `.reveal`, then `.is-visible` once the element scrolls into view.
 * Respects prefers-reduced-motion by revealing immediately.
 */
export function reveal(node, { delay = 0 } = {}) {
  node.classList.add('reveal');

  if (typeof window === 'undefined') return {};

  const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (reduced || !('IntersectionObserver' in window)) {
    node.classList.add('is-visible');
    return {};
  }

  if (delay) node.style.transitionDelay = `${delay}ms`;

  const observer = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (entry.isIntersecting) {
          node.classList.add('is-visible');
          observer.unobserve(node);
        }
      }
    },
    { threshold: 0.15, rootMargin: '0px 0px -40px 0px' }
  );
  observer.observe(node);

  return {
    destroy() {
      observer.disconnect();
    }
  };
}
