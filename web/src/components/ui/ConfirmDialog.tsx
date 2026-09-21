'use client';

import { Button } from '@/components/ui/Button';
import { Modal } from '@/components/ui/Modal';

export function ConfirmDialog({
  isOpen,
  title,
  body,
  confirmLabel = 'Confirm',
  cancelLabel = 'Cancel',
  isDanger = false,
  isPending = false,
  onConfirm,
  onCancel,
}: {
  isOpen: boolean;
  title: string;
  body: string;
  confirmLabel?: string;
  cancelLabel?: string;
  isDanger?: boolean;
  isPending?: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}) {
  return (
    <Modal
      title={title}
      isOpen={isOpen}
      onClose={onCancel}
      size="sm"
      footer={
        <div className="grid grid-cols-2 gap-3">
          <Button variant="secondary" onClick={onCancel}>
            {cancelLabel}
          </Button>
          <Button
            variant={isDanger ? 'danger' : 'primary'}
            isLoading={isPending}
            onClick={onConfirm}
          >
            {confirmLabel}
          </Button>
        </div>
      }
    >
      <p className="leading-relaxed text-pretty text-text-secondary">{body}</p>
    </Modal>
  );
}
