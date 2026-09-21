import { cn } from '@/lib/cn';
import { ICONS, type TIconName } from '@/lib/icons';

export function Icon({
  name,
  size = 24,
  strokeWidth = 1.6,
  className,
}: {
  name: TIconName;
  size?: number;
  strokeWidth?: number;
  className?: string;
}) {
  return (
    <svg
      viewBox="0 0 24 24"
      aria-hidden="true"
      fill="none"
      stroke="currentColor"
      strokeWidth={strokeWidth}
      strokeLinecap="round"
      strokeLinejoin="round"
      style={{ width: size, height: size }}
      className={cn('shrink-0', className)}
    >
      <path d={ICONS[name]} />
    </svg>
  );
}
