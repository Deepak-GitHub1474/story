'use client';

import { useState, useTransition } from 'react';
import { Button } from '@/components/ui/Button';
import { Field } from '@/components/ui/Field';
import { Modal } from '@/components/ui/Modal';
import { draftStory } from '@/lib/actions/ai';

export function WriteWithAI({
  isOpen,
  onClose,
  onWritten,
}: {
  isOpen: boolean;
  onClose: () => void;
  onWritten: (written: { title: string; body: string }) => void;
}) {
  const [subject, setSubject] = useState('');
  const [brief, setBrief] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isWriting, startWriting] = useTransition();

  const canWrite = subject.trim().length > 0 && brief.trim().length > 0;

  function write() {
    startWriting(async () => {
      setError(null);
      const result = await draftStory(subject.trim(), brief.trim());
      if (!result.written) {
        setError(result.error ?? 'That did not work.');
        return;
      }
      onWritten(result.written);
      setSubject('');
      setBrief('');
      onClose();
    });
  }

  return (
    <Modal size="md"
      title="Write it with AI"
      isOpen={isOpen}
      onClose={onClose}
      footer={
        <Button onClick={write} isLoading={isWriting} disabled={!canWrite || isWriting}>
          Write it
        </Button>
      }
    >
      <div className="flex flex-col gap-6">
        <Field
          label="What is it about"
          value={subject}
          onChange={(event) => setSubject(event.target.value)}
          maxLength={120}
          placeholder="The day I left home"
        />

        <div className="flex flex-col gap-2">
          <label
            htmlFor="ai-brief"
            className="text-[length:var(--text-label)] font-medium text-text-secondary"
          >
            What you want said
          </label>
          <textarea
            id="ai-brief"
            value={brief}
            onChange={(event) => setBrief(event.target.value)}
            rows={7}
            maxLength={4000}
            placeholder="Everything you remember, in any order. The messier the better."
            className="resize-y rounded-[length:var(--radius-md)] border border-border bg-surface px-4 py-3 leading-relaxed outline-none focus:border-accent"
          />
        </div>

        {error ? (
          <p role="alert" className="text-[length:var(--text-label)] text-danger">
            {error}
          </p>
        ) : null}
      </div>
    </Modal>
  );
}
