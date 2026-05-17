<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/state';
  import { client } from '$lib/api';
  import { authState } from '$lib/stores/auth.svelte';
  import CommentSection from '$lib/components/CommentSection.svelte';
  import TabBar from '$lib/components/TabBar.svelte';

  type PostData = {
    id: string;
    user_id: string;
    body: string;
    image_url: string | null;
    display_name: string;
    email: string;
    like_count: number;
    comment_count: number;
    liked_by_me: boolean;
    created_at: string;
  };

  let post = $state<PostData | null>(null);
  let loading = $state(true);
  let error = $state<string | null>(null);
  let liking = $state(false);

  onMount(async () => {
    try {
      const posts = (await client.posts.list({ limit: 500 })) as PostData[];
      post = posts.find((p) => p.id === page.params.id) ?? null;
      if (!post) {
        error = 'Post not found';
      }
    } catch (e: any) {
      error = e.message;
    }
    loading = false;
  });

  function timeAgo(dateStr: string): string {
    const diff = Date.now() - new Date(dateStr).getTime();
    const mins = Math.floor(diff / 60000);
    if (mins < 1) return 'just now';
    if (mins < 60) return `${mins}m ago`;
    const hrs = Math.floor(mins / 60);
    if (hrs < 24) return `${hrs}h ago`;
    const days = Math.floor(hrs / 24);
    if (days < 7) return `${days}d ago`;
    return new Date(dateStr).toLocaleDateString();
  }

  function avatarLetter(): string {
    if (!post) return '?';
    return (post.display_name || post.email || '?')[0].toUpperCase();
  }

  async function toggleLike() {
    if (!post || liking || !authState.user) return;
    liking = true;
    const wasLiked = post.liked_by_me;
    post.liked_by_me = !wasLiked;
    post.like_count += wasLiked ? -1 : 1;
    try {
      const result = await client.posts.like(post.id);
      if (result.liked !== post.liked_by_me) {
        post.liked_by_me = result.liked;
        post.like_count += result.liked ? 1 : -1;
      }
    } catch {
      post.liked_by_me = wasLiked;
      post.like_count += wasLiked ? 1 : -1;
    }
    liking = false;
  }
</script>

