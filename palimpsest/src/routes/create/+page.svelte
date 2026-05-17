<script lang="ts">
  import { goto } from '$app/navigation';
  import { client } from '$lib/api';
  import { authState } from '$lib/stores/auth.svelte';
  import TabBar from '$lib/components/TabBar.svelte';

  let body = $state('');
  let placeName = $state('Current location');
  let mood = $state('Memory');
  let submitting = $state(false);
  let error = $state<string | null>(null);
  let locationStatus = $state('Location is optional for the demo');
  let userLocation = $state<{ lng: number; lat: number } | null>({
    lng: -122.4194,
    lat: 37.7749
  });
  let mediaFiles = $state<File[]>([]);
  let mediaPreviews = $state<string[]>([]);

  const moods = ['Memory', 'Secret', 'Audio', 'Warning'];

  function useBrowserLocation() {
    if (!('geolocation' in navigator)) {
      locationStatus = 'Browser location is not available';
      return;
    }
    locationStatus = 'Finding you...';
    navigator.geolocation.getCurrentPosition(
      (position) => {
        userLocation = {
          lng: position.coords.longitude,
          lat: position.coords.latitude
        };
        locationStatus = 'Pinned to your current location';
      },
      () => {
        locationStatus = 'Using demo location. You can still leave a story.';
      },
      { enableHighAccuracy: true, timeout: 6000 }
    );
  }

  function handleMediaSelect(e: Event) {
    const input = e.target as HTMLInputElement;
    const files = Array.from(input.files || []);
    mediaFiles = [...mediaFiles, ...files];
    files.forEach((file) => {
      if (!file.type.startsWith('image/')) {
        mediaPreviews = [...mediaPreviews, 'audio'];
        return;
      }
      const reader = new FileReader();
      reader.onload = () => {
        mediaPreviews = [...mediaPreviews, reader.result as string];
      };
      reader.readAsDataURL(file);
    });
  }

  function removeMedia(index: number) {
    mediaFiles = mediaFiles.filter((_, i) => i !== index);
    mediaPreviews = mediaPreviews.filter((_, i) => i !== index);
  }

  async function handleSubmit(e: Event) {
    e.preventDefault();
    if (!body.trim() && mediaFiles.length === 0) return;
    if (!authState.user) {
      error = 'Sign in first, then leave your story.';
      return;
    }

    submitting = true;
    error = null;

    try {
      const form = new FormData();
      form.append('body', `[${mood}] ${body.trim()}`);
      if (userLocation) {
        form.append('lng', String(userLocation.lng));
        form.append('lat', String(userLocation.lat));
      }
      mediaFiles.forEach((file, i) => form.append(`media_${i}`, file));
      await client.posts.create(form);
      goto('/notifications');
    } catch (e: any) {
      error = e.message;
    }
    submitting = false;
  }
</script>

