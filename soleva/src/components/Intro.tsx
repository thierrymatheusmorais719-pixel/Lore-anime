import { createContext, useContext, useEffect, useState, type ReactNode } from 'react';

const KEY = 'soleva:intro-visto';
const IntroCtx = createContext(true);

/** `true` quando a abertura já terminou (ou não vai ser exibida). */
export const useIntroDone = () => useContext(IntroCtx);

function shouldPlay() {
  try {
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return false;
    return sessionStorage.getItem(KEY) !== '1';
  } catch {
    return false;
  }
}

/** Abertura da marca na primeira visita da sessão: letras sobem e uma cortina revela o site. */
export function IntroProvider({ children }: { children: ReactNode }) {
  const [phase, setPhase] = useState<'play' | 'leave' | 'done'>(() => (shouldPlay() ? 'play' : 'done'));

  useEffect(() => {
    if (phase === 'done') return;
    try {
      sessionStorage.setItem(KEY, '1');
    } catch {
      /* sem armazenamento: a abertura apenas toca de novo */
    }
    const t1 = window.setTimeout(() => setPhase('leave'), 1500);
    const t2 = window.setTimeout(() => setPhase('done'), 2300);
    return () => {
      window.clearTimeout(t1);
      window.clearTimeout(t2);
    };
  }, [phase === 'done']);

  return (
    <IntroCtx.Provider value={phase !== 'play'}>
      {children}
      {phase !== 'done' && (
        <div className={`intro ${phase === 'leave' ? 'leave' : ''}`} aria-hidden="true" onClick={() => setPhase('leave')}>
          <div className="intro-word">
            {'SOLEVA'.split('').map((ch, i) => (
              <span key={i} className="intro-letter" style={{ ['--i' as string]: i }}>
                <span>{ch}</span>
              </span>
            ))}
          </div>
          <div className="intro-bar">
            <span />
          </div>
          <span className="intro-tag mono">Sneakers premium · São Paulo</span>
        </div>
      )}
    </IntroCtx.Provider>
  );
}
