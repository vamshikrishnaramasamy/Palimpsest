<script lang="ts">
  import { authState } from '$lib/stores/auth.svelte';
  import TabBar from '$lib/components/TabBar.svelte';
  import { client } from '$lib/api';
  import maplibregl from 'maplibre-gl';

  // Sign-in form state
  let email = $state('');
  let password = $state('');
  let isSignUp = $state(true);
  let submitting = $state(false);

  async function handleAuth(e: Event) {
    e.preventDefault();
    submitting = true;
    authState.error = null;
    try {
      if (isSignUp) {
        const displayName = email.split('@')[0];
        const data = await client.auth.signUp(email, password, displayName);
        authState.user = data.user;
      } else {
        const data = await client.auth.signIn(email, password);
        authState.user = data.user;
      }
    } catch (e: any) {
      authState.error = e.message;
    }
    submitting = false;
  }

  // Map state
  let mapContainer = $state<HTMLDivElement>();
  let map: maplibregl.Map;

  // Dynamic stories from db
  let stories = $state<any[]>([]);

  $effect(() => {
    if (authState.user && stories.length === 0) {
      client.posts.list({ limit: 50 }).then(posts => {
        stories = posts.map((p: any) => {
          // Simulate audio duration from body length
          const words = (p.body || '').split(/\s+/).length;
          const totalSec = Math.max(15, Math.round(words * 2.5 + Math.random() * 30));
          const mins = Math.floor(totalSec / 60);
          const secs = totalSec % 60;
          const duration = mins > 0 ? `${mins} min ${secs} sec` : `${secs} sec`;
          return {
            id: p.id,
            title: p.body || 'Audio Story',
            author: p.display_name || p.email?.split('@')[0] || 'Anonymous',
            duration,
            timeAgo: timeAgo(p.created_at),
            avatar: p.avatar_url || `https://i.pravatar.cc/150?u=${p.user_id}`,
            lng: p.lng,
            lat: p.lat
          };
        });
        updateMapData();
      }).catch(e => console.error('Failed to load stories', e));
    }
  });

  function timeAgo(dateStr: string): string {
    const diff = Date.now() - new Date(dateStr + 'Z').getTime();
    const mins = Math.floor(diff / 60000);
    if (mins < 1) return 'just now';
    if (mins < 60) return `${mins}m ago`;
    const hrs = Math.floor(mins / 60);
    if (hrs < 24) return `${hrs}h ago`;
    const days = Math.floor(hrs / 24);
    if (days < 7) return `${days}d ago`;
    if (days < 30) return `${Math.floor(days / 7)}w ago`;
    return new Date(dateStr).toLocaleDateString();
  }

  let markers: maplibregl.Marker[] = [];

  function updateMapData() {
    if (map && map.getSource('overlap-points')) {
      const features = stories.filter(s => s.lng != null && s.lat != null).map(s => ({
        type: 'Feature', geometry: { type: 'Point', coordinates: [s.lng, s.lat] }, properties: {}
      }));
      (map.getSource('overlap-points') as maplibregl.GeoJSONSource).setData({
        type: 'FeatureCollection',
        features
      } as any);

      // Clear existing markers
      markers.forEach(m => m.remove());
      markers = [];

      // Add pins for stories
      stories.forEach(s => {
        if (s.lng != null && s.lat != null) {
          const el = document.createElement('div');
          el.className = 'w-8 h-8 rounded-full border-2 border-white shadow-md bg-cover bg-center cursor-pointer transition-transform hover:scale-110';
          el.style.backgroundImage = `url(${s.avatar})`;
          
          const marker = new maplibregl.Marker({ element: el })
            .setLngLat([s.lng, s.lat])
            .addTo(map);
          
          // Click marker to fly to it
          el.addEventListener('click', () => flyToStory(s));

          markers.push(marker);
        }
      });
    }
  }

  function flyToStory(story: any) {
    if (map && story.lng != null && story.lat != null) {
      map.flyTo({ center: [story.lng, story.lat], zoom: 16, essential: true });
    }
  }

  $effect(() => {
    if (authState.user && mapContainer && !map) {
      map = new maplibregl.Map({
        container: mapContainer,
        style: 'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json',
        center: [-117.2340, 32.8801], // UCSD / San Diego default
        zoom: 13,
        attributionControl: false
      });

      // Try to center on the user's actual location
      if ('geolocation' in navigator) {
        navigator.geolocation.getCurrentPosition((pos) => {
          map.flyTo({ center: [pos.coords.longitude, pos.coords.latitude], zoom: 14, essential: true });
        }, () => {}, { enableHighAccuracy: true });
      }

      map.on('load', () => {
        // Add Overlap heatmaps/circles source
        map.addSource('overlap-points', {
          type: 'geojson',
          data: {
            type: 'FeatureCollection',
            features: []
          }
        });
        
        updateMapData();

        // Add the outer lighter red circle
        map.addLayer({
          id: 'overlap-circles-outer',
          type: 'circle',
          source: 'overlap-points',
          paint: {
            'circle-radius': 60,
            'circle-color': '#ff4d4d',
            'circle-opacity': 0.4
          }
        });

        // Add the inner darker red circle
        map.addLayer({
          id: 'overlap-circles-inner',
          type: 'circle',
          source: 'overlap-points',
          paint: {
            'circle-radius': 20,
            'circle-color': '#ff4d4d',
            'circle-opacity': 0.8
          }
        });
      });
    }
  });
