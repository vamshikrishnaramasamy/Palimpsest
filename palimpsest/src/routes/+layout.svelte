<script lang="ts">
  import '../app.css';
  import favicon from '$lib/assets/favicon.svg';
  import { authState, initAuth } from '$lib/stores/auth.svelte';

  let { children } = $props();
  let ready = $state(false);

  $effect(() => {
    initAuth();
    ready = true;
  });
</script>

<svelte:head>
  <link rel="icon" href={favicon} />
  <title>OverLap — discover connections</title>
  <meta name="description" content="Discover the invisible connections between you and the people around you." />
</svelte:head>

<main class="min-h-dvh bg-[var(--color-surface)]">
  {#if ready}
    {@render children?.()}
  {/if}
</main>
