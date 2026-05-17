<script lang="ts">
  import { onMount } from 'svelte';
  import { client } from '$lib/api';
  import { authState } from '$lib/stores/auth.svelte';

  let { postId }: { postId: string } = $props();

  type CommentData = {
    id: string;
    post_id: string;
    user_id: string;
    body: string;
    display_name: string;
    email: string;
    created_at: string;
  };

  let comments = $state<CommentData[]>([]);
  let newBody = $state('');
  let loading = $state(true);
  let posting = $state(false);
  let error = $state<string | null>(null);

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

  function avatarLetter(name: string, email: string): string {
    return (name || email || '?')[0].toUpperCase();
  }

  async function loadComments() {
    loading = true;
    error = null;
    try {
      comments = (await client.posts.comments.list(postId)) as CommentData[];
    } catch (e: any) {
      error = e.message;
    }
    loading = false;
  }

  async function addComment() {
    const text = newBody.trim();
    if (!text || posting) return;
    posting = true;
    try {
      const result = await client.posts.comments.create(postId, text);
      const currentUser = authState.user;
      const newComment: CommentData = {
        id: result.id,
        post_id: result.post_id,
        user_id: result.user_id,
        body: text,
        display_name: currentUser?.email?.split('@')[0] || 'Anonymous',
        email: currentUser?.email || '',
        created_at: result.created_at || new Date().toISOString()
      };
      comments = [...comments, newComment];
      newBody = '';
    } catch (e: any) {
      error = e.message;
    }
    posting = false;
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      addComment();
    }
  }

  onMount(loadComments);
</script>

<div class="space-y-4">
  <h3 class="text-sm font-semibold text-[var(--color-text)]">
    Comments ({comments.length})
  </h3>

  {#if loading}
    <div class="animate-pulse space-y-3">
      {#each [1, 2] as _, i (i)}
        <div class="flex gap-3">
          <div class="w-8 h-8 rounded-full bg-[var(--color-surface-input)] shrink-0"></div>
          <div class="flex-1 space-y-1.5">
            <div class="h-3 w-20 bg-[var(--color-surface-input)] rounded"></div>
            <div class="h-3 w-40 bg-[var(--color-surface-input)] rounded"></div>
          </div>
        </div>
      {/each}
    </div>
  {:else if error}
    <p class="text-red-500 text-xs">{error}</p>
  {:else if comments.length === 0}
    <p class="text-sm text-[var(--color-text-muted)]">No comments yet.</p>
  {:else}
    <div class="space-y-3 max-h-80 overflow-y-auto pr-1">
      {#each comments as comment (comment.id)}
        <div class="flex gap-3">
          <!-- Avatar -->
          <div class="w-8 h-8 rounded-full bg-[var(--color-surface-muted)] flex items-center justify-center shrink-0 text-xs font-semibold text-[var(--color-text)] border border-[var(--color-border)]">
            {avatarLetter(comment.display_name, comment.email)}
          </div>
          <!-- Content -->
          <div class="flex-1 min-w-0">
            <div class="flex items-baseline gap-2">
              <span class="text-sm font-medium text-[var(--color-text)] truncate">
                {comment.display_name || comment.email}
              </span>
              <span class="text-xs text-[var(--color-text-muted)] shrink-0">
                {timeAgo(comment.created_at)}
              </span>
            </div>
            <p class="text-sm text-[var(--color-text-muted)] mt-0.5 whitespace-pre-wrap break-words">
              {comment.body}
            </p>
          </div>
        </div>
      {/each}
    </div>
  {/if}

  <!-- Comment input -->
  <div class="flex gap-2 items-end pt-2 border-t border-[var(--color-border)]">
    <textarea
      bind:value={newBody}
      onkeydown={handleKeydown}
      placeholder="Write a comment..."
      rows={1}
      class="flex-1 px-3 py-2 bg-[var(--color-surface)] border border-[var(--color-border)] rounded-xl text-sm text-[var(--color-text)] placeholder:text-[var(--color-text-muted)] focus:outline-none focus:border-black transition-colors resize-none min-h-[36px]"
    ></textarea>
    <button
      onclick={addComment}
      disabled={!newBody.trim() || posting}
      class="px-4 py-2 bg-black text-white rounded-xl text-sm font-medium hover:bg-[#333] transition-colors disabled:opacity-50 whitespace-nowrap"
    >
      {posting ? '...' : 'Send'}
    </button>
  </div>
</div>
