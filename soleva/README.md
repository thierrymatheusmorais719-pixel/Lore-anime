# SOLEVA — e-commerce de sneakers premium

Loja completa de tênis em React + TypeScript + Vite: home editorial, catálogo com filtros reais,
página de produto, carrinho persistente, checkout em 3 etapas e busca inteligente.
Tudo em português do Brasil, com preços em reais.

> **Projeto de demonstração.** Marcas, produtos, estoques e avaliações são fictícios.
> Sem um provedor de pagamento configurado, o checkout roda em **modo demonstração**, claramente
> identificado: nenhuma cobrança é feita e nenhum pedido é marcado como pago.

## Como rodar

```bash
cd soleva
npm install
npm run dev        # http://localhost:5173
npm test           # testes de filtros, busca, carrinho, cupons e validações
npm run build      # gera dist/ (inclui 404.html para hospedagem estática)
```

Para publicar em um subcaminho (ex.: GitHub Pages): `SOLEVA_BASE=/repo/ npm run build`.

## Páginas

| Rota | Conteúdo |
|---|---|
| `/` | Hero com carrossel, lançamentos, categorias, mais vendidos, próximo drop com contagem regressiva, coleções, raros, promoção, destaques, marcas, newsletter |
| `/loja`, `/loja/:categoria` | Grid com busca, filtros (marca, categoria, tamanho, cor, preço, destaques, coleção), ordenação, carregamento progressivo, estados de carregamento/vazio/erro |
| `/raros` | Edições limitadas |
| `/produto/:slug` | Galeria com 5 vistas e zoom, numeração com estoque, guia de tamanhos, quantidade, frete por CEP, avaliações, semelhantes |
| `/carrinho` | Itens, troca de tamanho, quantidade, cupom, frete |
| `/checkout` | Identificação → entrega (ViaCEP) → pagamento |
| `/pedido/:id` | Confirmação com status honesto do pagamento |
| `/favoritos`, `/ajuda/:tema` | Favoritos e central de ajuda |

Dicas: `/loja?simular=erro` mostra o estado de erro; os filtros ficam na URL (links compartilháveis).
Cupons de teste: `BEMVINDO10`, `SOLEVA150` (acima de R$ 1.200), `FRETEGRATIS`.

## Busca

`Ctrl/⌘ + K` ou `/` abre a busca. Sugestões de marcas, categorias e modelos enquanto digita,
navegação por setas, histórico recente, termos em alta, produtos populares e estado sem resultados.
A busca ignora acentos.

## Arquitetura

```
src/
  data/          catálogo (marcas, categorias, cores, coleções, produtos) e avaliações
  lib/           regras puras e testadas: filtros, busca, preços/cupons, validação (CPF, CEP…)
  store/         carrinho (reducer) + contexto com persistência em localStorage e sync entre abas
  services/      catálogo, frete, CEP, pedidos, newsletter e pagamentos (interfaces trocáveis)
  components/    Header, Footer, CartDrawer, SearchOverlay, ProductCard, SneakerArt, UI
  pages/         uma página por rota
  styles/        tokens e CSS por camada (base, layout, componentes, páginas)
```

**Imagens.** Os produtos usam `SneakerArt`, um render vetorial parametrizado por silhueta e paleta
(lateral, medial, calcanhar, biqueira e solado). Para usar fotos reais, preencha `images` no produto:
`ProductMedia` passa a exibir as fotos automaticamente.

**Regras de compra.** Não é possível adicionar ao carrinho sem um tamanho com estoque; quantidade
limitada pelo estoque e a 5 por item; edições limitadas a 1 par por cliente; itens esgotados são
removidos do carrinho salvo ao recarregar.

## Pagamentos (Mercado Pago / Stripe)

O front nunca recebe dados de cartão nem chaves secretas. Defina em `.env` (veja `.env.example`):

```
VITE_PAYMENT_PROVIDER=mercadopago   # ou stripe
VITE_API_URL=https://sua-api.exemplo.com
```

Sem `VITE_API_URL`, o modo demonstração é usado sempre. Com ele, o front espera este contrato no seu back-end:

| Método | Rota | Resposta |
|---|---|---|
| `POST` | `/payments/{mercadopago\|stripe}/checkout` (corpo: pedido) | `{ "url": "…" }` — Checkout Pro / Stripe Checkout |
| `GET` | `/orders/{id}/status` | `{ "status": "awaiting_payment" \| "paid" \| "payment_failed" }` |

O back-end cria a preferência/sessão com a chave secreta, recalcula preços e cupons do lado do
servidor e só marca o pedido como `paid` ao receber o **webhook** do provedor. A página do pedido
consulta esse status; o retorno do navegador nunca confirma pagamento.

Frete: `services/shipping.ts` traz uma estimativa por região do CEP e a interface `ShippingProvider`
para plugar Correios, Melhor Envio etc.
