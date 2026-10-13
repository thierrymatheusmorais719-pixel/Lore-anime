// O ROTEIRO: cada fala do narrador, na ordem, agrupada por cena.
// measure.js mede quanto cada fala dura (vodur.js) e score.js monta a linha do tempo a partir disso.
(function () {
  const SCENES = [
    ['intro', [
      ['i1', 'Fala, turma! Prova de Química amanhã? Então bora revisar tudo sobre ligações químicas.'],
      ['i2', 'São três tipos: iônica, covalente e metálica. Presta atenção, que isso cai!'],
    ]],
    ['octeto', [
      ['o1', 'Primeiro: por que os átomos se ligam? Porque eles buscam estabilidade.'],
      ['o2', 'Os gases nobres, como o neônio, já são estáveis: eles têm oito elétrons na última camada.'],
      ['o3', 'Essa é a regra do octeto. Os outros átomos fazem ligações para ficar com oito elétrons na camada de valência.'],
      ['o4', 'Atenção à exceção: o hidrogênio fica estável com apenas dois elétrons, igual ao hélio.'],
    ]],
    ['valencia', [
      ['v1', 'Os elétrons da última camada são os elétrons de valência. E a família da tabela periódica entrega quantos são.'],
      ['v2', 'Metais têm poucos, de um a três, e tendem a perder elétrons, virando cátions, que são íons positivos.'],
      ['v3', 'Ametais têm muitos, de cinco a sete, e tendem a ganhar elétrons, virando ânions, que são íons negativos.'],
    ]],
    ['ionica', [
      ['n1', 'Ligação iônica! Ela acontece entre um metal e um ametal.'],
      ['n2', 'Veja o sódio e o cloro. O sódio tem um elétron de valência. O cloro tem sete.'],
      ['n3', 'O sódio transfere o seu elétron para o cloro. Agora os dois ficam com oito elétrons na última camada.'],
      ['n4', 'O sódio vira o cátion sódio, positivo. O cloro vira o ânion cloreto, negativo.'],
      ['n5', 'Cargas opostas se atraem. Essa atração eletrostática é a ligação iônica. Nasce o cloreto de sódio, o sal de cozinha!'],
    ]],
    ['reticulo', [
      ['n6', 'No sólido, milhões de íons se organizam num retículo cristalino, uma grade bem arrumada.'],
      ['n7', 'Por isso, os compostos iônicos são sólidos na temperatura ambiente, com pontos de fusão e ebulição altos.'],
      ['n8', 'São duros, mas quebradiços. E conduzem corrente elétrica quando fundidos ou dissolvidos em água. No estado sólido, não conduzem.'],
    ]],
    ['formula', [
      ['f1', 'Dica para montar a fórmula: a carga de um vira o índice do outro.'],
      ['f2', 'Alumínio três mais, com oxigênio dois menos. O três vai para o oxigênio, e o dois vai para o alumínio.'],
      ['f3', 'Resultado: alumínio dois, oxigênio três.'],
    ]],
    ['covalente', [
      ['c1', 'Ligação covalente! Ela acontece entre ametais, ou entre ametal e hidrogênio.'],
      ['c2', 'Aqui ninguém quer perder elétrons. Então os átomos compartilham pares de elétrons.'],
      ['c3', 'No gás hidrogênio, cada átomo tem um elétron. Eles compartilham um par: é uma ligação simples.'],
      ['c4', 'No gás oxigênio, cada átomo precisa de mais dois elétrons. São dois pares: uma ligação dupla.'],
      ['c5', 'No gás nitrogênio, cada átomo precisa de mais três. São três pares: uma ligação tripla.'],
    ]],
    ['moleculas', [
      ['c6', 'Na água, o oxigênio tem seis elétrons de valência e faz duas ligações simples, uma com cada hidrogênio.'],
      ['c7', 'No gás carbônico, o carbono tem quatro elétrons de valência e faz duas ligações duplas, uma com cada oxigênio.'],
    ]],
    ['formulas', [
      ['c8', 'Na prova, aparecem três jeitos de representar uma molécula.'],
      ['c9', 'A fórmula eletrônica, ou de Lewis, mostra os elétrons de valência como pontinhos.'],
      ['c10', 'A fórmula estrutural troca cada par compartilhado por um tracinho.'],
      ['c11', 'E a fórmula molecular mostra só os átomos e as quantidades, como H dois O.'],
    ]],
    ['covprop', [
      ['c12', 'Compostos covalentes formam moléculas. Podem ser sólidos, líquidos ou gasosos, e costumam ter pontos de fusão e ebulição mais baixos que os iônicos.'],
      ['c13', 'E, em geral, não conduzem corrente elétrica.'],
    ]],
    ['metalica', [
      ['m1', 'Ligação metálica! Ela acontece entre átomos de metais.'],
      ['m2', 'Os metais soltam seus elétrons de valência. Eles ficam livres, passeando entre os cátions: é o famoso mar de elétrons.'],
      ['m3', 'Esse mar de elétrons funciona como uma cola, que mantém os cátions metálicos unidos.'],
    ]],
    ['metprop', [
      ['m4', 'Por causa dele, os metais são ótimos condutores de eletricidade e de calor.'],
      ['m5', 'Têm brilho metálico, são maleáveis, viram lâminas, e são dúcteis, viram fios.'],
      ['m6', 'São sólidos na temperatura ambiente. A exceção é o mercúrio, que é líquido.'],
    ]],
    ['ligas', [
      ['m7', 'E quando misturamos metais, temos as ligas metálicas.'],
      ['m8', 'Bronze é cobre com estanho. Latão é cobre com zinco. E o aço é ferro com um pouquinho de carbono.'],
    ]],
    ['resumo', [
      ['r1', 'Hora do resumo!'],
      ['r2', 'Iônica: metal com ametal. Transfere elétrons e forma íons.'],
      ['r3', 'Covalente: ametal com ametal, ou com hidrogênio. Compartilha pares de elétrons e forma moléculas.'],
      ['r4', 'Metálica: metal com metal. Cátions mergulhados num mar de elétrons.'],
    ]],
    ['dicas', [
      ['d1', 'Três dicas para a prova.'],
      ['d2', 'Um: veja se cada elemento é metal ou ametal. Isso já diz o tipo de ligação.'],
      ['d3', 'Dois: conte os elétrons de valência pela família da tabela periódica.'],
      ['d4', 'Três: lembre que o hidrogênio se comporta como ametal.'],
    ]],
    ['fim', [
      ['e1', 'É isso! Revisa, respira e arrasa na prova. Boa sorte!'],
    ]],
  ];
  const LINES = { SCENES };
  if (typeof module !== 'undefined') module.exports = LINES; else globalThis.LINES = LINES;
})();
