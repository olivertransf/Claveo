<!-- Copyright (c) 2025 Oliver Tran -->
<script>
  import Hero from '../lib/Hero.svelte';
  import FeatureGrid from '../lib/FeatureGrid.svelte';
  import Showcase from '../lib/Showcase.svelte';
  import CtaBand from '../lib/CtaBand.svelte';

  export let navigate;
  export let darkMode = false;
</script>

<Hero {darkMode} />
<FeatureGrid />
<Showcase {darkMode} />
<CtaBand {navigate} />
