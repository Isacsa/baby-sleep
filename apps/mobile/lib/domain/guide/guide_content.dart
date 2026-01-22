/// Guide content model for offline educational content
///
/// Contains curated, evidence-based information from AAP/CDC/NHS/AASM.
/// All content is in Portuguese (PT-PT).
class GuideContent {
  /// Unique identifier for linking from insights
  final String id;

  /// Title of the guide section
  final String title;

  /// Short subtitle/teaser
  final String subtitle;

  /// Icon name for display
  final String iconName;

  /// Full content (Markdown-like, but simplified)
  final String content;

  /// Sources referenced
  final List<GuideSource> sources;

  /// Whether this section requires birth date to show age-specific content
  final bool hasAgeVariants;

  const GuideContent({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.iconName,
    required this.content,
    this.sources = const [],
    this.hasAgeVariants = false,
  });
}

/// Source reference for guide content
class GuideSource {
  final String id;
  final String name;
  final String? url;

  const GuideSource({
    required this.id,
    required this.name,
    this.url,
  });
}

/// Static guide content (curated, versioned)
class GuideContentRepository {
  GuideContentRepository._();

  static const List<GuideContent> allSections = [
    _normalByAge,
    _dayVsNight,
    _bedtimeRoutine,
    _safeSleep,
    _whenToCallPediatrician,
  ];

