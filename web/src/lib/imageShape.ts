export const PORTRAIT_BOUND = 0.8;
export const LANDSCAPE_BOUND = 1.91;

export function postRatioFor(width: number, height: number): number {
  if (width <= 0 || height <= 0) return PORTRAIT_BOUND;

  const natural = width / height;
  if (natural < PORTRAIT_BOUND) return PORTRAIT_BOUND;
  if (natural > LANDSCAPE_BOUND) return LANDSCAPE_BOUND;
  return natural;
}

export function isCropped(width: number, height: number): boolean {
  if (width <= 0 || height <= 0) return false;

  const natural = width / height;
  return natural < PORTRAIT_BOUND || natural > LANDSCAPE_BOUND;
}
