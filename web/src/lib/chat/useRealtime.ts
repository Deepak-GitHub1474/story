'use client';

import { useEffect, useRef } from 'react';

export type RealtimeEvent = {
  type: string;
  conversation_id?: string;
  message_id?: string;
  message?: unknown;
};

const BACKOFF = [1000, 2000, 4000, 8000, 15000, 30000];

export function useRealtime(onEvent: (event: RealtimeEvent) => void) {
  const handler = useRef(onEvent);
  handler.current = onEvent;

  useEffect(() => {
    let socket: WebSocket | null = null;
    let retry: ReturnType<typeof setTimeout> | null = null;
    let attempt = 0;
    let closed = false;

    async function connect() {
      if (closed) return;

      const response = await fetch('/api/chat/ticket', { method: 'POST' });
      if (!response.ok) return schedule();

      const { url } = (await response.json()) as { url: string | null };
      if (!url) return schedule();

      socket = new WebSocket(url);
      socket.onopen = () => {
        attempt = 0;
      };
      socket.onmessage = (raw) => {
        try {
          handler.current(JSON.parse(raw.data as string) as RealtimeEvent);
        } catch {}
      };
      socket.onclose = schedule;
      socket.onerror = () => socket?.close();
    }

    function schedule() {
      if (closed) return;
      const wait = BACKOFF[Math.min(attempt, BACKOFF.length - 1)];
      attempt += 1;
      retry = setTimeout(connect, wait);
    }

    void connect();

    return () => {
      closed = true;
      if (retry) clearTimeout(retry);
      socket?.close();
    };
  }, []);
}
