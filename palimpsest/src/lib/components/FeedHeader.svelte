<script lang="ts">
  let {
    activeTab,
    ontabchange
  }: {
    activeTab: string;
    ontabchange?: (tab: string) => void;
  } = $props();

  const tabs = [
    { id: 'following', label: 'Following' },
    { id: 'for_you', label: 'For you' },
    { id: 'favorites', label: 'Favorites' }
  ];
</script>

<div class="flex items-center justify-center gap-[30px] px-4 py-[10px] bg-[var(--color-surface)]">
  {#each tabs as tab (tab.id)}
    <button
      onclick={() => ontabchange?.(tab.id)}
      class="relative text-sm font-semibold transition-colors pb-2 {activeTab === tab.id ? 'text-[var(--color-text)]' : 'text-[var(--color-text-muted)]'}"
    >
      {tab.label}
      {#if activeTab === tab.id}
        <div class="absolute bottom-0 left-1/2 -translate-x-1/2 w-[24px] h-[2px] rounded-[1px] bg-[var(--color-text)]"></div>
      {/if}
    </button>
  {/each}
</div>
