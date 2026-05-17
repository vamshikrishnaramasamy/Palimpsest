<script lang="ts">
  import { onMount } from 'svelte';
  import { authState, signOut } from '$lib/stores/auth.svelte';
  import { client } from '$lib/api';
  import { goto } from '$app/navigation';
  import TabBar from '$lib/components/TabBar.svelte';

  type ProfileData = {
    id: string;
    email: string;
    display_name: string;
    avatar_url: string | null;
    created_at: string;
    posts_count: number;
    followers_count: number;
    following_count: number;
  };

  let profile = $state<ProfileData | null>(null);
  let loading = $state(true);
  let error = $state<string | null>(null);

  // Edit form state
  let editDisplayName = $state('');
  let editAvatarFile = $state<File | null>(null);
  let editAvatarPreview = $state<string | null>(null);
  let editPassword = $state('');
  let saving = $state(false);
  let saveError = $state<string | null>(null);
  let saveSuccess = $state(false);

  onMount(async () => {
    if (!authState.user) { loading = false; return; }
    try {
      profile = (await client.profile.get()) as ProfileData;
      editDisplayName = profile.display_name || '';
    } catch (e: any) {
      error = e.message;
    }
    loading = false;
  });

  function handleAvatarSelect(e: Event) {
    const input = e.target as HTMLInputElement;
    const file = input.files?.[0];
    if (file) {
      editAvatarFile = file;
      const reader = new FileReader();
      reader.onload = () => {
        editAvatarPreview = reader.result as string;
      };
      reader.readAsDataURL(file);
    }
  }

  async function saveProfile(e: Event) {
    e.preventDefault();
    if (saving) return;
    saving = true;
    saveError = null;
    saveSuccess = false;

    try {
      const form = new FormData();
      if (editDisplayName.trim()) {
        form.append('display_name', editDisplayName.trim());
      }
      if (editAvatarFile) {
        form.append('avatar', editAvatarFile);
      }
      if (editPassword.length >= 6) {
        form.append('password', editPassword);
      }

      const result = (await client.profile.update(form)) as { id: string; email: string; display_name: string; avatar_url: string | null };
      if (profile) {
        profile.display_name = result.display_name;
        profile.avatar_url = result.avatar_url;
      }
      editAvatarFile = null;
      editAvatarPreview = null;
      editPassword = '';
      saveSuccess = true;
      setTimeout(() => { saveSuccess = false; }, 3000);
    } catch (e: any) {
      saveError = e.message;
    }
    saving = false;
  }

  function avatarLetter(): string {
    if (!profile) return '?';
    return (profile.display_name || profile.email || '?')[0].toUpperCase();
  }
</script>

