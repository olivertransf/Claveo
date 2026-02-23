<!-- Copyright (c) 2025 Oliver Tran -->
<script>
  import { onMount } from "svelte";
  export let navigate;

  let items = [
    {
      title: "Optical Music Recognition (OMR)",
      status: "BETA",
      description:
        "Scan and digitize sheet music directly from photos. Convert printed scores into editable digital formats for practice and analysis.",
    },
    {
      title: "Enhanced Practice Analytics",
      description:
        "Deeper insights into your practice patterns with advanced statistics, progress tracking, and personalized recommendations.",
    },
    {
      title: "Collaboration Features",
      description:
        "Share recordings and practice notes with teachers, collaborators, and fellow musicians.",
    },
    {
      title: "More Coming Soon",
      description:
        "We're constantly working on new features to enhance your music practice experience. Stay tuned for updates!",
    },
  ];

  onMount(() => {
    // Intersection Observer for scroll animations
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
      // Add staggered delay
      item.style.transitionDelay = `${index * 0.15}s`;
      observer.observe(item);
    });

    return () => {
      roadmapItems.forEach((item) => observer.unobserve(item));
    };
  });
</script>

<div class="container">
  <div class="section hero-section">
    <h1>Roadmap</h1>
    <p class="hero-subtitle">What's coming next to Claveo</p>
  </div>

  <div class="section">
    <div class="roadmap-content">
      <div class="roadmap-timeline">
        {#each items as item, index}
          <div class="roadmap-item">
            <div class="roadmap-dot"></div>
            <div class="roadmap-content-wrapper">
              <div class="roadmap-header">
                <h3>{item.title}</h3>
                {#if item.status}
                  <span class="roadmap-status">{item.status}</span>
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
    <h2>Have Suggestions?</h2>
    <p>We'd love to hear your ideas for new features and improvements.</p>
    <p class="margin-top">
      <a href="mailto:claveo.app@gmail.com" class="link-primary"
        >claveo.app@gmail.com →</a
      >
    </p>
  </div>
</div>
