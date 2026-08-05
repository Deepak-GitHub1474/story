import { cn } from '@/lib/cn';

type Variant = 'primary' | 'secondary' | 'ghost' | 'danger';
type Size = 'md' | 'sm';

type Props = React.ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: Variant;
  size?: Size;
  isLoading?: boolean;
  isFullWidth?: boolean;
};

const VARIANTS: Record<Variant, string> = {
  primary: 'bg-accent text-accent-text hover:opacity-90 border border-accent',
  secondary:
    'bg-surface-raised text-text-primary border border-border hover:border-text-muted',
  ghost: 'bg-transparent text-accent border border-transparent hover:bg-surface',
  danger: 'bg-transparent text-danger border border-danger hover:bg-danger/10',
};

const SIZES: Record<Size, string> = {
  md: 'h-[var(--size-control-height)] px-6 text-[length:var(--text-body)]',
  sm: 'h-10 px-4 text-[length:var(--text-label)]',
};

export function Button({
  variant = 'primary',
  size = 'md',
  isLoading = false,
  isFullWidth = true,
  disabled,
  className,
  children,
  ...rest
}: Props) {
  return (
    <button
      {...rest}
      disabled={disabled || isLoading}
      className={cn(
        'inline-flex items-center justify-center gap-2 rounded-[length:var(--radius-md)]',
        'font-semibold transition-[opacity,border-color,background-color] duration-150',
        'focus-visible:ring-2 focus-visible:ring-accent focus-visible:ring-offset-2',
        'focus-visible:ring-offset-bg focus-visible:outline-none',
        'disabled:cursor-not-allowed disabled:opacity-55',
        VARIANTS[variant],
        SIZES[size],
        isFullWidth && 'w-full',
        className,
      )}
    >
      {isLoading ? <Spinner /> : children}
    </button>
  );
}

function Spinner() {
  return (
    <span
      aria-hidden="true"
      className="size-[var(--size-icon-md)] animate-spin rounded-full border-2 border-current border-t-transparent"
    />
  );
}