<div class="h-dvh flex flex-col bg-[var(--color-surface)]">
  <div class="flex-1 overflow-y-auto px-5 pt-6 pb-[112px] max-w-md mx-auto w-full animate-fade-in">
    <p class="text-xs font-semibold uppercase tracking-[0.12em] text-[var(--color-text-muted)]">Palimpsest</p>
    <h1 class="text-[30px] leading-tight font-bold text-[var(--color-text)] mt-1">Leave a layer here</h1>
    <p class="text-sm text-[var(--color-text-muted)] mt-2 leading-snug">
      Drop an audio story, secret, or memory onto a physical place for future visitors to unlock.
    </p>

    <div class="mt-6 relative h-56 rounded-[28px] bg-[var(--color-surface-input)] overflow-hidden border border-[var(--color-border)]">
      <div class="absolute inset-0 bg-white" style="background-image: linear-gradient(#ececec 1px, transparent 1px), linear-gradient(90deg, #ececec 1px, transparent 1px); background-size: 30px 30px;"></div>
      <div class="absolute left-[24%] top-[24%] w-36 h-36 rounded-full bg-red-400/20"></div>
      <div class="absolute right-[18%] bottom-[18%] w-28 h-28 rounded-full bg-black/10"></div>
      <div class="absolute inset-0 flex items-center justify-center">
        <div class="w-16 h-16 rounded-full bg-black text-white flex items-center justify-center shadow-xl">
          <svg class="w-8 h-8" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
        </div>
      </div>
      <div class="absolute left-4 right-4 bottom-4 rounded-2xl bg-white/90 backdrop-blur border border-[var(--color-border)] px-4 py-3">
        <div class="flex items-center justify-between gap-3">
          <div class="min-w-0">
            <p class="text-sm font-semibold text-[var(--color-text)] truncate">{placeName}</p>
            <p class="text-xs text-[var(--color-text-muted)] mt-0.5">{locationStatus}</p>
          </div>
          <button onclick={useBrowserLocation} class="shrink-0 px-3 py-2 rounded-lg bg-black text-white text-xs font-medium">
            Use GPS
          </button>
        </div>
      </div>
    </div>

    <form onsubmit={handleSubmit} class="mt-6 space-y-4">
      <div>
        <label for="place" class="text-xs font-medium text-[var(--color-text-muted)]">Place label</label>
        <input
          id="place"
          bind:value={placeName}
          class="mt-1 w-full h-11 px-4 rounded-xl border border-[var(--color-border)] bg-white text-sm focus:outline-none focus:border-black"
          placeholder="Bench outside Geisel, third floor stairwell..."
        />
      </div>

      <div>
        <p class="text-xs font-medium text-[var(--color-text-muted)]">Layer type</p>
        <div class="mt-2 flex gap-2 overflow-x-auto scrollbar-hide">
          {#each moods as option}
            <button
              type="button"
              onclick={() => mood = option}
              class="px-4 py-2 rounded-full text-sm font-medium shrink-0 {mood === option ? 'bg-black text-white' : 'bg-[var(--color-surface-input)] text-[var(--color-text)]'}"
            >
              {option}
            </button>
          {/each}
        </div>
      </div>

      <textarea
        bind:value={body}
        rows={6}
        placeholder="What should someone feel when they stand here?"
        class="w-full px-4 py-3 bg-white border border-[var(--color-border)] rounded-2xl text-sm leading-relaxed text-[var(--color-text)] placeholder:text-[var(--color-text-muted)] focus:outline-none focus:border-black resize-none"
      ></textarea>

      {#if mediaPreviews.length > 0}
        <div class="flex gap-2 overflow-x-auto scrollbar-hide">
          {#each mediaPreviews as preview, i}
            <div class="relative w-20 h-20 rounded-2xl bg-[var(--color-surface-input)] overflow-hidden border border-[var(--color-border)] flex items-center justify-center shrink-0">
              {#if preview === 'audio'}
                <svg class="w-7 h-7 text-[var(--color-text-muted)]" viewBox="0 0 24 24" fill="currentColor"><path d="M12 3v10.55A4 4 0 1 0 14 17V7h4V3h-6Z"/></svg>
              {:else}
                <img src={preview} alt="preview" class="w-full h-full object-cover" />
              {/if}
              <button type="button" onclick={() => removeMedia(i)} class="absolute top-1.5 right-1.5 w-6 h-6 rounded-full bg-black/70 text-white text-xs">x</button>
            </div>
          {/each}
        </div>
      {/if}

      <div class="grid grid-cols-2 gap-3">
        <label class="flex items-center justify-center gap-2 h-12 rounded-2xl bg-[var(--color-surface-input)] text-sm font-medium cursor-pointer">
          <svg class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="12" r="6"/></svg>
          Add audio
          <input type="file" accept="audio/*" class="hidden" onchange={handleMediaSelect} />
        </label>
        <label class="flex items-center justify-center gap-2 h-12 rounded-2xl bg-[var(--color-surface-input)] text-sm font-medium cursor-pointer">
          <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M4 16l4-4 4 4 4-5 4 5M4 5h16v14H4z" />
          </svg>
          Add image
          <input type="file" accept="image/*" multiple class="hidden" onchange={handleMediaSelect} />
        </label>
      </div>

      {#if error}
        <p class="text-red-500 text-sm text-center">{error}</p>
      {/if}

      <button
        type="submit"
        disabled={submitting || (!body.trim() && mediaFiles.length === 0)}
        class="w-full h-13 py-3.5 rounded-2xl bg-black text-white text-sm font-semibold disabled:opacity-50"
      >
        {submitting ? 'Layering story...' : authState.user ? 'Leave Story Here' : 'Sign in to Leave Story'}
      </button>
    </form>
  </div>

  <div class="fixed bottom-0 left-0 right-0 z-50">
    <TabBar />
  </div>
</div>
