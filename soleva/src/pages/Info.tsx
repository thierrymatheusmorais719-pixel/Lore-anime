import { Link, NavLink, useParams } from 'react-router-dom';
import { SizeGuide } from '../components/SizeGuide';
import { EmptyState } from '../components/ui';
import { useDocumentTitle } from '../hooks';

const PAGES: Record<string, { title: string; body: React.ReactNode }> = {
  entregas: {
    title: 'Entregas e prazos',
    body: (
      <>
        <p>Enviamos para todo o Brasil. Pedidos com pagamento aprovado até 14h (dias úteis) são despachados no mesmo dia.</p>
        <h3>Prazos estimados</h3>
        <ul>
          <li>Grande São Paulo: 1 a 3 dias úteis</li>
          <li>Sul, Sudeste e Centro-Oeste: 2 a 8 dias úteis</li>
          <li>Norte e Nordeste: 4 a 11 dias úteis</li>
        </ul>
        <p>O frete é grátis na entrega padrão para compras acima de R$ 799. Você recebe o código de rastreio por e-mail assim que o pedido é enviado.</p>
      </>
    ),
  },
  trocas: {
    title: 'Trocas e devoluções',
    body: (
      <>
        <p>Você tem até 30 dias corridos após o recebimento para solicitar troca ou devolução — além dos 7 dias de arrependimento garantidos pelo Código de Defesa do Consumidor.</p>
        <ul>
          <li>O produto deve estar sem sinais de uso, com etiquetas e na caixa original.</li>
          <li>A primeira troca de cada pedido é gratuita.</li>
          <li>Na devolução, o reembolso é feito na mesma forma de pagamento em até 10 dias úteis após o recebimento.</li>
          <li>Edições limitadas podem ser devolvidas, mas não trocadas por outra numeração.</li>
        </ul>
      </>
    ),
  },
  tamanhos: { title: 'Guia de tamanhos', body: <SizeGuide /> },
  pagamentos: {
    title: 'Pagamentos',
    body: (
      <>
        <p>Aceitamos Pix, cartão de crédito em até 10x sem juros (parcela mínima de R$ 50) e boleto bancário.</p>
        <p>O pagamento é processado em ambiente seguro do provedor (Mercado Pago ou Stripe). A SOLEVA não armazena dados de cartão.</p>
        <p className="muted">Esta loja está em modo demonstração: nenhum pagamento é processado.</p>
      </>
    ),
  },
  autenticidade: {
    title: 'Autenticidade',
    body: (
      <>
        <p>Trabalhamos apenas com marcas e distribuidores oficiais. Cada par de edição limitada passa por uma inspeção em 12 pontos — costuras, materiais, etiquetas, caixa e numeração — antes de ser enviado.</p>
        <p>Se houver qualquer dúvida sobre a autenticidade de um produto comprado aqui, devolvemos 100% do valor.</p>
      </>
    ),
  },
  contato: {
    title: 'Fale conosco',
    body: (
      <>
        <p>Atendimento de segunda a sexta, das 9h às 18h, e aos sábados, das 9h às 13h.</p>
        <p>E-mail: <a href="mailto:atendimento@soleva.example">atendimento@soleva.example</a></p>
        <p className="muted">Canais fictícios — projeto de demonstração.</p>
      </>
    ),
  },
  privacidade: {
    title: 'Privacidade',
    body: (
      <>
        <p>Neste modo de demonstração, carrinho, favoritos, histórico de busca e pedidos ficam salvos apenas no armazenamento local do seu navegador. Nenhum dado é enviado a servidores da SOLEVA.</p>
        <p>O preenchimento automático de endereço consulta o serviço público ViaCEP apenas com o CEP digitado.</p>
      </>
    ),
  },
  termos: {
    title: 'Termos de uso',
    body: <p>SOLEVA é um projeto de demonstração. Marcas, produtos, preços, avaliações e estoques são fictícios. Nenhuma compra realizada aqui gera cobrança ou envio.</p>,
  },
};

export function Info() {
  const { topic = '' } = useParams();
  const page = PAGES[topic];
  useDocumentTitle(page?.title ?? 'Ajuda');
  if (!page) {
    return (
      <div className="container page-pad">
        <EmptyState icon="info" title="Página não encontrada" action={<Link to="/ajuda/entregas" className="btn btn-primary">Central de ajuda</Link>} />
      </div>
    );
  }
  return (
    <div className="container page-pad info">
      <aside className="info-nav">
        <span className="eyebrow">Ajuda</span>
        {Object.entries(PAGES).map(([k, v]) => (
          <NavLink key={k} to={`/ajuda/${k}`}>
            {v.title}
          </NavLink>
        ))}
      </aside>
      <article className="info-body">
        <h1 className="display h2">{page.title}</h1>
        {page.body}
      </article>
    </div>
  );
}
