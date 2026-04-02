<!-- Copyright (c) 2025 Oliver Tran -->
<script>
  import { onMount } from "svelte";

  const timeline = [
    {
      title: "Exercises & theory tools",
      status: "SHIPPED",
      shipped: true,
      description:
        "Note identification on staff notation, key signature drills, interval ear training, chord and scale reference, and a customizable tab bar with a dedicated More menu.",
    },
    {
      title: "Recording & practice polish",
      status: "SHIPPED",
      shipped: true,
      description:
        "Piece library for recordings, non-destructive trim, variable playback speed, and practice entries that can link to takes—with iCloud-friendly sync when you sign in.",
    },
    {
      title: "Optical Music Recognition (OMR)",
      status: "BETA",
      shipped: false,
      description:
        "Scan and explore sheet music from photos or PDFs. Experimental tooling inside the app for digitizing and analyzing scores.",
    },
    {
      title: "Enhanced Practice Analytics",
      shipped: false,
      description:
        "Deeper insights into practice patterns with richer statistics and trends over time.",
    },
    {
      title: "Collaboration Features",
      shipped: false,
      description:
        "Easier ways to share recordings and practice notes with teachers and collaborators.",
    },
    {
      title: "More coming soon",
      shipped: false,
      description:
        "I'm always improving Claveo. Send ideas to the email below.",
    },
  ];

  onMount(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("visible");
          }
        });
      },
      {
        threshold: 0.2,
        rootMargin: "0px 0px -50px 0px",
      },
    );

    const roadmapItems = document.querySelectorAll(".roadmap-item");
    roadmapItems.forEach((item, index) => {
      item.style.transitionDelay = `${index * 0.08}s`;
      observer.observe(item);
    });

    return () => {
      roadmapItems.forEach((item) => observer.unobserve(item));
    };
  });
</script>

<div class="container roadmap-page">
  <div class="section hero-section">
    <h1>Roadmap</h1>
    <p class="hero-subtitle">Shipped features and what I'm planning next—one timeline.</p>
  </div>

  <div class="section roadmap-section-main">
    <div class="roadmap-content">
      <div class="roadmap-timeline">
        {#each timeline as item (item.title)}
          <div class="roadmap-item" class:roadmap-item-shipped={item.shipped}>
            <div class="roadmap-dot"></div>
            <div class="roadmap-content-wrapper">
              <div class="roadmap-header">
                <h3>{item.title}</h3>
                {#if item.status}
                  <span
                    class="roadmap-status"
                    class:roadmap-status-shipped={item.status === "SHIPPED"}
                    class:roadmap-status-beta={item.status === "BETA"}>{item.status}</span>
                {/if}
              </div>
              <p>{item.description}</p>
            </div>
          </div>
        {/each}
      </div>
    </div>
  </div>

  <div class="divider"></div>

  <div class="section privacy-data-section">
    <h2>Have suggestions?</h2>
    <p>I'd love to hear your ideas for new features and improvements.</p>
    <p class="margin-top">
      <a href="mailto:claveo.app@gmail.com" class="link-primary">claveo.app@gmail.com →</a>
    </p>
  </div>
</div>
