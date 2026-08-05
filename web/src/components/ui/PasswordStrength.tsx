import { cn } from '@/lib/cn';

const LABELS = ['', 'Short', 'Okay', 'Strong', 'Very strong'];

function score(password: string): number {
  if (!password) return 0;
  let value = 0;
  if (password.length >= 10) value += 1;
  if (password.length >= 16) value += 1;
  if (/\s/.test(password.trim())) value += 1;
  if (/[^a-zA-Z0-9]/.test(password)) value += 1;
  return Math.min(value, 4);
}

export function PasswordStrength({ password }: { password: string }) {
  const value = score(password);
  const tone =
    value <= 1 ? 'bg-danger' : value === 2 ? 'bg-text-secondary' : 'bg-success';

  return (
    <div className="flex items-center gap-3">
      <div className="flex flex-1 gap-1">
        {[0, 1, 2, 3].map((index) => (
          <span
            key={index}
            className={cn(
              'h-1 flex-1 rounded-[length:var(--radius-pill)] transition-colors duration-150',
              index < value ? tone : 'bg-border',
            )}
          />
        ))}
      </div>
      <span className="w-20 text-[length:var(--text-caption)] text-text-muted">
        {LABELS[value]}
      </span>
    </div>
  );
}
