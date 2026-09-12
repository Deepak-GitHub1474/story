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
  primary:
    'bg-accent text-accent-text border border-accent hover:brightness-105 active:brightness-95',
  secondary:
    'bg-surface text-text-primary border border-border hover:border-border-strong hover:bg-surface-raised',
  ghost:
    'bg-transparent text-text-secondary border border-transparent hover:text-text-primary hover:bg-surface',
  danger: 'bg-transparent text-danger border border-danger/50 hover:border-danger hover:bg-danger/10',
};

const SIZES: Record<Size, string> = {
  md: 'h-[var(--size-control-height)] px-4 text-[length:var(--text-label)]',
  sm: 'h-[var(--size-control-height-sm)] px-3 text-[length:var(--text-caption)]',
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
        'inline-flex shrink-0 items-center justify-center gap-2 rounded-[length:var(--radius-md)]',
        'font-medium tracking-[var(--tracking-label)] whitespace-nowrap',
        'transition-[color,background-color,border-color,filter] duration-[var(--motion-fast)]',
        'focus-visible:ring-[1.5px] focus-visible:ring-accent focus-visible:ring-offset-2',
        'focus-visible:ring-offset-bg focus-visible:outline-none',
        'disabled:cursor-not-allowed disabled:opacity-45',
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
      className="size-3.5 animate-spin rounded-full border-[1.5px] border-current border-t-transparent opacity-70"
    />
  );
}