</script>

{#if !authState.user}
  <!-- OverLap Sign In / Sign Up Screen -->
  <div class="h-dvh flex flex-col items-center justify-center px-6 bg-[var(--color-surface)] animate-fade-in">
    <!-- Logo -->
    <div class="relative mb-8">
      <div class="flex items-center justify-center relative" style="width: 200px; height: 160px;">
        <div class="absolute rounded-full" style="width: 140px; height: 140px; background: #b0b0b0; left: 10px; top: 10px; opacity: 0.7;"></div>
        <div class="absolute rounded-full" style="width: 140px; height: 140px; background: #d9d9d9; right: 10px; top: 10px; opacity: 0.7;"></div>
        <span class="relative z-10 text-4xl font-bold tracking-tight text-[var(--color-text)]" style="font-size: 42px;">OverLap</span>
      </div>
    </div>

    <!-- Auth form -->
    <div class="w-full max-w-[327px] space-y-6">
      <div class="text-center space-y-1">
        <h2 class="text-base font-semibold text-[var(--color-text)]">
          {isSignUp ? 'Create an account' : 'Welcome back'}
        </h2>
        <p class="text-sm text-[var(--color-text-muted)]">
          Enter your email to {isSignUp ? 'sign up for' : 'sign in to'} this app
        </p>
      </div>

      <form onsubmit={handleAuth} class="space-y-4">
        <div class="w-full px-4 py-2.5 border border-[var(--color-border)] rounded-lg bg-[var(--color-surface)]">
          <input
            type="email" bind:value={email} placeholder="email@domain.com"
            autocomplete="email" required
            class="w-full text-sm text-[var(--color-text)] placeholder:text-[var(--color-text-muted)] focus:outline-none bg-transparent"
          />
        </div>
        <div class="w-full px-4 py-2.5 border border-[var(--color-border)] rounded-lg bg-[var(--color-surface)]">
          <input
            type="password" bind:value={password} placeholder="Password"
            autocomplete={isSignUp ? 'new-password' : 'current-password'}
            minlength={6} required
            class="w-full text-sm text-[var(--color-text)] placeholder:text-[var(--color-text-muted)] focus:outline-none bg-transparent"
          />
        </div>
        {#if authState.error}
          <p class="text-red-500 text-xs text-center">{authState.error}</p>
        {/if}
        <button
          type="submit" disabled={submitting}
          class="w-full py-2.5 bg-black text-white rounded-lg font-medium text-sm hover:bg-[#333] transition-colors disabled:opacity-50"
        >
          {submitting ? '...' : 'Continue'}
        </button>
      </form>

      <div class="flex items-center gap-2">
        <div class="flex-1 h-px bg-[var(--color-border)]"></div>
        <span class="text-sm text-[var(--color-text-muted)]">or</span>
        <div class="flex-1 h-px bg-[var(--color-border)]"></div>
      </div>

      <div class="space-y-2">
        <button class="w-full flex items-center justify-center gap-2 py-2.5 bg-[var(--color-surface-input)] rounded-lg text-sm font-medium text-[var(--color-text)] hover:bg-[#e0e0e0] transition-colors">
          <svg class="w-5 h-5" viewBox="0 0 24 24">
            <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z" fill="#4285F4"/>
            <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
            <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/>
            <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
          </svg>
          Continue with Google
        </button>
        <button class="w-full flex items-center justify-center gap-2 py-2.5 bg-[var(--color-surface-input)] rounded-lg text-sm font-medium text-[var(--color-text)] hover:bg-[#e0e0e0] transition-colors">
          <svg class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
            <path d="M17.05 20.28c-.98.95-2.05.88-3.08.4-1.09-.5-2.08-.48-3.24 0-1.44.62-2.2.44-3.06-.4C2.79 15.25 3.51 7.59 9.05 7.31c1.35.07 2.29.74 3.08.8 1.18-.24 2.31-.93 3.57-.84 1.51.12 2.65.72 3.4 1.8-3.12 1.87-2.38 5.98.48 7.13-.57 1.5-1.31 2.99-2.54 4.09zM12.03 7.25c-.15-2.23 1.66-4.07 3.74-4.25.29 2.58-2.34 4.5-3.74 4.25z"/>
          </svg>
          Continue with Apple
        </button>
      </div>
      <p class="text-center text-xs text-[var(--color-text-muted)]">
        {isSignUp ? 'Already have an account?' : "Don't have an account?"}
        <button onclick={() => { isSignUp = !isSignUp; authState.error = null; }} class="ml-1 text-[var(--color-text)] font-medium hover:underline">
          {isSignUp ? 'Sign in' : 'Sign up'}
        </button>
      </p>
    </div>
  </div>
{:else}
  <!-- Authenticated: OverLap + Palimpsest Map Screen -->
  <div class="h-dvh flex flex-col bg-[var(--color-surface)] relative overflow-hidden">
    
    <!-- Header Logo -->
    <div class="absolute top-0 left-0 right-0 z-10 flex justify-center pt-12 pb-4 bg-gradient-to-b from-white via-white/80 to-transparent pointer-events-none">
      <div class="flex items-center justify-center relative" style="width: 80px; height: 60px;">
        <div class="absolute rounded-full" style="width: 56px; height: 56px; background: #b0b0b0; left: 4px; top: 2px; opacity: 0.7;"></div>
        <div class="absolute rounded-full" style="width: 56px; height: 56px; background: #d9d9d9; right: 4px; top: 2px; opacity: 0.7;"></div>
        <span class="relative z-10 font-bold tracking-tight text-[var(--color-text)]" style="font-size: 16px;">OverLap</span>
      </div>
    </div>

    <!-- Map Area (Overlap Feature) -->
    <div class="absolute inset-0 z-0">
      <div bind:this={mapContainer} class="w-full h-full"></div>
    </div>

    <!-- Location Stories (Palimpsest Feature) -->
    <div class="absolute bottom-0 left-0 right-0 z-20 pointer-events-none pb-[80px]">
      <div class="bg-white/90 backdrop-blur-xl w-full rounded-t-3xl pt-4 px-4 shadow-[0_-4px_32px_rgba(0,0,0,0.1)] pointer-events-auto flex flex-col" style="max-height: 50vh;">
        <div class="w-12 h-1.5 bg-gray-300 rounded-full mx-auto mb-4 shrink-0"></div>
        
        <div class="space-y-3 overflow-y-auto pb-6 scrollbar-hide">
          {#if stories.length === 0}
            <div class="py-6 text-center">
              <div class="mx-auto w-14 h-14 rounded-full bg-[var(--color-surface-input)] flex items-center justify-center">
                <svg class="w-7 h-7 text-[var(--color-text-muted)]" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7Z"/>
                </svg>
              </div>
              <h2 class="mt-3 text-base font-semibold text-[var(--color-text)]">No nearby stories yet</h2>
              <p class="mt-1 text-sm text-[var(--color-text-muted)] px-6">Leave the first memory here and the map will start to come alive.</p>
              <a href="/create" class="inline-flex mt-4 px-5 py-2.5 rounded-lg bg-black text-white text-sm font-medium">
                Leave a Story
              </a>
            </div>
          {:else}
            {#each stories as story (story.id)}
              <button onclick={() => flyToStory(story)} class="w-full flex items-center gap-4 p-3 rounded-2xl bg-[var(--color-surface-input)] border border-[var(--color-border)] hover:bg-[#e8e8e8] transition-colors text-left">
                <img src={story.avatar} alt="User Avatar" class="w-14 h-14 rounded-full object-cover shrink-0" />
                <div class="flex-1 min-w-0">
                  <h3 class="text-[15px] font-medium text-[var(--color-text)] truncate">{story.title}</h3>
                  <p class="text-[13px] text-[var(--color-text-muted)] mt-1">{story.author} · {story.duration} · {story.timeAgo}</p>
                </div>
              </button>
            {/each}
          {/if}
        </div>
      </div>
    </div>

    <!-- Fixed bottom: TabBar -->
    <div class="fixed bottom-0 left-0 right-0 z-50 pointer-events-auto">
      <TabBar />
    </div>
  </div>
{/if}
