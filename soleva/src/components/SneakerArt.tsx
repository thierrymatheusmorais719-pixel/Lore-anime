import { memo, useId } from 'react';
import type { Palette, Silhouette } from '../types';

/**
 * Render vetorial de produto. Cada silhueta é desenhada em um viewBox 600×360
 * com a biqueira para a direita; as vistas reutilizam o mesmo desenho
 * (espelhado ou recortado) para montar a galeria sem depender de fotos.
 */

export type SneakerView = 'lateral' | 'medial' | 'heel' | 'toe' | 'sole';

export const VIEW_LABELS: Record<SneakerView, string> = {
  lateral: 'Lateral',
  medial: 'Medial',
  heel: 'Detalhe do calcanhar',
  toe: 'Detalhe da biqueira',
  sole: 'Solado',
};

interface Shape {
  outsole: string;
  midsole: string;
  upper: string;
  heel: string;
  toe: string;
  eyestay: string;
  tongue: string;
  collar: string;
  mark: string;
  tab: string;
  wing?: string;
  midsoleLine?: string;
  foxing?: string;
  lace: { from: [number, number]; to: [number, number]; count: number };
  stitches: string[];
  perf?: { x: number; y: number; cols: number; rows: number };
}

const SHAPES: Record<Silhouette, Shape> = {
  court: {
    outsole: 'M44 282 C44 296 52 304 66 304 L548 304 C561 304 569 295 567 282 Z',
    midsole: 'M38 244 C38 262 40 276 44 288 L566 288 C575 281 577 265 567 252 C540 251 140 249 38 244 Z',
    midsoleLine: 'M48 270 L560 271',
    upper:
      'M40 248 C33 200 37 158 56 128 C84 120 118 128 150 144 C168 124 186 104 206 98 C222 94 234 104 238 124 L420 196 C478 204 538 218 562 240 C568 246 568 252 566 254 Z',
    heel: 'M40 248 C33 200 37 160 54 132 C84 150 106 196 114 250 Z',
    toe: 'M452 202 C510 210 548 226 562 242 L566 254 C530 253 480 252 440 252 C434 232 438 214 452 202 Z',
    eyestay: 'M231 116 C290 140 360 168 426 194 L414 214 C350 190 282 164 220 146 Z',
    tongue: 'M196 108 C200 84 224 72 242 82 L248 128 L230 120 Z',
    collar: 'M56 128 C84 120 118 128 150 144 C120 138 88 134 60 140 Z',
    mark: 'M126 226 C200 206 262 244 336 220 C378 206 412 200 446 206 L444 220 C410 214 380 220 340 234 C262 260 196 222 126 240 Z',
    tab: 'M42 150 L58 140 L66 178 L46 186 Z',
    lace: { from: [244, 128], to: [410, 194], count: 6 },
    stitches: ['M118 250 C112 200 92 160 60 138', 'M446 252 C442 228 446 214 456 206', 'M226 152 C290 172 352 194 410 218'],
    perf: { x: 486, y: 222, cols: 5, rows: 2 },
  },
  high: {
    outsole: 'M44 282 C44 296 52 304 66 304 L548 304 C561 304 569 295 567 282 Z',
    midsole: 'M38 244 C38 262 40 276 44 288 L566 288 C575 281 577 265 567 252 C540 251 140 249 38 244 Z',
    midsoleLine: 'M48 270 L560 271',
    upper:
      'M40 248 C30 190 33 110 52 62 C90 52 140 50 176 60 C186 46 204 34 222 34 C236 34 242 48 242 66 L420 196 C478 204 538 218 562 240 C568 246 568 252 566 254 Z',
    heel: 'M40 248 C30 190 33 124 48 74 C86 112 112 184 118 250 Z',
    wing: 'M50 64 C90 54 140 52 176 62 C190 70 200 84 206 98 C160 94 104 104 44 126 Z',
    toe: 'M452 202 C510 210 548 226 562 242 L566 254 C530 253 480 252 440 252 C434 232 438 214 452 202 Z',
    eyestay: 'M236 60 C300 104 364 150 428 192 L414 212 C352 172 290 128 224 92 Z',
    tongue: 'M206 46 C212 22 236 12 254 22 L256 70 L238 64 Z',
    collar: 'M52 62 C90 52 140 50 176 60 C148 70 96 76 54 86 Z',
    mark: 'M140 222 C208 200 270 238 340 214 C380 200 414 194 446 200 L444 214 C412 208 382 214 344 228 C270 254 206 216 140 236 Z',
    tab: 'M40 96 L54 86 L64 128 L46 136 Z',
    lace: { from: [250, 74], to: [412, 192], count: 7 },
    stitches: ['M122 250 C116 190 92 124 54 84', 'M446 252 C442 228 446 214 456 206', 'M214 250 C210 200 218 152 236 116'],
    perf: { x: 488, y: 222, cols: 5, rows: 2 },
  },
  runner: {
    outsole: 'M52 284 C46 298 58 306 74 306 L518 306 C546 304 566 292 574 274 L562 268 C540 278 300 290 62 280 Z',
    midsole:
      'M36 222 C28 248 36 276 54 290 C200 294 420 292 548 280 C568 276 578 264 576 250 C560 248 520 248 470 248 C330 240 180 232 36 222 Z',
    midsoleLine: 'M60 262 C150 246 200 280 300 266 C380 256 430 274 520 262',
    upper:
      'M40 226 C34 188 42 150 62 128 C90 124 122 132 150 142 C166 124 186 108 206 104 C222 102 232 112 236 126 L410 188 C470 200 532 216 562 236 C574 244 574 250 570 252 C430 246 240 236 40 226 Z',
    heel: 'M40 226 C36 194 42 160 58 136 C78 160 92 196 96 230 Z',
    toe: 'M470 206 C522 214 552 228 566 240 C574 246 572 252 568 252 C530 251 490 250 456 249 C452 232 458 216 470 206 Z',
    eyestay: 'M230 118 C290 140 350 162 418 186 L406 206 C346 186 286 166 220 142 Z',
    tongue: 'M196 112 C198 88 220 76 238 84 L246 130 L228 122 Z',
    collar: 'M62 128 C90 124 122 132 150 142 C122 138 92 136 66 142 Z',
    mark: 'M118 214 C190 196 250 230 322 208 C366 194 404 188 440 194 L438 207 C404 202 372 208 326 222 C250 246 188 210 118 228 Z',
    tab: 'M60 132 C48 114 54 98 72 98 L78 126 Z',
    lace: { from: [240, 130], to: [402, 188], count: 6 },
    stitches: ['M100 230 C96 196 82 162 62 140', 'M460 249 C456 232 462 218 474 210'],
  },
  skate: {
    outsole: 'M42 288 C42 298 48 304 60 304 L552 304 C564 304 572 297 572 288 Z',
    midsole: 'M38 248 C36 266 38 282 44 292 L568 292 C576 284 578 268 570 258 C548 254 140 252 38 248 Z',
    foxing: 'M40 270 L572 272 L572 278 L40 276 Z',
    upper:
      'M40 252 C34 210 38 162 56 134 C86 128 118 132 150 146 C168 128 188 112 206 108 C222 106 232 114 236 128 L400 200 C460 206 530 222 560 246 C568 254 568 258 566 260 Z',
    heel: 'M40 252 C34 210 38 168 54 138 C86 160 104 204 108 252 Z',
    toe: 'M420 206 C486 208 540 222 562 246 L566 260 C520 257 460 256 410 255 C404 236 408 218 420 206 Z',
    eyestay: 'M230 120 C286 144 340 168 404 196 L392 214 C334 190 280 168 220 148 Z',
    tongue: 'M194 114 C198 90 222 80 240 88 L246 132 L228 124 Z',
    collar: 'M56 134 C86 128 118 132 150 146 C120 142 88 140 60 146 Z',
    mark: 'M150 232 C212 214 262 246 324 226 C360 214 388 210 412 214 L410 226 C386 222 362 228 330 240 C264 264 210 228 150 246 Z',
    tab: 'M42 160 L56 152 L62 184 L46 190 Z',
    lace: { from: [242, 132], to: [392, 198], count: 5 },
    stitches: ['M112 254 C108 206 88 166 60 146', 'M414 255 C408 236 412 220 424 210', 'M412 208 C462 210 520 224 552 246'],
  },
};

