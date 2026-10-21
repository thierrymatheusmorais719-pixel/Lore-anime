import { useEffect, useMemo, useRef, useState, type FormEvent } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { getBrand, getProduct } from '../data/catalog';
import { Icon } from '../components/Icon';
import { CouponField, MiniLines, TotalsTable } from '../components/OrderSummary';
import { EmptyState } from '../components/ui';
import { useDocumentTitle } from '../hooks';
import { formatPrice } from '../lib/format';
import { computeTotals } from '../lib/pricing';
import { readJSON, writeJSON } from '../lib/storage';
import {
  UF,
  isValidCEP,
  maskCEP,
  maskCPF,
  maskPhone,
  validateAddress,
  validateCustomer,
  type Errors,
} from '../lib/validation';
import { lookupCep } from '../services/cep';
import { newOrderId, saveOrder } from '../services/orders';
import { getPaymentProvider } from '../services/payments';
import { shippingProvider } from '../services/shipping';
import { useShop } from '../store/ShopProvider';
import type { Address, Customer, Order, ShippingOption } from '../types';

type Step = 1 | 2 | 3;
const DRAFT_KEY = 'soleva:checkout-draft';

const emptyCustomer: Customer = { name: '', email: '', cpf: '', phone: '' };
const emptyAddress: Address = { cep: '', street: '', number: '', complement: '', district: '', city: '', state: '' };

