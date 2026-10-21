import { useEffect, useRef, useState } from 'react';

/**
 * Balão que segue o mouse sobre elementos com `data-cursor` (ex.: "Ver").
 * Só aparece em telas com mouse; o cursor do sistema continua visível.
 */
export function CursorBubble() {
  const ref = useRef<HTMLDivElement>(null);
  const [label, setLabel] = useState<string | null>(null);
  const [enabled] = useState(
    () => typeof window !== 'undefined' && window.matchMedia('(hover: hover) and (pointer: fine)').matches && !window.matchMedia('(prefers-reduced-motion: reduce)').matches,
  );

  useEffect(() => {
    if (!enabled) return;
    const pos = { x: 0, y: 0, tx: 0, ty: 0 };
    let raf = 0;
    const loop = () => {
      pos.x += (pos.tx - pos.x) * 0.22;
      pos.y += (pos.ty - pos.y) * 0.22;
      if (ref.current) ref.current.style.transform = `translate3d(${pos.x}px, ${pos.y}px, 0)`;
      raf = requestAnimationFrame(loop);
    };
    const onMove = (e: PointerEvent) => {
      pos.tx = e.clientX;
      pos.ty = e.clientY;
      const el = (e.target as Element | null)?.closest?.('[data-cursor]');
      setLabel(el ? el.getAttribute('data-cursor') : null);
    };
    const onLeave = () => setLabel(null);
    window.addEventListener('pointermove', onMove, { passive: true });
    document.addEventListener('pointerleave', onLeave);
    raf = requestAnimationFrame(loop);
    return () => {
      window.removeEventListener('pointermove', onMove);
      document.removeEventListener('pointerleave', onLeave);
      cancelAnimationFrame(raf);
    };
  }, [enabled]);

  if (!enabled) return null;
  return (
    <div className="cursor-bubble" ref={ref} aria-hidden="true">
      <span className={label ? 'on' : ''}>{label}</span>
    </div>
  );
}
