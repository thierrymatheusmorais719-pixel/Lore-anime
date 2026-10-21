export const SIZE_TABLE: [string, string, string, string][] = [
  ['34', '3.5', '36', '22,5'],
  ['35', '4.5', '37', '23,0'],
  ['36', '5', '37,5', '23,5'],
  ['37', '6', '38,5', '24,5'],
  ['38', '7', '40', '25,0'],
  ['39', '7.5', '40,5', '25,5'],
  ['40', '8', '41', '26,0'],
  ['41', '9', '42,5', '27,0'],
  ['42', '9.5', '43', '27,5'],
  ['43', '10', '44', '28,0'],
  ['44', '11', '45', '29,0'],
  ['45', '12', '46', '30,0'],
];

export function SizeGuide({ highlight }: { highlight?: string }) {
  return (
    <div className="size-guide">
      <p className="muted">
        Meça o pé no fim do dia, apoiado no chão, do calcanhar até a ponta do dedo mais longo. Compare com a coluna
        “centímetros”. Entre dois tamanhos, escolha o maior.
      </p>
      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>BR</th>
              <th>US</th>
              <th>EU</th>
              <th>Centímetros</th>
            </tr>
          </thead>
          <tbody>
            {SIZE_TABLE.map((r) => (
              <tr key={r[0]} className={r[0] === highlight ? 'hl' : ''}>
                {r.map((c, i) => (
                  <td key={i}>{c}</td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <ul className="size-tips">
        <li><strong>Basketball e high-tops:</strong> forma normal, com mais estrutura no tornozelo.</li>
        <li><strong>Running:</strong> considere meio número acima para corridas longas.</li>
        <li><strong>Couro (Kurō, Vantra):</strong> lacea com o uso; prefira o tamanho exato.</li>
      </ul>
    </div>
  );
}
