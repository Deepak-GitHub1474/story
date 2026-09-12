import type { Metadata } from 'next';
import { EmptyState } from '@/components/EmptyState';

export const metadata: Metadata = { title: 'Messages' };

export default function ChatsPage() {
  return (
    <EmptyState
      title="Pick a conversation"
      body="Choose someone on the left to read what you said, or start a new one."
    />
  );
}