const TREAD: Record<Silhouette, 'herringbone' | 'pivot' | 'waffle' | 'lugs'> = {
  court: 'pivot',
  high: 'herringbone',
  runner: 'lugs',
  skate: 'waffle',
};

const VIEWBOX: Record<SneakerView, string> = {
  lateral: '0 0 600 360',
  medial: '0 0 600 360',
  heel: '0 50 320 192',
  toe: '300 110 300 180',
  sole: '0 0 600 360',
};

interface Props {
  palette: Palette;
  silhouette: Silhouette;
  view?: SneakerView;
  brandMark?: string;
  className?: string;
  title?: string;
  shadow?: boolean;
}

function SneakerArtBase({ palette: c, silhouette, view = 'lateral', brandMark = 'S', className, title, shadow = true }: Props) {
  const uid = useId().replace(/:/g, '');
  const s = SHAPES[silhouette];

  if (view === 'sole') return <Sole id={uid} palette={c} silhouette={silhouette} brand={brandMark} className={className} title={title} />;

  const id = (n: string) => `${uid}-${n}`;
  const { from, to, count } = s.lace;
  const laces = Array.from({ length: count }, (_, i) => {
    const t = i / (count - 1);
    return [from[0] + (to[0] - from[0]) * t, from[1] + (to[1] - from[1]) * t] as const;
  });

  const mirror = view === 'medial';

  return (
    <svg
      viewBox={VIEWBOX[view]}
      className={className}
      role="img"
      aria-label={title}
      xmlns="http://www.w3.org/2000/svg"
      preserveAspectRatio="xMidYMid meet"
      style={{ overflow: 'hidden' }}
    >
      <defs>
        <linearGradient id={id('shade')} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#fff" stopOpacity=".22" />
          <stop offset=".45" stopColor="#fff" stopOpacity="0" />
          <stop offset="1" stopColor="#000" stopOpacity=".22" />
        </linearGradient>
        <linearGradient id={id('side')} x1="0" y1="0" x2="1" y2="0">
          <stop offset="0" stopColor="#000" stopOpacity=".16" />
          <stop offset=".3" stopColor="#000" stopOpacity="0" />
          <stop offset=".8" stopColor="#fff" stopOpacity=".06" />
          <stop offset="1" stopColor="#000" stopOpacity=".14" />
        </linearGradient>
        <linearGradient id={id('sole')} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#fff" stopOpacity=".18" />
          <stop offset="1" stopColor="#000" stopOpacity=".16" />
        </linearGradient>
        <radialGradient id={id('ground')} cx=".5" cy=".5" r=".5">
          <stop offset="0" stopColor="#000" stopOpacity=".38" />
          <stop offset=".6" stopColor="#000" stopOpacity=".12" />
          <stop offset="1" stopColor="#000" stopOpacity="0" />
        </radialGradient>
        <pattern id={id('mesh')} width="7" height="7" patternUnits="userSpaceOnUse" patternTransform="rotate(30)">
          <circle cx="3.5" cy="3.5" r="1.1" fill="#000" fillOpacity=".16" />
        </pattern>
        <clipPath id={id('clip-upper')}>
          <path d={s.upper} />
        </clipPath>
      </defs>

      {shadow && <ellipse cx="305" cy="310" rx="290" ry="18" fill={`url(#${id('ground')})`} />}

      <g transform={mirror ? 'translate(600 0) scale(-1 1)' : undefined}>
        {/* Lingueta atrás do cabedal */}
        <path d={s.tongue} fill={c.upper} />
        <path d={s.tongue} fill={`url(#${id('shade')})`} />
        <rect x={s.lace.from[0] - 24} y={s.lace.from[1] - 40} width="20" height="13" rx="2" fill={c.lining} transform={`rotate(-12 ${s.lace.from[0] - 14} ${s.lace.from[1] - 34})`} />

        {/* Cabedal */}
        <path d={s.upper} fill={c.upper} />
        {silhouette === 'runner' && <path d={s.upper} fill={`url(#${id('mesh')})`} />}
        <g clipPath={`url(#${id('clip-upper')})`}>
          <path d={s.collar} fill={c.lining} />
          {s.wing && <path d={s.wing} fill={c.overlay} />}
          <path d={s.heel} fill={c.overlay} />
          <path d={s.toe} fill={c.overlay} />
          <path d={s.eyestay} fill={c.overlay} />
          {!mirror && <path d={s.mark} fill={c.accent} />}
          {s.stitches.map((d) => (
            <path key={d} d={d} fill="none" stroke="#000" strokeOpacity=".28" strokeWidth="1.3" strokeDasharray="4 4" />
          ))}
          {s.perf &&
            Array.from({ length: s.perf.cols * s.perf.rows }, (_, i) => (
              <circle
                key={i}
                cx={s.perf!.x + (i % s.perf!.cols) * 12 + (Math.floor(i / s.perf!.cols) % 2) * 6}
                cy={s.perf!.y + Math.floor(i / s.perf!.cols) * 10}
                r="1.8"
                fill="#000"
                fillOpacity=".3"
              />
            ))}
          <path d={s.upper} fill={`url(#${id('shade')})`} />
          <path d={s.upper} fill={`url(#${id('side')})`} />
        </g>

        {/* Ilhoses e cadarço */}
        {laces.map(([x, y], i) => (
          <g key={i}>
            <circle cx={x - 6} cy={y + 12} r="3.4" fill="#000" fillOpacity=".35" />
            <circle cx={x - 6} cy={y + 12} r="1.6" fill={c.lining} />
            <path
              d={`M${x - 18} ${y + 4} Q${x - 4} ${y - 10} ${x + 14} ${y - 4}`}
              fill="none"
              stroke={c.laces}
              strokeWidth="6"
              strokeLinecap="round"
            />
            <path
              d={`M${x - 18} ${y + 4} Q${x - 4} ${y - 10} ${x + 14} ${y - 4}`}
              fill="none"
              stroke="#000"
              strokeOpacity=".18"
              strokeWidth="1"
              strokeLinecap="round"
              transform="translate(0 2.4)"
            />
          </g>
        ))}

        {/* Puxador */}
        <path d={s.tab} fill={c.accent} />
        <path d={s.tab} fill={`url(#${id('shade')})`} />

        {/* Entressola e solado */}
        <path d={s.midsole} fill={c.midsole} />
        {s.foxing && <path d={s.foxing} fill={c.overlay} opacity=".9" />}
        {s.midsoleLine && (
          <path
            d={s.midsoleLine}
            fill="none"
            stroke={silhouette === 'runner' ? c.accent : '#000'}
            strokeOpacity={silhouette === 'runner' ? 0.9 : 0.22}
            strokeWidth={silhouette === 'runner' ? 3 : 1.2}
            strokeDasharray={silhouette === 'runner' ? undefined : '3 4'}
          />
        )}
        <path d={s.midsole} fill={`url(#${id('sole')})`} />
        <path d={s.outsole} fill={c.outsole} />
        <path d={s.outsole} fill="#000" fillOpacity=".12" />

        {/* Assinatura no calcanhar */}
        <text
          x="76"
          y={silhouette === 'high' ? 238 : 236}
          fontFamily="Archivo, sans-serif"
          fontWeight="800"
          fontSize="9"
          letterSpacing="1.5"
          fill="#000"
          fillOpacity=".38"
          transform={mirror ? 'translate(152 0) scale(-1 1)' : undefined}
        >
          {brandMark}
        </text>
      </g>
    </svg>
  );
}

