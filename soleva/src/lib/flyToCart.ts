/**
 * Anima uma cópia da imagem do produto voando até o ícone da sacola.
 * Retorna a duração (ms) para quem quiser encadear outra ação.
 */
export function flyToCart(source: Element | null | undefined): number {
  const target = document.querySelector('[data-cart-icon]');
  if (!source || !target || window.matchMedia('(prefers-reduced-motion: reduce)').matches) return 0;

  const from = source.getBoundingClientRect();
  const to = target.getBoundingClientRect();
  if (!from.width) return 0;

  const ghost = source.cloneNode(true) as HTMLElement;
  Object.assign(ghost.style, {
    position: 'fixed',
    left: `${from.left}px`,
    top: `${from.top}px`,
    width: `${from.width}px`,
    height: `${from.height}px`,
    margin: '0',
    zIndex: '200',
    pointerEvents: 'none',
    objectFit: 'contain',
    transformOrigin: 'center',
    opacity: '1',
  });
  document.body.appendChild(ghost);

  const dx = to.left + to.width / 2 - (from.left + from.width / 2);
  const dy = to.top + to.height / 2 - (from.top + from.height / 2);
  const scale = Math.max(0.06, 28 / from.width);
  const duration = 750;

  ghost
    .animate(
      [
        { transform: 'translate(0, 0) scale(1) rotate(0deg)', opacity: 1 },
        { transform: `translate(${dx * 0.45}px, ${dy * 0.45 - 120}px) scale(${(1 + scale) / 2.2}) rotate(-18deg)`, opacity: 1, offset: 0.45 },
        { transform: `translate(${dx}px, ${dy}px) scale(${scale}) rotate(-30deg)`, opacity: 0.4 },
      ],
      { duration, easing: 'cubic-bezier(.55,0,.25,1)', fill: 'forwards' },
    )
    .finished.finally(() => {
      ghost.remove();
      target.classList.remove('bump');
      void (target as HTMLElement).offsetWidth;
      target.classList.add('bump');
    });
  return duration;
}
