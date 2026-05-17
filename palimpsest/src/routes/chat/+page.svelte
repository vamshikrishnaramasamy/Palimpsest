<script lang="ts">
  import { onMount } from 'svelte';
  import { client } from '$lib/api';
  import TabBar from '$lib/components/TabBar.svelte';

  type OverlapPerson = {
    id: string;
    name: string;
    status: string;
    crossings: number;
    last: string;
  };

  type OverlapPlace = {
    name: string;
    count: number;
    strength: number;
  };

  let friends = $state<OverlapPerson[]>([]);
  let places = $state<OverlapPlace[]>([]);
  let loading = $state(true);

  onMount(async () => {
    try {
      const summary = await client.overlap.summary();
      friends = summary.people;
      places = summary.places;
    } catch {
      friends = [];
      places = [];
    }
    loading = false;
  });
</script>

<div class="h-dvh flex flex-col bg-[var(--color-surface)]">
  <div class="flex-1 overflow-y-auto px-5 pt-6 pb-[112px] max-w-md mx-auto w-full animate-fade-in">
    <div class="flex items-start justify-between gap-4">
      <div>
        <p class="text-xs font-semibold uppercase tracking-[0.12em] text-[var(--color-text-muted)]">Overlap</p>
        <h1 class="text-[30px] leading-tight font-bold text-[var(--color-text)] mt-1">Who was already near you?</h1>
        <p class="text-sm text-[var(--color-text-muted)] mt-2 leading-snug">
          Compare historical paths only after both people agree. The map reveals places where your lives nearly touched.
        </p>
      </div>
      <div class="relative w-16 h-14 shrink-0 mt-1">
        <div class="absolute left-0 top-1 w-12 h-12 rounded-full bg-black/15"></div>
        <div class="absolute right-0 top-1 w-12 h-12 rounded-full bg-black/8"></div>
      </div>
    </div>

    <div class="mt-6 rounded-[28px] bg-[var(--color-surface-input)] p-4 overflow-hidden">
      <div class="relative h-56 rounded-2xl bg-white border border-[var(--color-border)] overflow-hidden">
        <div class="absolute inset-0 opacity-70" style="background-image: linear-gradient(#eee 1px, transparent 1px), linear-gradient(90deg, #eee 1px, transparent 1px); background-size: 32px 32px;"></div>
        <div class="absolute left-[16%] top-[28%] w-36 h-36 rounded-full bg-red-400/30 blur-sm"></div>
        <div class="absolute right-[12%] bottom-[18%] w-28 h-28 rounded-full bg-black/15 blur-sm"></div>
        <div class="absolute left-[42%] top-[38%] w-24 h-24 rounded-full bg-red-500/40 blur-sm"></div>
        <div class="absolute left-[28%] top-[52%] w-3 h-3 rounded-full bg-black"></div>
        <div class="absolute right-[32%] top-[34%] w-3 h-3 rounded-full bg-black"></div>
        <div class="absolute left-4 right-4 bottom-4 rounded-2xl bg-white/90 backdrop-blur px-4 py-3 border border-[var(--color-border)]">
          <div class="flex items-center justify-between">
            <p class="text-sm font-semibold text-[var(--color-text)]">{friends[0]?.name ?? (loading ? 'Loading...' : 'No overlap yet')}</p>
            <p class="text-xs text-[var(--color-text-muted)]">{friends[0]?.crossings ?? 0} crossings</p>
          </div>
          <p class="text-xs text-[var(--color-text-muted)] mt-1">
            {places[0] ? `Strongest overlap near ${places[0].name}.` : 'Add location stories to calculate shared places.'}
          </p>
        </div>
      </div>
    </div>

    <div class="mt-6">
      <div class="flex items-center justify-between">
        <h2 class="text-base font-semibold text-[var(--color-text)]">Mutual comparisons</h2>
        <button class="text-sm font-medium text-[var(--color-text)]">Invite</button>
      </div>

      <div class="mt-3 divide-y divide-[var(--color-border-light)]">
        {#if loading}
          <p class="py-6 text-sm text-[var(--color-text-muted)]">Loading comparisons...</p>
        {:else if friends.length === 0}
          <p class="py-6 text-sm text-[var(--color-text-muted)]">No comparison data yet. Seed users and posts to generate overlaps.</p>
        {:else}
          {#each friends as friend (friend.id)}
          <div class="py-4 flex items-center gap-3">
            <div class="w-11 h-11 rounded-full bg-[var(--color-surface-input)] border border-[var(--color-border)] flex items-center justify-center text-sm font-bold">
              {friend.name.slice(0, 1)}
            </div>
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2">
                <p class="text-[15px] font-semibold text-[var(--color-text)] truncate">{friend.name}</p>
                <span class="text-[11px] px-2 py-0.5 rounded-full {friend.status === 'consented' ? 'bg-black text-white' : 'bg-[var(--color-surface-input)] text-[var(--color-text-muted)]'}">
                  {friend.status}
                </span>
              </div>
              <p class="text-sm text-[var(--color-text-muted)] truncate mt-0.5">{friend.last}</p>
            </div>
            <p class="text-sm font-semibold text-[var(--color-text)]">{friend.crossings}</p>
          </div>
          {/each}
        {/if}
      </div>
    </div>

    <div class="mt-6 rounded-2xl border border-[var(--color-border)] p-4">
      <h2 class="text-base font-semibold text-[var(--color-text)]">Top shared places</h2>
      <div class="mt-4 space-y-3">
        {#if loading}
          <p class="text-sm text-[var(--color-text-muted)]">Loading shared places...</p>
        {:else if places.length === 0}
          <p class="text-sm text-[var(--color-text-muted)]">No shared places yet.</p>
        {:else}
        {#each places as place (place.name)}
          <div>
            <div class="flex justify-between text-sm">
              <span class="font-medium text-[var(--color-text)]">{place.name}</span>
              <span class="text-[var(--color-text-muted)]">{place.count}</span>
            </div>
            <div class="mt-2 h-2 rounded-full bg-[var(--color-surface-input)] overflow-hidden">
              <div class="h-full rounded-full bg-black" style="width: {Math.max(8, Math.round(place.strength * 100))}%"></div>
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
