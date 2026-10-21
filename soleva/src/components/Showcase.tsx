import { useEffect, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { getProductBySlug } from '../data/catalog';
import { formatPrice } from '../lib/format';
import { Icon } from './Icon';
import { ProductMedia } from './ui';

const STEPS = [
  {
    kicker: '1998 · Flórida',
    title: 'Pôr do sol no degradê',
    body: 'Sean McDowell desenhou o Air Max Plus olhando o céu da Flórida ao entardecer. O degradê do cabedal vem daí.',
    x: '62%',
    y: '48%',
  },
  {
    kicker: 'Overlays em TPU',
    title: 'Palmeiras ao vento',
    body: 'As “garras” que sobem pela lateral imitam palmeiras balançando. Além do visual, elas seguram o pé no lugar.',
    x: '73%',
    y: '30%',
  },
  {
    kicker: 'Meio do pé',
    title: 'Cauda de baleia',
    body: 'A ponte de TPU no arco tem o formato de uma cauda de baleia e dá estabilidade em cada passada.',
    x: '67%',
    y: '83%',
  },
  {
    kicker: 'Tuned Air',
    title: 'Ar onde você pisa',
    body: 'Unidades de ar ajustadas no calcanhar e no antepé. Foi o primeiro Nike com o sistema Tuned Air.',
    x: '89%',
    y: '76%',
  },
];

/**
 * Seção fixa durante a rolagem: o progresso (0–1) é exposto como `--p` e a
 * etapa atual como `data-step`, e o CSS anima o tênis e as anotações.
 */
export function Showcase() {
  const ref = useRef<HTMLElement>(null);
  const [step, setStep] = useState(0);
  const product = getProductBySlug('nike-air-max-plus-black-white');

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    let raf = 0;
    const update = () => {
      raf = 0;
      const r = el.getBoundingClientRect();
      const total = r.height - window.innerHeight;
      const p = Math.min(1, Math.max(0, -r.top / total));
      el.style.setProperty('--p', p.toFixed(4));
      setStep(Math.min(STEPS.length - 1, Math.floor(p * STEPS.length * 0.999)));
    };
    const onScroll = () => {
      if (!raf) raf = requestAnimationFrame(update);
    };
    update();
    window.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', onScroll);
    return () => {
      window.removeEventListener('scroll', onScroll);
      window.removeEventListener('resize', onScroll);
      cancelAnimationFrame(raf);
    };
  }, []);

  if (!product) return null;

  return (
    <section className="showcase dark grain" ref={ref} data-step={step} aria-label="A história do Air Max Plus">
      <div className="showcase-sticky">
        <div className="showcase-word display" aria-hidden="true">
          Tuned Air · Tuned Air ·
        </div>
        <div className="showcase-head container">
          <span className="eyebrow">Anatomia de um ícone</span>
          <h2 className="display h2">
            Air Max Plus
            <span className="accent"> “TN”</span>
          </h2>
        </div>

        <div className="showcase-stage">
          <div className="showcase-glow" />
          <div className="showcase-shoe">
            <ProductMedia product={product} sizes="(max-width: 900px) 100vw, 70vw" />
            {/* Os pontos ficam dentro do tênis para acompanhar a rotação. */}
            {STEPS.map((s, i) => (
              <span
                key={s.title}
                className={`showcase-dot ${i === step ? 'on' : ''} ${i < step ? 'past' : ''}`}
                style={{ left: s.x, top: s.y }}
                aria-hidden="true"
              />
            ))}
          </div>
        </div>

        <div className="showcase-panel container">
          <ol className="showcase-steps" aria-label="Etapas">
            {STEPS.map((s, i) => (
              <li key={s.title} className={i === step ? 'on' : i < step ? 'past' : ''}>
                <span className="mono">0{i + 1}</span>
              </li>
            ))}
          </ol>
          <div className="showcase-copy" aria-live="polite">
            {STEPS.map((s, i) => (
              <article key={s.title} className={i === step ? 'on' : ''} aria-hidden={i !== step}>
                <span className="mono accent">{s.kicker}</span>
                <h3 className="display">{s.title}</h3>
                <p>{s.body}</p>
              </article>
            ))}
          </div>
          <Link to={`/produto/${product.slug}`} className="btn btn-primary showcase-cta">
            Comprar — {formatPrice(product.price)} <Icon name="arrowRight" size={18} className="arrow" />
          </Link>
        </div>

        <div className="showcase-progress" aria-hidden="true">
          <span />
        </div>
      </div>
    </section>
  );
}