<div class="h-dvh flex flex-col bg-[var(--color-surface)]">
  <div class="flex-1 overflow-y-auto p-4 pb-[120px] max-w-md mx-auto w-full space-y-6 animate-fade-in">
    <h1 class="text-xl font-bold text-[var(--color-text)]">Profile</h1>

    {#if !authState.user}
      <div class="text-center py-12 bg-[var(--color-surface-muted)] border border-[var(--color-border)] rounded-2xl">
        <p class="text-[var(--color-text-muted)] text-sm">Sign in to manage your profile</p>
        <a href="/" class="inline-block mt-3 px-4 py-2 bg-black text-white rounded-lg text-sm font-medium hover:bg-[#333] transition-colors">
          Sign In
        </a>
      </div>
    {:else if loading}
      <div class="animate-pulse space-y-4">
        <div class="flex flex-col items-center gap-3 py-8">
          <div class="w-20 h-20 rounded-full bg-[var(--color-surface-input)]"></div>
          <div class="h-4 w-32 bg-[var(--color-surface-input)] rounded"></div>
          <div class="h-3 w-48 bg-[var(--color-surface-input)] rounded"></div>
        </div>
        <div class="h-16 bg-[var(--color-surface-input)] rounded-2xl"></div>
      </div>
    {:else if error}
      <div class="text-center py-12 bg-[var(--color-surface-muted)] border border-[var(--color-border)] rounded-2xl">
        <p class="text-red-500 text-sm">{error}</p>
      </div>
    {:else if profile}
      <!-- Avatar & name -->
      <div class="flex flex-col items-center gap-3 py-4">
        {#if profile.avatar_url}
          <img
            src={profile.avatar_url}
            alt="Avatar"
            class="w-20 h-20 rounded-full object-cover border-2 border-[var(--color-border)]"
          />
        {:else}
          <div class="w-20 h-20 rounded-full bg-[var(--color-surface-input)] flex items-center justify-center text-2xl font-bold text-[var(--color-text)] border-2 border-[var(--color-border)]">
            {avatarLetter()}
          </div>
        {/if}
        <div class="text-center">
          <h2 class="text-lg font-semibold text-[var(--color-text)]">{profile.display_name || 'Anonymous'}</h2>
          <p class="text-sm text-[var(--color-text-muted)]">{profile.email}</p>
        </div>
      </div>

      <!-- Stats row -->
      <div class="flex justify-center gap-8 py-3 bg-[var(--color-surface)] border border-[var(--color-border)] rounded-2xl">
        <div class="text-center">
          <p class="text-lg font-bold text-[var(--color-text)]">{profile.posts_count}</p>
          <p class="text-xs text-[var(--color-text-muted)]">Posts</p>
        </div>
        <div class="w-px bg-[var(--color-border)]"></div>
        <div class="text-center">
          <p class="text-lg font-bold text-[var(--color-text)]">{profile.followers_count}</p>
          <p class="text-xs text-[var(--color-text-muted)]">Followers</p>
        </div>
        <div class="w-px bg-[var(--color-border)]"></div>
        <div class="text-center">
          <p class="text-lg font-bold text-[var(--color-text)]">{profile.following_count}</p>
          <p class="text-xs text-[var(--color-text-muted)]">Following</p>
        </div>
      </div>

      <!-- Edit profile form -->
      <div class="bg-[var(--color-surface)] border border-[var(--color-border)] rounded-2xl p-5 space-y-4">
        <h3 class="text-sm font-medium text-[var(--color-text)]">Edit Profile</h3>

        <form onsubmit={saveProfile} class="space-y-3">
          <!-- Display name -->
          <div>
            <span class="text-xs text-[var(--color-text-muted)] block mb-1">Display Name</span>
            <input
              type="text"
              bind:value={editDisplayName}
              placeholder="Your display name"
              class="w-full px-4 py-2.5 bg-[var(--color-surface)] border border-[var(--color-border)] rounded-lg text-sm placeholder:text-[var(--color-text-muted)] focus:outline-none focus:border-black transition-colors"
            />
          </div>

          <!-- Avatar upload -->
          <div>
            <span class="text-xs text-[var(--color-text-muted)] block mb-1">Avatar</span>
            <label class="flex items-center gap-2 px-4 py-2.5 bg-[var(--color-surface)] border border-[var(--color-border)] rounded-lg text-sm text-[var(--color-text-muted)] hover:bg-[var(--color-surface-muted)] hover:text-[var(--color-text)] transition-colors cursor-pointer">
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M6.827 6.175A2.31 2.31 0 015.186 7.23c-.38.054-.757.112-1.134.175C2.999 7.58 2.25 8.507 2.25 9.574V18a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18V9.574c0-1.067-.75-1.994-1.802-2.169a47.865 47.865 0 00-1.134-.175 2.31 2.31 0 01-1.64-1.055l-.822-1.316a2.192 2.192 0 00-1.736-1.039 48.774 48.774 0 00-5.232 0 2.192 2.192 0 00-1.736 1.039l-.821 1.316z" />
                <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 12.75a4.5 4.5 0 11-9 0 4.5 4.5 0 019 0z" />
              </svg>
              {editAvatarFile ? editAvatarFile.name : 'Change avatar'}
              <input
                type="file"
                accept="image/*"
                onchange={handleAvatarSelect}
                class="hidden"
              />
            </label>
            {#if editAvatarPreview}
              <div class="mt-2 flex items-center gap-2">
                <img src={editAvatarPreview} alt="Preview" class="w-10 h-10 rounded-full object-cover" />
                <span class="text-xs text-[var(--color-text-muted)]">New avatar preview</span>
              </div>
            {/if}
          </div>

          <!-- Password -->
          <div>
            <span class="text-xs text-[var(--color-text-muted)] block mb-1">New Password (leave blank to keep current)</span>
            <input
              type="password"
              bind:value={editPassword}
              placeholder="Min 6 characters"
              minlength={6}
              class="w-full px-4 py-2.5 bg-[var(--color-surface)] border border-[var(--color-border)] rounded-lg text-sm placeholder:text-[var(--color-text-muted)] focus:outline-none focus:border-black transition-colors"
            />
          </div>

          {#if saveError}
            <p class="text-red-500 text-xs">{saveError}</p>
          {/if}

          {#if saveSuccess}
            <p class="text-green-600 text-xs">Profile updated successfully</p>
          {/if}

          <button
            type="submit"
            disabled={saving}
            class="w-full py-2.5 bg-black text-white rounded-lg text-sm font-medium hover:bg-[#333] transition-colors disabled:opacity-50"
          >
            {saving ? 'Saving...' : 'Save Changes'}
          </button>
        </form>
      </div>

      <!-- Sign out -->
      <button
        onclick={async () => { await signOut(); goto('/'); }}
        class="w-full py-2.5 bg-[var(--color-surface-input)] text-red-500 rounded-lg text-sm font-medium hover:bg-[var(--color-border)] transition-colors"
      >
        Sign Out
      </button>
    {/if}
  </div>

  <!-- Fixed bottom: TabBar -->
  <div class="fixed bottom-0 left-0 right-0 z-50">
    <TabBar />
  </div>
</div>