export function Checkout() {
  useDocumentTitle('Checkout');
  const { items, coupon, clearCart } = useShop();
  const navigate = useNavigate();
  const provider = useMemo(getPaymentProvider, []);

  const draft = readJSON<{ customer: Customer; address: Address }>(DRAFT_KEY, { customer: emptyCustomer, address: emptyAddress });
  const [step, setStep] = useState<Step>(1);
  const [customer, setCustomer] = useState<Customer>(draft.customer);
  const [address, setAddress] = useState<Address>(draft.address);
  const [cErrors, setCErrors] = useState<Errors<Customer>>({});
  const [aErrors, setAErrors] = useState<Errors<Address>>({});
  const [options, setOptions] = useState<ShippingOption[]>([]);
  const [shipping, setShipping] = useState<ShippingOption | null>(null);
  const [quoting, setQuoting] = useState(false);
  const [cepState, setCepState] = useState<'idle' | 'loading' | 'found' | 'notfound'>('idle');
  const [method, setMethod] = useState<'pix' | 'card' | 'boleto'>('pix');
  const [submitting, setSubmitting] = useState(false);
  const [payError, setPayError] = useState<string | null>(null);
  const [accepted, setAccepted] = useState(false);
  const [acceptError, setAcceptError] = useState(false);
  const numberRef = useRef<HTMLInputElement>(null);

  // Rascunho local para não perder dados ao recarregar (sem CPF por privacidade).
  useEffect(() => writeJSON(DRAFT_KEY, { customer: { ...customer, cpf: '' }, address }), [customer, address]);

  const totals = computeTotals(items, getProduct, coupon, shipping?.price ?? null, shipping?.id === 'padrao');

  // CEP completo: autopreenche o endereço e cota o frete.
  const cepDigits = address.cep.replace(/\D/g, '');
  useEffect(() => {
    if (cepDigits.length !== 8) {
      setOptions([]);
      setShipping(null);
      setCepState('idle');
      return;
    }
    const ctrl = new AbortController();
    setCepState('loading');
    lookupCep(cepDigits, ctrl.signal).then((r) => {
      if (ctrl.signal.aborted) return;
      if (r) {
        setAddress((a) => ({ ...a, street: r.street || a.street, district: r.district || a.district, city: r.city || a.city, state: r.state || a.state }));
        setCepState('found');
        window.setTimeout(() => numberRef.current?.focus(), 50);
      } else setCepState('notfound');
    });
    setQuoting(true);
    shippingProvider
      .quote(cepDigits, items)
      .then((opts) => {
        if (ctrl.signal.aborted) return;
        setOptions(opts);
        setShipping((cur) => opts.find((o) => o.id === cur?.id) ?? opts[0]);
      })
      .finally(() => !ctrl.signal.aborted && setQuoting(false));
    return () => ctrl.abort();
  }, [cepDigits, items]);

  if (items.length === 0) {
    return (
      <div className="container page-pad">
        <EmptyState
          icon="bag"
          title="Nada para finalizar"
          body="Seu carrinho está vazio."
          action={
            <Link to="/loja" className="btn btn-primary">
              Ir para a loja
            </Link>
          }
        />
      </div>
    );
  }

  const submitCustomer = (e: FormEvent) => {
    e.preventDefault();
    const err = validateCustomer(customer);
    setCErrors(err);
    if (Object.keys(err).length === 0) setStep(2);
    else focusFirstError();
  };

  const submitAddress = (e: FormEvent) => {
    e.preventDefault();
    const err = validateAddress(address);
    setAErrors(err);
    if (Object.keys(err).length === 0 && shipping) setStep(3);
    else focusFirstError();
  };

  const placeOrder = async () => {
    if (!accepted) return setAcceptError(true);
    if (!shipping) return setStep(2);
    setSubmitting(true);
    setPayError(null);
    const order: Order = {
      id: newOrderId(),
      createdAt: new Date().toISOString(),
      status: provider.isDemo ? 'demo' : 'awaiting_payment',
      provider: provider.id,
      customer,
      address,
      shipping,
      lines: items.map((it) => {
        const p = getProduct(it.productId)!;
        return { productId: p.id, name: `${p.name} “${p.model}”`, brand: getBrand(p.brandId)?.name ?? '', size: it.size, quantity: it.quantity, unitPrice: p.price };
      }),
      coupon: coupon?.code,
      subtotal: totals.subtotal,
      discount: totals.discount,
      shippingCost: totals.shipping ?? 0,
      total: totals.total,
    };
    try {
      const result = await provider.start(order);
      saveOrder(order);
      if (result.kind === 'redirect') {
        // O carrinho é mantido até o back-end confirmar o pagamento.
        window.location.assign(result.url);
        return;
      }
      clearCart();
      navigate(`/pedido/${order.id}`, { replace: true });
    } catch (e) {
      setPayError((e as Error).message);
      setSubmitting(false);
    }
  };

  const setC = (k: keyof Customer, v: string) => setCustomer((c) => ({ ...c, [k]: v }));
  const setA = (k: keyof Address, v: string) => setAddress((a) => ({ ...a, [k]: v }));

  return (
    <div className="checkout">
      <div className="container">
        <header className="checkout-head">
          <h1 className="display h2">Checkout</h1>
          <span className="mono muted">
            <Icon name="lock" size={14} /> Ambiente seguro
          </span>
        </header>

        {provider.isDemo && (
          <div className="demo-banner" role="note">
            <Icon name="info" size={18} />
            <p>
              <strong>Modo demonstração.</strong> Nenhum provedor de pagamento está configurado: nenhuma cobrança será
              feita e o pedido não será enviado. Configure Mercado Pago ou Stripe no back-end para vender de verdade.
            </p>
          </div>
        )}

        <ol className="steps" aria-label="Etapas">
          {['Identificação', 'Entrega', 'Pagamento'].map((l, i) => (
            <li key={l} className={step === i + 1 ? 'current' : step > i + 1 ? 'done' : ''}>
              <span>{step > i + 1 ? <Icon name="check" size={14} /> : i + 1}</span> {l}
            </li>
          ))}
        </ol>

        <div className="checkout-grid">
          <div className="checkout-main">
            {/* 1. Identificação */}
            <section className={`co-step ${step === 1 ? 'active' : ''}`}>
              <header>
                <h2>1. Identificação</h2>
                {step > 1 && (
                  <button className="link-btn" onClick={() => setStep(1)}>
                    Editar
                  </button>
                )}
              </header>
              {step === 1 ? (
                <form onSubmit={submitCustomer} noValidate className="form-grid">
                  <Field id="name" label="Nome completo" error={cErrors.name} className="span-2">
                    <input id="name" className="input" autoComplete="name" value={customer.name} onChange={(e) => setC('name', e.target.value)} aria-invalid={Boolean(cErrors.name)} />
                  </Field>
                  <Field id="email" label="E-mail" error={cErrors.email} className="span-2">
                    <input id="email" type="email" className="input" autoComplete="email" value={customer.email} onChange={(e) => setC('email', e.target.value)} aria-invalid={Boolean(cErrors.email)} />
                  </Field>
                  <Field id="cpf" label="CPF" error={cErrors.cpf} hint="Necessário para a nota fiscal.">
                    <input id="cpf" className="input" inputMode="numeric" value={customer.cpf} onChange={(e) => setC('cpf', maskCPF(e.target.value))} aria-invalid={Boolean(cErrors.cpf)} placeholder="000.000.000-00" />
                  </Field>
                  <Field id="phone" label="Celular" error={cErrors.phone}>
                    <input id="phone" className="input" inputMode="tel" autoComplete="tel" value={customer.phone} onChange={(e) => setC('phone', maskPhone(e.target.value))} aria-invalid={Boolean(cErrors.phone)} placeholder="(11) 91234-5678" />
                  </Field>
                  <button className="btn btn-primary span-2">
                    Continuar para entrega <Icon name="arrowRight" size={18} className="arrow" />
                  </button>
                </form>
              ) : (
                <p className="co-summary">
                  {customer.name} · {customer.email} · {customer.phone}
                </p>
              )}
            </section>

            {/* 2. Entrega */}
            <section className={`co-step ${step === 2 ? 'active' : ''}`}>
              <header>
                <h2>2. Entrega</h2>
                {step > 2 && (
                  <button className="link-btn" onClick={() => setStep(2)}>
                    Editar
                  </button>
                )}
              </header>
              {step === 2 && (
                <form onSubmit={submitAddress} noValidate className="form-grid">
                  <Field
                    id="cep"
                    label="CEP"
                    error={aErrors.cep}
                    hint={cepState === 'loading' ? 'Buscando endereço…' : cepState === 'notfound' ? 'CEP não encontrado — preencha manualmente.' : undefined}
                  >
                    <input id="cep" className="input" inputMode="numeric" autoComplete="postal-code" value={address.cep} onChange={(e) => setA('cep', maskCEP(e.target.value))} aria-invalid={Boolean(aErrors.cep)} placeholder="00000-000" />
                  </Field>
                  <div className="field cep-help">
                    <a href="https://buscacepinter.correios.com.br/" target="_blank" rel="noreferrer" className="link-btn">
                      Não sei meu CEP
                    </a>
                  </div>
                  <Field id="street" label="Rua / Avenida" error={aErrors.street} className="span-2">
                    <input id="street" className="input" autoComplete="address-line1" value={address.street} onChange={(e) => setA('street', e.target.value)} aria-invalid={Boolean(aErrors.street)} />
                  </Field>
                  <Field id="number" label="Número" error={aErrors.number}>
                    <input id="number" ref={numberRef} className="input" value={address.number} onChange={(e) => setA('number', e.target.value)} aria-invalid={Boolean(aErrors.number)} />
                  </Field>
                  <Field id="complement" label="Complemento (opcional)">
                    <input id="complement" className="input" autoComplete="address-line2" value={address.complement} onChange={(e) => setA('complement', e.target.value)} />
                  </Field>
                  <Field id="district" label="Bairro" error={aErrors.district}>
                    <input id="district" className="input" value={address.district} onChange={(e) => setA('district', e.target.value)} aria-invalid={Boolean(aErrors.district)} />
                  </Field>
                  <Field id="city" label="Cidade" error={aErrors.city}>
                    <input id="city" className="input" autoComplete="address-level2" value={address.city} onChange={(e) => setA('city', e.target.value)} aria-invalid={Boolean(aErrors.city)} />
                  </Field>
                  <Field id="state" label="Estado" error={aErrors.state}>
                    <select id="state" className="select" value={address.state} onChange={(e) => setA('state', e.target.value)} aria-invalid={Boolean(aErrors.state)}>
                      <option value="">Selecione</option>
                      {UF.map((u) => (
                        <option key={u}>{u}</option>
                      ))}
                    </select>
                  </Field>

                  <fieldset className="ship-choice span-2">
                    <legend>Forma de entrega</legend>
                    {!isValidCEP(address.cep) && <p className="muted small">Informe o CEP para ver as opções.</p>}
                    {quoting && <div className="skeleton" style={{ height: 64 }} />}
                    {!quoting &&
                      options.map((o) => (
                        <label key={o.id} className={`radio-card ${shipping?.id === o.id ? 'on' : ''}`}>
                          <input type="radio" name="ship" checked={shipping?.id === o.id} onChange={() => setShipping(o)} />
                          <div>
                            <strong>{o.label}</strong>
                            <span className="muted small">
                              {o.days[0]}–{o.days[1]} dias úteis após a confirmação do pagamento
                            </span>
                          </div>
                          <span>{totals.freeShipping && o.id === 'padrao' ? <span className="free">Grátis</span> : formatPrice(o.price)}</span>
                        </label>
                      ))}
                    {options.length > 0 && <p className="field-hint">Valores estimados por região. Integração com transportadora preparada em <code>services/shipping.ts</code>.</p>}
                  </fieldset>

                  <button className="btn btn-primary span-2" disabled={!shipping || quoting}>
                    Continuar para pagamento <Icon name="arrowRight" size={18} className="arrow" />
                  </button>
                </form>
              )}
              {step > 2 && shipping && (
                <p className="co-summary">
                  {address.street}, {address.number}
                  {address.complement && ` — ${address.complement}`} · {address.district}, {address.city}/{address.state} · CEP {address.cep}
                  <br />
                  {shipping.label}: {shipping.days[0]}–{shipping.days[1]} dias úteis
                </p>
              )}
            </section>

            {/* 3. Pagamento */}
            <section className={`co-step ${step === 3 ? 'active' : ''}`}>
              <header>
                <h2>3. Pagamento</h2>
              </header>
              {step === 3 && (
                <div className="pay">
                  <div className="pay-methods" role="radiogroup" aria-label="Forma de pagamento">
                    {(
                      [
                        ['pix', 'pix', 'Pix', 'Aprovação imediata'],
                        ['card', 'card', 'Cartão de crédito', 'Até 10x sem juros'],
                        ['boleto', 'package', 'Boleto', 'Compensação em até 3 dias úteis'],
                      ] as const
                    ).map(([id, icon, label, hint]) => (
                      <label key={id} className={`radio-card ${method === id ? 'on' : ''}`}>
                        <input type="radio" name="method" checked={method === id} onChange={() => setMethod(id)} />
                        <Icon name={icon} size={20} />
                        <div>
                          <strong>{label}</strong>
                          <span className="muted small">{hint}</span>
                        </div>
                      </label>
                    ))}
                  </div>

                  <div className="pay-note">
                    <Icon name="shield" size={18} />
                    {provider.isDemo ? (
                      <p>
                        Em produção, os dados de pagamento são digitados no ambiente seguro do provedor (Mercado Pago ou
                        Stripe) — a SOLEVA nunca recebe o número do seu cartão. Neste modo de demonstração nenhum dado de
                        pagamento é solicitado.
                      </p>
                    ) : (
                      <p>
                        Você será redirecionado ao ambiente seguro do <strong>{provider.label}</strong> para concluir o
                        pagamento. O pedido só é confirmado após a aprovação do provedor.
                      </p>
                    )}
                  </div>

                  <label className="checkbox">
                    <input
                      type="checkbox"
                      checked={accepted}
                      onChange={(e) => {
                        setAccepted(e.target.checked);
                        setAcceptError(false);
                      }}
                    />
                    <span>
                      Li e aceito os <Link to="/ajuda/termos" target="_blank">termos de uso</Link> e a <Link to="/ajuda/trocas" target="_blank">política de trocas</Link>.
                    </span>
                  </label>
                  {acceptError && <p className="field-error">Aceite os termos para continuar.</p>}
                  {payError && (
                    <p className="field-error" role="alert">
                      <Icon name="alert" size={14} /> {payError}
                    </p>
                  )}

                  <button className="btn btn-primary btn-block" onClick={placeOrder} disabled={submitting}>
                    {submitting ? (
                      <span className="spinner" />
                    ) : provider.isDemo ? (
                      <>Registrar pedido de demonstração · {formatPrice(totals.total)}</>
                    ) : (
                      <>
                        <Icon name="lock" size={16} /> Pagar {formatPrice(totals.total)} com {provider.label}
                      </>
                    )}
                  </button>
                </div>
              )}
            </section>
          </div>

          <aside className="summary checkout-summary">
            <h2 className="display h3">Seu pedido</h2>
            <MiniLines />
            <CouponField />
            <TotalsTable totals={totals} shippingLabel={<span className="muted">Informe o CEP</span>} />
            <Link to="/carrinho" className="link-btn">
              <Icon name="arrowLeft" size={14} /> Voltar ao carrinho
            </Link>
          </aside>
        </div>
      </div>
    </div>
  );
}

function Field({ id, label, error, hint, className = '', children }: { id: string; label: string; error?: string; hint?: string; className?: string; children: React.ReactNode }) {
  return (
    <div className={`field ${className}`}>
      <label htmlFor={id}>{label}</label>
      {children}
      {error ? (
        <p className="field-error" id={`${id}-error`}>
          <Icon name="alert" size={13} /> {error}
        </p>
      ) : (
        hint && <p className="field-hint">{hint}</p>
      )}
    </div>
  );
}

function focusFirstError() {
  window.setTimeout(() => (document.querySelector('[aria-invalid="true"]') as HTMLElement | null)?.focus(), 30);
}
