'use client';

import { Modal } from '@/components/ui/Modal';
import { Icon } from '@/components/ui/Icon';
import type { TIconName } from '@/lib/icons';

const POINTS: { icon: TIconName; title: string; body: string }[] = [
  {
    icon: 'person',
    title: 'You stay anonymous',
    body: 'No real name, no phone number. Pick a username nobody can trace back to you.',
  },
  {
    icon: 'key',
    title: 'Your password cannot be recovered',
    body: 'Unless you add an email later, a forgotten password means a lost account. Nobody here can reset it for you.',
  },
  {
    icon: 'lock',
    title: 'Your vault opens with its passcode alone',
    body: 'We never receive it, so nobody here can read what you keep there. Forget it and those files are gone for good.',
  },
  {
    icon: 'eye',
    title: 'You choose who reads a story',
    body: 'Drafts and private stories stay with you. Anything public can be read and shared by anyone.',
  },
  {
    icon: 'trash',
    title: 'Deleting really deletes',
    body: 'Removing a story erases its pictures from storage too. It does not come back.',
  },
  {
    icon: 'activity',
    title: 'Be kind here',
    body: 'No harassment, no impersonation, nothing illegal. Accounts that do harm are removed.',
  },
];

export function TermsSheet({ isOpen, onClose }: { isOpen: boolean; onClose: () => void }) {
  return (
    <Modal title="Terms & Conditions" isOpen={isOpen} onClose={onClose}>
      <ul className="flex flex-col gap-6">
        {POINTS.map((point) => (
          <li key={point.title} className="flex items-start gap-4">
            <span className="grid size-9 shrink-0 place-items-center rounded-full bg-surface-raised text-accent">
              <Icon name={point.icon} size={18} />
            </span>
            <div className="min-w-0">
              <p className="text-[length:var(--text-body)]">{point.title}</p>
              <p className="mt-1 text-[length:var(--text-label)] leading-[1.5] text-text-muted">
                {point.body}
              </p>
            </div>
          </li>
        ))}
      </ul>
    </Modal>
  );
}
