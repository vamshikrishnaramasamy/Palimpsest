<script lang="ts">
  import { onMount } from 'svelte';
  import { client } from '$lib/api';
  import TabBar from '$lib/components/TabBar.svelte';

  type Story = {
    id: string;
    title: string;
    author: string;
    time: string;
    lat: number | null;
    lng: number | null;
  };

  let stories = $state<Story[]>([]);
  let loading = $state(true);

  onMount(async () => {
    try {
      const posts = await client.posts.list({ limit: 30 });
      stories = posts.map((post: any) => ({
        id: post.id,
        title: post.body || 'Untitled memory',
        author: post.display_name || post.email?.split('@')[0] || 'Anonymous',
        time: new Date(post.created_at).toLocaleDateString(),
        lat: post.lat,
        lng: post.lng
      }));
    } catch {
      stories = [];
    }
    loading = false;
  });
</script>

<div class="h-dvh flex flex-col bg-[var(--color-surface)]">
  <div class="flex-1 overflow-y-auto pb-[112px] animate-fade-in">
    <div class="px-5 pt-6 max-w-md mx-auto">
      <p class="text-xs font-semibold uppercase tracking-[0.12em] text-[var(--color-text-muted)]">Map</p>
      <h1 class="text-[30px] leading-tight font-bold text-[var(--color-text)] mt-1">Layered stories around you</h1>
      <p class="text-sm text-[var(--color-text-muted)] mt-2 leading-snug">
        Palimpsest turns physical places into stacks of memory. Overlap adds the invisible crossings between people.
      </p>
    </div>

    <div class="mt-5 px-5 max-w-md mx-auto">
      <div class="relative h-[430px] rounded-[30px] bg-[var(--color-surface-input)] overflow-hidden border border-[var(--color-border)]">
        <div class="absolute inset-0 bg-white" style="background-image: linear-gradient(#ececec 1px, transparent 1px), linear-gradient(90deg, #ececec 1px, transparent 1px); background-size: 34px 34px;"></div>
        <div class="absolute inset-0 opacity-80" style="background: radial-gradient(circle at 34% 30%, rgba(239, 68, 68, 0.26), transparent 22%), radial-gradient(circle at 68% 58%, rgba(0,0,0,0.14), transparent 24%), radial-gradient(circle at 44% 72%, rgba(239,68,68,0.22), transparent 18%);"></div>

        <svg class="absolute inset-0 w-full h-full text-black/20" viewBox="0 0 360 430" fill="none">
          <path d="M20 94C86 86 112 124 180 116C244 108 262 70 340 82" stroke="currentColor" stroke-width="6" stroke-linecap="round"/>
          <path d="M18 272C70 220 110 246 158 216C210 184 242 174 340 194" stroke="currentColor" stroke-width="5" stroke-linecap="round"/>
          <path d="M74 24C88 94 64 142 86 202C112 274 150 322 132 410" stroke="currentColor" stroke-width="5" stroke-linecap="round"/>
          <path d="M260 20C234 96 250 158 226 228C202 296 232 342 218 410" stroke="currentColor" stroke-width="5" stroke-linecap="round"/>
        </svg>

        <div class="absolute left-[28%] top-[26%]">
          <div class="w-12 h-12 rounded-full bg-black text-white flex items-center justify-center shadow-lg">
            <svg class="w-6 h-6" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
          </div>
        </div>
        <div class="absolute right-[22%] top-[48%]">
          <div class="w-10 h-10 rounded-full bg-white border-2 border-black flex items-center justify-center shadow-lg">
            <span class="text-xs font-bold">3</span>
          </div>
        </div>
        <div class="absolute left-[42%] bottom-[22%]">
          <div class="w-11 h-11 rounded-full bg-red-500 text-white flex items-center justify-center shadow-lg">
            <svg class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7Z"/></svg>
          </div>
        </div>

        <div class="absolute left-4 right-4 bottom-4 rounded-3xl bg-white/90 backdrop-blur border border-[var(--color-border)] p-4">
          <div class="flex items-center justify-between">
            <p class="text-sm font-semibold text-[var(--color-text)]">Current layer</p>
            <p class="text-xs text-[var(--color-text-muted)]">{loading ? 'Loading' : `${stories.length} stories`}</p>
          </div>
          <div class="mt-3 grid grid-cols-3 gap-2">
            <button class="py-2 rounded-full bg-black text-white text-xs font-medium">Stories</button>
            <button class="py-2 rounded-full bg-[var(--color-surface-input)] text-xs font-medium">Secrets</button>
            <button class="py-2 rounded-full bg-[var(--color-surface-input)] text-xs font-medium">Overlap</button>
          </div>
        </div>
      </div>
    </div>

    <div class="mt-6 px-5 max-w-md mx-auto">
      <div class="flex items-center justify-between">
        <h2 class="text-base font-semibold text-[var(--color-text)]">Nearby layers</h2>
        <a href="/create" class="text-sm font-medium text-[var(--color-text)]">Add</a>
      </div>
      <div class="mt-3 space-y-3">
        {#if loading}
          <p class="text-sm text-[var(--color-text-muted)]">Loading nearby layers...</p>
        {:else if stories.length === 0}
          <p class="text-sm text-[var(--color-text-muted)]">No nearby layers yet. Add one from Create.</p>
        {:else}
          {#each stories as story (story.id)}
          <div class="flex items-center gap-3 p-3 rounded-2xl bg-[var(--color-surface-input)]">
            <div class="w-12 h-12 rounded-full bg-white border border-[var(--color-border)] flex items-center justify-center shrink-0">
              <svg class="w-5 h-5 text-[var(--color-text)]" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
            </div>
            <div class="min-w-0 flex-1">
              <p class="text-sm font-medium text-[var(--color-text)] truncate">{story.title}</p>
              <p class="text-xs text-[var(--color-text-muted)] mt-0.5">{story.author} · {story.time}</p>
            </div>
          </div>
          {/each}
        {/if}
      </div>
    </div>
  </div>

  <div class="fixed bottom-0 left-0 right-0 z-50">
    <TabBar />
  </div>
</div>
