import { NextResponse } from 'next/server';
import { API_BASE_URL } from '@/lib/config';
import { backendFetch } from '@/lib/server/session';

export async function POST() {
  const result = await backendFetch<{ ticket: string }>('/realtime/ticket', {
    method: 'POST',
  });
  if (!result.ok) return NextResponse.json({ url: null }, { status: 401 });

  const base = API_BASE_URL.replace(/^http/, 'ws');
  const ticket = encodeURIComponent(result.value.ticket);
  return NextResponse.json({ url: `${base}/ws?ticket=${ticket}` });
}