<div class="h-dvh flex flex-col bg-[var(--color-surface)]">
  <div class="flex-1 overflow-y-auto p-4 pb-[120px] max-w-lg mx-auto w-full animate-fade-in">
    <a href="/" class="inline-flex items-center gap-1.5 text-sm text-[var(--color-text-muted)] hover:text-[var(--color-text)] transition-colors mb-4">
      <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
        <path stroke-linecap="round" stroke-linejoin="round" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
      </svg>
      Back
    </a>

    {#if loading}
      <div class="animate-pulse space-y-4 bg-[var(--color-surface)] border border-[var(--color-border)] rounded-2xl p-5">
        <div class="flex items-center gap-3">
          <div class="w-10 h-10 rounded-full bg-[var(--color-surface-input)]"></div>
          <div class="space-y-2">
            <div class="h-3 w-24 bg-[var(--color-surface-input)] rounded"></div>
            <div class="h-2.5 w-16 bg-[var(--color-surface-input)] rounded"></div>
          </div>
        </div>
        <div class="space-y-2">
          <div class="h-3 w-full bg-[var(--color-surface-input)] rounded"></div>
          <div class="h-3 w-3/4 bg-[var(--color-surface-input)] rounded"></div>
        </div>
      </div>
    {:else if error}
      <div class="text-center py-16 bg-[var(--color-surface)] border border-[var(--color-border)] rounded-2xl">
        <p class="text-[var(--color-text-muted)] text-sm mb-3">{error}</p>
        <a href="/" class="inline-block px-4 py-2 bg-black text-white rounded-lg text-sm font-medium hover:bg-[#333] transition-colors">
          Go Home
        </a>
      </div>
    {:else if post}
      <div class="bg-[var(--color-surface)] border border-[var(--color-border)] rounded-2xl p-5 space-y-4">
        <!-- Author header -->
        <div class="flex items-center gap-3">
          <div class="w-10 h-10 rounded-full bg-[var(--color-surface-muted)] flex items-center justify-center text-sm font-semibold text-[var(--color-text)] shrink-0 border border-[var(--color-border)]">
            {avatarLetter()}
          </div>
          <div class="min-w-0">
            <p class="text-sm font-medium text-[var(--color-text)] truncate">
              {post.display_name || post.email}
            </p>
            <p class="text-xs text-[var(--color-text-muted)]">
              {timeAgo(post.created_at)}
            </p>
          </div>
        </div>

        <!-- Body -->
        {#if post.body}
          <p class="text-sm text-[var(--color-text)] leading-relaxed whitespace-pre-wrap break-words">
            {post.body}
          </p>
        {/if}

        <!-- Image -->
        {#if post.image_url}
          <img
            src={post.image_url}
            alt="Post attachment"
            class="w-full max-h-96 object-contain rounded-xl bg-[var(--color-surface-muted)]"
          />
        {/if}

        <!-- Like & comment counts -->
        <div class="flex items-center gap-4 pt-2 border-t border-[var(--color-border)]">
          <button
            onclick={toggleLike}
            disabled={!authState.user || liking}
            class="flex items-center gap-1.5 text-sm transition-colors {post.liked_by_me ? 'text-red-500' : 'text-[var(--color-text-muted)] hover:text-red-400'} disabled:opacity-50"
          >
            {#if post.liked_by_me}
              <svg class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                <path d="M11.645 20.91l-.007-.003-.022-.012a15.247 15.247 0 01-.383-.218 25.18 25.18 0 01-4.244-3.17C4.688 15.36 2.25 12.174 2.25 8.25 2.25 5.322 4.714 3 7.688 3A5.5 5.5 0 0112 5.052 5.5 5.5 0 0116.313 3c2.973 0 5.437 2.322 5.437 5.25 0 3.925-2.438 7.111-4.739 9.256a25.175 25.175 0 01-4.244 3.17 15.247 15.247 0 01-.383.219l-.022.012-.007.004-.003.001a.752.752 0 01-.704 0l-.003-.001z" />
              </svg>
            {:else}
              <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12z" />
              </svg>
            {/if}
            <span>{post.like_count}</span>
          </button>
          <span class="flex items-center gap-1.5 text-sm text-[var(--color-text-muted)]">
            <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M20.25 8.511c.884.284 1.5 1.128 1.5 2.097v4.286c0 1.136-.847 2.1-1.98 2.193-.34.027-.68.052-1.02.072v3.091l-3-3c-1.354 0-2.694-.055-4.02-.163a2.115 2.115 0 01-.825-.242m9.345-8.334a2.126 2.126 0 00-.476-.095 48.64 48.64 0 00-8.048 0c-1.131.094-1.976 1.057-1.976 2.192v4.286c0 .837.46 1.58 1.155 1.951m9.345-8.334V6.637c0-1.621-1.152-3.026-2.76-3.235A48.455 48.455 0 0011.25 3c-2.115 0-4.198.137-6.24.402-1.608.209-2.76 1.614-2.76 3.235v6.226c0 1.621 1.152 3.026 2.76 3.235.577.075 1.157.14 1.74.194V21l4.155-4.155" />
            </svg>
            <span>{post.comment_count}</span>
          </span>
        </div>
      </div>

      <!-- Comment section -->
      <div class="mt-6 bg-[var(--color-surface)] border border-[var(--color-border)] rounded-2xl p-5">
        <CommentSection postId={post.id} />
      </div>
    {/if}
  </div>

  <!-- Fixed bottom: TabBar -->
  <div class="fixed bottom-0 left-0 right-0 z-50">
    <TabBar />
  </div>
</div>
