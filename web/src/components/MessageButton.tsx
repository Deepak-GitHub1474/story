'use client';

import { useRouter } from 'next/navigation';
import { useState, useTransition } from 'react';
import { Button } from '@/components/ui/Button';
import {
  newConversationKey,
  pairKey,
  wrapForPeer,
} from '@/lib/chat/crypto';
import { useChatIdentity } from '@/lib/chat/useIdentity';
import { peerIdentity, startConversation } from '@/lib/actions/chat';

export function MessageButton({
  username,
  viewerId,
}: {
  username: string;
  viewerId: string;
}) {
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();
  const identity = useChatIdentity(viewerId);

  return (
    <div className="flex flex-col gap-2">
      <Button
        variant="secondary"
        isFullWidth={false}
        isLoading={isPending}
        onClick={() =>
          startTransition(async () => {
            if (identity.status !== 'ready') {
              setError('This browser cannot do the encryption chat needs.');
              return;
            }

            const peer = await peerIdentity(username);
            if (!peer) {
              setError(
                'They have not signed in since chat was added, so their device has no key yet.',
              );
              return;
            }

            const cek = await newConversationKey();
            const pair = pairKey(viewerId, peer.user_id);

            const id = await startConversation({
              username,
              wrapped_cek_for_me: await wrapForPeer({
                cek,
                mine: identity.pair,
                theirPublicKey: peer.public_key,
                pair,
                recipientId: viewerId,
              }),
              wrapped_cek_for_them: await wrapForPeer({
                cek,
                mine: identity.pair,
                theirPublicKey: peer.public_key,
                pair,
                recipientId: peer.user_id,
              }),
              sender_public_key: identity.publicKey,
            });

            if (id) router.push(`/chats/${id}`);
            else setError('Could not open that chat.');
          })
        }
      >
        Message
      </Button>
      {error ? (
        <p role="alert" className="text-[length:var(--text-caption)] text-danger">
          {error}
        </p>
      ) : null}
    </div>
  );
}
