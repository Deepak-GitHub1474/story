type ClassValue = string | false | null | undefined | 0;

export function cn(...parts: ClassValue[]): string {
  return parts.filter((part): part is string => typeof part === 'string' && part.length > 0).join(' ');
}
