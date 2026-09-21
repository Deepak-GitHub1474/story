'use client';

import { useState, useTransition } from 'react';
import { Button } from '@/components/ui/Button';
import { Modal } from '@/components/ui/Modal';
import { polishText } from '@/lib/actions/ai';

const IDEAS = [
  'Fix the spelling and grammar',
  'Make it shorter',
  'Break it into paragraphs',
  'Keep it simple and plain',
];

export function PolishSheet({
  isOpen,
  text,
  onClose,
  onKeep,
}: {
  isOpen: boolean;
  text: string;
  onClose: () => void;
  onKeep: (polished: string) => void;
}) {
  const [instruction, setInstruction] = useState('');
  const [result, setResult] = useState<string | null>(null);
  const [before, setBefore] = useState<string | null>(null);
  const [rounds, setRounds] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [isBusy, startPolish] = useTransition();

  const canRun = !isBusy && instruction.trim().length > 0;

  function reset() {
    setInstruction('');
    setResult(null);
    setBefore(null);
    setRounds(0);
    setError(null);
  }

  function run() {
    startPolish(async () => {
      setError(null);
      const outcome = await polishText(result ?? text, instruction.trim());
      if (!outcome.text) {
        setError(outcome.error);
        return;
      }
      setBefore(result);
      setResult(outcome.text);
      setRounds((value) => value + 1);
      setInstruction('');
    });
  }

  return (
    <Modal size="lg"
      title="Another go at it"
      isOpen={isOpen}
      onClose={() => {
        reset();
        onClose();
      }}
      footer={
        <div className="flex flex-col gap-3">
          <div className="flex items-end gap-2 rounded-[length:var(--radius-lg)] border border-border px-4 py-2">
            <textarea
              value={instruction}
              onChange={(event) => setInstruction(event.target.value)}
              onKeyDown={(event) => {
                if (event.key === 'Enter' && !event.shiftKey && canRun) {
                  event.preventDefault();
                  run();
                }
              }}
              rows={1}
              maxLength={400}
              placeholder={
                result === null ? 'Say what should change' : 'Ask for one more change'
              }
              aria-label="What should change"
              className="max-h-24 flex-1 resize-none bg-transparent py-2 outline-none placeholder:text-text-muted"
            />
            <Button
              size="sm"
              isFullWidth={false}
              onClick={run}
              isLoading={isBusy}
              disabled={!canRun}
            >
              {result === null ? 'Show me' : 'Again'}
            </Button>
          </div>

          {result !== null ? (
            <div className="grid grid-cols-2 gap-3">
              <Button
                variant="secondary"
                onClick={() => {
                  reset();
                  onClose();
                }}
              >
                Keep mine
              </Button>
              <Button
                onClick={() => {
                  onKeep(result);
                  reset();
                  onClose();
                }}
              >
                Use this version
              </Button>
            </div>
          ) : null}
        </div>
      }
    >
      <p className="leading-relaxed text-text-secondary">
        Say what you want changed. It stays your story, in your words — nothing is added
        and nothing is softened.
      </p>

      <div className="mt-6 flex flex-wrap gap-2">
        {IDEAS.map((idea) => (
          <button
            key={idea}
            type="button"
            onClick={() => setInstruction(idea)}
            className="inline-flex h-9 items-center rounded-[length:var(--radius-pill)] bg-surface-raised px-4 text-[length:var(--text-label)] font-medium text-text-secondary transition-colors duration-[var(--motion-fast)] hover:text-text-primary"
          >
            {idea}
          </button>
        ))}
      </div>

      {error ? (
        <p role="alert" className="mt-4 text-[length:var(--text-label)] text-danger">
          {error}
        </p>
      ) : null}

      {result !== null ? (
        <div className="mt-6">
          <div className="flex items-center justify-between gap-4">
            <p className="text-[length:var(--text-caption)] text-text-muted">
              {rounds === 1
                ? 'One change in. Ask for another and it builds on this.'
                : `${rounds} changes in, each one on top of the last.`}
            </p>
            {before !== null ? (
              <button
                type="button"
                disabled={isBusy}
                onClick={() => {
                  setResult(before);
                  setBefore(null);
                  setRounds((value) => value - 1);
                }}
                className="shrink-0 text-[length:var(--text-caption)] text-accent hover:underline"
              >
                Undo that one
              </button>
            ) : null}
          </div>

          <div className="story-body mt-3 rounded-[length:var(--radius-md)] border border-border p-4 leading-relaxed whitespace-pre-wrap">
            {result}
          </div>
        </div>
      ) : null}
    </Modal>
  );
}
