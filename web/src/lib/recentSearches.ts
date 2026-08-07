const KEY = 'story.recent_searches';
const STAMP_KEY = 'story.recent_searches_at';
const LIMIT = 8;
const LIFETIME_MS = 24 * 60 * 60 * 1000;

function read(): string[] {
  try {
    const stamp = Number(localStorage.getItem(STAMP_KEY) ?? 0);
    if (stamp && Date.now() - stamp > LIFETIME_MS) return [];
    return JSON.parse(localStorage.getItem(KEY) ?? '[]') as string[];
  } catch {
    return [];
  }
}

export function recentSearches() {
  return read();
}

export function rememberSearch(term: string) {
  const trimmed = term.trim();
  if (!trimmed) return read();

  const next = [trimmed, ...read().filter((item) => item !== trimmed)].slice(0, LIMIT);
  localStorage.setItem(KEY, JSON.stringify(next));
  localStorage.setItem(STAMP_KEY, String(Date.now()));
  return next;
}

export function forgetSearch(term: string) {
  const next = read().filter((item) => item !== term);
  localStorage.setItem(KEY, JSON.stringify(next));
  return next;
}

export function clearSearches() {
  localStorage.removeItem(KEY);
  localStorage.removeItem(STAMP_KEY);
  return [];
}