  static GuideContent? getById(String id) {
    try {
      return allSections.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  // === SECTIONS ===

  static const _normalByAge = GuideContent(
    id: 'normal_por_idade',
    title: 'Normal por idade',
    subtitle: 'O que esperar em cada fase',
    iconName: 'child_care',
    hasAgeVariants: true,
    content: '''
**0–3 meses (Recém-nascido)**
• Sono total: 14–17 horas por dia
• Blocos curtos (2–4 horas), dia e noite
• Variabilidade alta é completamente normal
• O ritmo circadiano ainda está a desenvolver-se

**4–12 meses**
• Sono total: 12–16 horas (incluindo sestas)
• Blocos noturnos mais longos começam a aparecer
• 2–3 sestas durante o dia
• Regressões são comuns aos 4, 6 e 9 meses

**12–24 meses**
• Sono total: 11–14 horas (incluindo sestas)
• Tipicamente 1–2 sestas
• Pode resistir à hora de deitar (testar limites)
• Transição para 1 sesta acontece geralmente aos 15–18 meses

Cada bebé é único. Estes são intervalos típicos, não regras rígidas.
''',
    sources: [
      GuideSource(id: 'AASM', name: 'American Academy of Sleep Medicine'),
      GuideSource(id: 'AAP', name: 'American Academy of Pediatrics'),
    ],
  );

  static const _dayVsNight = GuideContent(
    id: 'dia_vs_noite',
    title: 'Dia vs noite',
    subtitle: 'Ajudar o bebé a distinguir',
    iconName: 'brightness_4',
    content: '''
**Durante o dia:**
• Luz natural abundante
• Interações normais, conversa, brincadeira
• Ruídos do dia-a-dia (não é preciso silêncio total)
• Sestas podem ser em ambiente mais claro

**Durante a noite:**
• Luz baixa ou ambiente escuro
• Interações mínimas e calmas
• Voz suave, movimentos lentos
• Evitar estimulação excessiva nas mamadas/mudas

**Porque é importante:**
O ritmo circadiano do bebé desenvolve-se nas primeiras semanas de vida. Estas diferenças ajudam o corpo a perceber quando é dia e quando é noite.

**Dica prática:**
Não é preciso ser perfeito. Pequenas consistências ao longo do tempo são mais importantes do que fazer tudo "certo" num único dia.
''',
    sources: [
      GuideSource(id: 'NHS', name: 'NHS UK'),
    ],
  );

  static const _bedtimeRoutine = GuideContent(
    id: 'rotina_antes_dormir',
    title: 'Rotina antes de dormir',
    subtitle: '2–4 passos simples',
    iconName: 'format_list_numbered',
    content: '''
**O que é uma rotina de sono?**
Uma sequência curta e previsível de atividades calmas antes de dormir. Ajuda o bebé a perceber que "é hora de desligar".

**Exemplo simples (2–4 passos):**
1. Banho ou limpeza
2. Vestir pijama
3. Canção suave ou história curta
4. Luz baixa e despedida

**Dicas:**
• Mantém a mesma ordem todos os dias
• Começa 20–30 minutos antes da hora de dormir
• Faz no mesmo sítio (quarto ou zona calma)
• Menos é mais — rotinas longas podem cansar mais do que relaxar

**O que evitar:**
• Ecrãs ou brinquedos estimulantes
• Jogos ativos ou rir muito
• Muita conversa ou "negociações"

**Não te preocupes se:**
Alguns dias não correm bem. O importante é a consistência ao longo do tempo, não a perfeição em cada noite.
''',
    sources: [
      GuideSource(id: 'AAP', name: 'American Academy of Pediatrics'),
      GuideSource(id: 'NHS', name: 'NHS UK'),
    ],
  );

  static const _safeSleep = GuideContent(
    id: 'sono_seguro',
    title: 'Sono seguro',
    subtitle: 'Checklist rápida',
    iconName: 'verified_user',
    content: '''
**ABC do Sono Seguro:**
• **A**lone (Sozinho) — sem almofadas, mantas soltas, bonecos
• **B**ack (De costas) — sempre de costas para dormir
• **C**rib (Berço) — superfície firme e plana

**Checklist (primeiros 12 meses):**
☐ Bebé dorme de costas
☐ Colchão firme e plano
☐ Lençol bem ajustado
☐ Sem almofadas, mantas soltas ou bonecos
☐ Temperatura confortável (não demasiado quente)
☐ Quarto do bebé sem fumo
☐ Partilha de quarto (não de cama) recomendada até 6–12 meses

**Depois dos 12 meses:**
As recomendações de sono seguro podem ser ajustadas. Consulta o pediatra se tiveres dúvidas.

**Porque importa:**
Estas recomendações reduzem significativamente o risco de problemas durante o sono.
''',
    sources: [
      GuideSource(id: 'AAP', name: 'American Academy of Pediatrics'),
      GuideSource(id: 'CDC', name: 'Centers for Disease Control and Prevention'),
      GuideSource(id: 'NHS', name: 'NHS UK'),
    ],
  );

  static const _whenToCallPediatrician = GuideContent(
    id: 'quando_pediatra',
    title: 'Quando falar com pediatra',
    subtitle: 'Sinais de atenção',
    iconName: 'medical_services_outlined',
    content: '''
**Confia no teu instinto.**
Se algo te preocupa, fala com o pediatra. Não há perguntas "parvas".

**Sinais que merecem atenção médica:**
• Respiração irregular ou pausas longas
• Cor da pele alterada (azulada ou muito pálida)
• Febre em bebés < 3 meses
• Dificuldade em acordar ou letargia extrema
• Recusa persistente em alimentar-se
• Choro inconsolável diferente do habitual

**Sobre o sono em si:**
• Mudanças bruscas no padrão sem causa óbvia
• Ronco consistente ou respiração ruidosa
• Acordar em pânico frequente (diferente de pesadelos normais)

**O que NÃO é necessariamente preocupante:**
• Variabilidade normal no padrão de sono
• Noites difíceis durante regressões ou dentes
• Preferência por adormecer ao colo (muito comum)

**Lembra-te:**
Este guia é informativo. Não substitui aconselhamento médico personalizado.
''',
    sources: [
      GuideSource(id: 'AAP', name: 'American Academy of Pediatrics'),
      GuideSource(id: 'NHS', name: 'NHS UK'),
    ],
  );
}
