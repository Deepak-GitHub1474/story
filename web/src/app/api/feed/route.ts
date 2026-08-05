import { NextResponse } from 'next/server';
import { backendFetch } from '@/lib/server/session';
import type { TPage, TStory } from '@/lib/types';

export async function GET(request: Request) {
  const cursor = new URL(request.url).searchParams.get('cursor');
  const query = cursor ? `?limit=20&cursor=${encodeURIComponent(cursor)}` : '?limit=20';
  const result = await backendFetch<TPage<TStory>>(`/stories/feed${query}`);

  return NextResponse.json(result.ok ? result.value : null, {
    status: result.ok ? 200 : result.status || 500,
  });
}
