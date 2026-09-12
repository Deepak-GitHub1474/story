type HairStyle =
  | 'bobFringe'
  | 'longPart'
  | 'bunTop'
  | 'longFringe'
  | 'bunLow'
  | 'quiff'
  | 'crop'
  | 'sidePart'
  | 'curls'
  | 'afro';

type FaceStyle = {
  skin: string;
  shadow: string;
  hair: string;
  backdrop: string;
  style: HairStyle;
};

const FACES: FaceStyle[] = [
  { skin: '#F6D9C6', shadow: '#E2BBA4', hair: '#3A2A22', backdrop: '#FFE1EC', style: 'bobFringe' },
  { skin: '#EBBC97', shadow: '#D29B74', hair: '#C9762F', backdrop: '#FFE9D2', style: 'longPart' },
  { skin: '#C98D62', shadow: '#AB7049', hair: '#1E1712', backdrop: '#DDEBFF', style: 'bunTop' },
  { skin: '#9A5F35', shadow: '#7C4826', hair: '#241813', backdrop: '#E4E0FF', style: 'longFringe' },
  { skin: '#5E3720', shadow: '#442513', hair: '#15100D', backdrop: '#D8F2E4', style: 'bunLow' },
  { skin: '#F6D9C6', shadow: '#E2BBA4', hair: '#B98A4C', backdrop: '#D9F0FF', style: 'quiff' },
  { skin: '#EBBC97', shadow: '#D29B74', hair: '#2C2119', backdrop: '#E7E4DC', style: 'crop' },
  { skin: '#C98D62', shadow: '#AB7049', hair: '#19120E', backdrop: '#FFE3D5', style: 'sidePart' },
  { skin: '#9A5F35', shadow: '#7C4826', hair: '#120D0A', backdrop: '#DCE8FF', style: 'curls' },
  { skin: '#5E3720', shadow: '#442513', hair: '#0F0B09', backdrop: '#FFE7BF', style: 'afro' },
];

const LONG_HAIR = new Set<HairStyle>([
  'bobFringe',
  'longPart',
  'bunTop',
  'longFringe',
  'bunLow',
]);

const CROP =
  'M0.245 0.455 Q0.245 0.175 0.5 0.175 Q0.755 0.175 0.755 0.455 Q0.7 0.335 0.5 0.335 Q0.3 0.335 0.245 0.455 Z';

const BOB =
  'M0.235 0.52 L0.235 0.38 Q0.5 0.145 0.765 0.38 L0.765 0.52 Q0.735 0.36 0.5 0.365 Q0.265 0.36 0.235 0.52 Z';

const PART =
  'M0.25 0.47 L0.25 0.4 Q0.5 0.155 0.75 0.4 L0.75 0.47 Q0.7 0.33 0.545 0.335 Q0.36 0.345 0.25 0.47 Z';

const QUIFF = 'M0.34 0.255 Q0.44 0.095 0.7 0.185 Q0.54 0.195 0.47 0.3 Z';

const SIDE_PART = 'M0.615 0.205 Q0.665 0.265 0.675 0.345 Q0.625 0.275 0.575 0.235 Z';

const CURL_SPOTS = [
  [0.305, 0.325],
  [0.375, 0.245],
  [0.465, 0.212],
  [0.56, 0.228],
  [0.645, 0.29],
  [0.695, 0.365],
];

function faceIndexFor(seed: string): number {
  if (!seed) return 0;
  let hash = 7;
  for (let i = 0; i < seed.length; i += 1) {
    hash = (hash * 31 + seed.charCodeAt(i)) & 0x7fffffff;
  }
  return hash % FACES.length;
}

export function Avatar({
  seed,
  size = 40,
}: {
  seed?: string | null;
  size?: number;
}) {
  const index = faceIndexFor(seed ?? '');
  const face = FACES[index];
  const isLong = LONG_HAIR.has(face.style);
  const hasCrop =
    face.style === 'crop' ||
    face.style === 'quiff' ||
    face.style === 'sidePart' ||
    face.style === 'curls' ||
    face.style === 'afro';
  const bunY = face.style === 'bunTop' ? 0.145 : 0.215;
  const clip = `story-avatar-${index}`;

  return (
    <svg
      viewBox="0 0 1 1"
      aria-hidden="true"
      className="inline-block shrink-0 rounded-full"
      style={{ width: size, height: size }}
    >
      <defs>
        <clipPath id={clip}>
          <circle cx="0.5" cy="0.5" r="0.5" />
        </clipPath>
      </defs>

      <circle cx="0.5" cy="0.5" r="0.5" fill={face.backdrop} />

      <g clipPath={`url(#${clip})`}>
        <rect x="0.295" y="0.835" width="0.41" height="0.28" rx="0.18" fill={face.shadow} />

        {isLong ? (
          <rect x="0.175" y="0.16" width="0.65" height="0.72" rx="0.32" fill={face.hair} />
        ) : null}

        {face.style === 'afro' ? (
          <circle cx="0.5" cy="0.375" r="0.295" fill={face.hair} />
        ) : null}

        {face.style === 'bunTop' || face.style === 'bunLow' ? (
          <>
            <circle cx="0.335" cy={bunY} r="0.072" fill={face.hair} />
            <circle cx="0.665" cy={bunY} r="0.072" fill={face.hair} />
          </>
        ) : null}

        <circle cx="0.245" cy="0.545" r="0.052" fill={face.skin} />
        <circle cx="0.755" cy="0.545" r="0.052" fill={face.skin} />
        <rect x="0.255" y="0.245" width="0.49" height="0.52" rx="0.245" fill={face.skin} />

        {face.style === 'bobFringe' || face.style === 'longFringe' ? (
          <path d={BOB} fill={face.hair} />
        ) : null}

        {face.style === 'longPart' || face.style === 'bunTop' || face.style === 'bunLow' ? (
          <path d={PART} fill={face.hair} />
        ) : null}

        {hasCrop ? <path d={CROP} fill={face.hair} /> : null}
        {face.style === 'quiff' ? <path d={QUIFF} fill={face.hair} /> : null}
        {face.style === 'sidePart' ? <path d={SIDE_PART} fill={face.skin} /> : null}

        {face.style === 'curls'
          ? CURL_SPOTS.map(([cx, cy]) => (
              <circle key={`${cx}-${cy}`} cx={cx} cy={cy} r="0.062" fill={face.hair} />
            ))
          : null}

        <ellipse cx="0.3375" cy="0.596" rx="0.0525" ry="0.031" fill="#F08A9B" opacity="0.42" />
        <ellipse cx="0.6625" cy="0.596" rx="0.0525" ry="0.031" fill="#F08A9B" opacity="0.42" />

        <ellipse cx="0.397" cy="0.529" rx="0.049" ry="0.059" fill="#3A2B26" />
        <ellipse cx="0.603" cy="0.529" rx="0.049" ry="0.059" fill="#3A2B26" />

        <circle cx="0.42" cy="0.502" r="0.021" fill="#FFFFFF" />
        <circle cx="0.626" cy="0.502" r="0.021" fill="#FFFFFF" />
        <circle cx="0.376" cy="0.556" r="0.011" fill="#FFFFFF" />
        <circle cx="0.582" cy="0.556" r="0.011" fill="#FFFFFF" />

        <path
          d="M0.437 0.655 Q0.5 0.712 0.563 0.655"
          fill="none"
          stroke="#6E4B3F"
          strokeWidth="0.03"
          strokeLinecap="round"
        />
      </g>
    </svg>
  );
}