function Sole({ id, palette: c, silhouette, brand, className, title }: { id: string; palette: Palette; silhouette: Silhouette; brand: string; className?: string; title?: string }) {
  const outline =
    'M58 180 C58 132 104 112 166 116 C254 122 326 100 418 94 C502 88 558 122 562 180 C566 238 508 272 426 266 C336 260 258 238 166 244 C104 248 58 228 58 180 Z';
  const tread = TREAD[silhouette];
  return (
    <svg viewBox="0 0 600 360" className={className} role="img" aria-label={title} xmlns="http://www.w3.org/2000/svg">
      <defs>
        <clipPath id={`${id}-sole`}>
          <path d={outline} />
        </clipPath>
        <pattern id={`${id}-hb`} width="16" height="16" patternUnits="userSpaceOnUse">
          <path d="M0 8 L8 0 M8 16 L16 8 M0 8 L8 16 M8 0 L16 8" stroke="#000" strokeOpacity=".28" strokeWidth="2.2" />
        </pattern>
        <pattern id={`${id}-wf`} width="14" height="14" patternUnits="userSpaceOnUse">
          <rect x="2" y="2" width="10" height="10" rx="1.5" fill="#000" fillOpacity=".16" />
        </pattern>
        <pattern id={`${id}-lg`} width="26" height="20" patternUnits="userSpaceOnUse">
          <path d="M3 4 L13 2 L22 6 L14 16 L4 14 Z" fill="#000" fillOpacity=".18" />
        </pattern>
        <pattern id={`${id}-pv`} width="18" height="10" patternUnits="userSpaceOnUse">
          <path d="M0 5 H18" stroke="#000" strokeOpacity=".22" strokeWidth="2" />
        </pattern>
        <radialGradient id={`${id}-g`} cx=".5" cy=".4" r=".7">
          <stop offset="0" stopColor="#fff" stopOpacity=".18" />
          <stop offset="1" stopColor="#000" stopOpacity=".2" />
        </radialGradient>
      </defs>
      <ellipse cx="310" cy="190" rx="270" ry="110" fill="#000" opacity=".08" />
      <path d={outline} fill={c.midsole} transform="translate(0 4)" />
      <path d={outline} fill={c.outsole} />
      <g clipPath={`url(#${id}-sole)`}>
        <rect
          width="600"
          height="360"
          fill={`url(#${id}-${tread === 'herringbone' ? 'hb' : tread === 'waffle' ? 'wf' : tread === 'lugs' ? 'lg' : 'pv'})`}
        />
        {(tread === 'pivot' || tread === 'herringbone') && (
          <>
            <circle cx="440" cy="178" r="44" fill={c.outsole} />
            {[38, 28, 18, 8].map((r) => (
              <circle key={r} cx="440" cy="178" r={r} fill="none" stroke="#000" strokeOpacity=".25" strokeWidth="2" />
            ))}
            <circle cx="150" cy="180" r="30" fill={c.outsole} />
            {[24, 14].map((r) => (
              <circle key={r} cx="150" cy="180" r={r} fill="none" stroke="#000" strokeOpacity=".25" strokeWidth="2" />
            ))}
          </>
        )}
        {tread === 'lugs' && <path d="M250 120 C280 170 280 200 250 250" stroke={c.accent} strokeWidth="18" fill="none" opacity=".85" />}
        <rect x="270" y="168" width="96" height="24" rx="12" fill={c.outsole} />
        <text x="318" y="185" textAnchor="middle" fontFamily="Archivo, sans-serif" fontWeight="800" fontSize="12" letterSpacing="3" fill="#000" fillOpacity=".45">
          {brand}
        </text>
        <path d={outline} fill={`url(#${id}-g)`} />
      </g>
      <path d={outline} fill="none" stroke="#000" strokeOpacity=".2" strokeWidth="2" />
    </svg>
  );
}

export const SneakerArt = memo(SneakerArtBase);
