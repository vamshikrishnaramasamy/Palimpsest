<script lang="ts">
  import { page } from '$app/state';
  import { goto } from '$app/navigation';
  import { authState } from '$lib/stores/auth.svelte';

  const avatarLetter = $derived(
    authState.user?.email?.[0]?.toUpperCase() || '?'
  );

  // Determine active tab from current path
  const currentPath = $derived(page.url?.pathname || '/');

  const tabs = [
    { id: 'home', path: '/', label: 'Home', icon: 'home' },
    { id: 'chat', path: '/chat', label: 'Overlap', icon: 'overlap' },
    { id: 'create', path: '/create', label: 'Create', icon: 'create' },
    { id: 'map', path: '/notifications', label: 'Map', icon: 'map' },
    { id: 'profile', path: '/profile', label: 'Profile', icon: 'profile' }
  ];

  function isActive(tab: typeof tabs[0]): boolean {
    if (tab.path === '/') return currentPath === '/';
    return currentPath.startsWith(tab.path);
  }
</script>

<nav class="bg-[var(--color-surface)] border-t border-[var(--color-border)]" style="backdrop-filter: blur(20px); box-shadow: 0 -1px 8px rgba(0,0,0,0.04);">
  <div class="flex items-center justify-around h-[44px]">
    {#each tabs as tab (tab.id)}
      <button
        aria-label={tab.label}
        onclick={() => goto(tab.path)}
        class="flex items-center justify-center w-[76px] h-full transition-opacity {isActive(tab) ? 'opacity-100' : 'opacity-30'}"
      >
        {#if tab.icon === 'home'}
          <!-- Home icon (filled house) -->
          <svg class="w-6 h-6" viewBox="0 0 24 24" fill="currentColor">
            <path d="M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z"/>
          </svg>
        {:else if tab.icon === 'overlap'}
          <svg class="w-6 h-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="9" cy="12" r="5"/>
            <circle cx="15" cy="12" r="5"/>
          </svg>
        {:else if tab.icon === 'create'}
          <!-- Create / plus in square -->
          <svg class="w-6 h-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <rect x="3" y="3" width="18" height="18" rx="4"/>
            <line x1="12" y1="8" x2="12" y2="16"/>
            <line x1="8" y1="12" x2="16" y2="12"/>
          </svg>
        {:else if tab.icon === 'map'}
          <svg class="w-6 h-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M9 18l-6 3V6l6-3 6 3 6-3v15l-6 3-6-3Z"/>
            <path d="M9 3v15M15 6v15"/>
          </svg>
        {:else if tab.icon === 'profile'}
          {#if authState.user}
            <div class="w-6 h-6 rounded-full bg-black flex items-center justify-center text-white text-[10px] font-semibold border border-[var(--color-border)]">
              {avatarLetter}
            </div>
          {:else}
            <!-- Person outline -->
            <svg class="w-6 h-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
              <circle cx="12" cy="7" r="4"/>
            </svg>
          {/if}
        {/if}
      </button>
    {/each}
  </div>
  <!-- Home Indicator -->
  <div class="flex justify-center pb-[8px] pt-1">
    <div class="w-[134px] h-[5px] rounded-full bg-black/20"></div>
  </div>
</nav>
