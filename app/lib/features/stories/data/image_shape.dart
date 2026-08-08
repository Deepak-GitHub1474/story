const portraitBound = 0.8;
const landscapeBound = 1.91;

double postRatioFor(int width, int height) {
  if (width <= 0 || height <= 0) return portraitBound;

  final natural = width / height;
  if (natural < portraitBound) return portraitBound;
  if (natural > landscapeBound) return landscapeBound;
  return natural;
}

bool isCropped(int width, int height) {
  if (width <= 0 || height <= 0) return false;

  final natural = width / height;
  return natural < portraitBound || natural > landscapeBound;
}
