# Content Contributing Guide

Este guia explica como adicionar novo conteúdo ao Baby Sleep (insights, secções do guia, fontes).

## Arquitetura de Conteúdo

```
assets/curated/
├── guide/v1/
│   ├── guide_index.json       # Metadata das secções
│   ├── pt_PT/*.md             # Conteúdo em Português
│   └── en_US/*.md             # Conteúdo em Inglês
├── sources/v1/
│   └── sources.json           # Registry de fontes (AAP, CDC, NHS, etc.)
└── sleep_expectations_v1_pt.json  # Expectativas de sono por idade

lib/l10n/
├── app_pt.arb                 # Strings UI em Português
└── app_en.arb                 # Strings UI em Inglês

lib/domain/analysis/insight_rules/
└── sleep_insight_rules.dart   # Triggers/regras de insights (Dart)

lib/domain/content/
└── content_ids.dart           # IDs estáveis (GuideSectionId, InsightId, SourceId)
```

## Regra de Ouro

- **Copy curta (UI)** → ARB (`lib/l10n/`)
- **Conteúdo longo (Guia)** → Markdown assets (`assets/curated/guide/`)
- **Regras/triggers** → Dart (`lib/domain/analysis/insight_rules/`)
- **IDs** → Dart (`lib/domain/content/content_ids.dart`)

---

## Receita 1: Adicionar uma Nova Regra de Insight

### Passo 1: Definir o ID

Em `lib/domain/content/content_ids.dart`, adiciona o novo ID:

```dart
abstract class InsightId {
  // ... existentes ...
  static const meuNovoInsight = 'meu_novo_insight';
}
```

### Passo 2: Adicionar strings l10n

Em `lib/l10n/app_pt.arb`:
```json
"insightMeuNovoInsightTitle": "Título do insight",
"insightMeuNovoInsightBody": "Corpo do insight com {placeholder}.",
"insightMeuNovoInsightWhy": "Explicação opcional."
```

Em `lib/l10n/app_en.arb`:
```json
"insightMeuNovoInsightTitle": "Insight title",
"insightMeuNovoInsightBody": "Insight body with {placeholder}.",
"@insightMeuNovoInsightBody": {
  "placeholders": { "placeholder": { "type": "String" } }
},
"insightMeuNovoInsightWhy": "Optional explanation."
```

### Passo 3: Criar a regra (trigger)

Em `lib/domain/analysis/insight_rules/sleep_insight_rules.dart`:

```dart
class MeuNovoInsightRule extends SimpleInsightRule {
  @override
  String get id => InsightId.meuNovoInsight;
  
  @override
  InsightPriority get priority => InsightPriority.medium;
  
  @override
  int get cooldownHours => 48;
  
  @override
  int get requiresDataDays => 3;
  
  @override
  bool get requiresDob => false;
  
  @override
  List<SleepAgeBand> get ageBands => [];

  @override
  bool condition(InsightRuleContext context) {
    // Lógica que retorna true quando o insight deve aparecer
    return context.metrics.algumaCoisaRelevante;
  }

  @override
  InsightRenderModel buildInsight(InsightRuleContext context) {
    return InsightRenderModel(
      id: id,
      titleKey: 'insightMeuNovoInsightTitle',
      bodyKey: 'insightMeuNovoInsightBody',
      whyKey: 'insightMeuNovoInsightWhy',
      args: {'placeholder': 'valor'},
      ctaAction: InsightCtaAction.openGuide,
      ctaLabelKey: 'insightCtaLearnMore',
      guideSectionId: GuideSectionId.rotinaAntesDormir,
      priority: priority,
      cooldownHours: cooldownHours,
      requiresDataDays: requiresDataDays,
    );
  }
}
```

### Passo 4: Registar a regra

No final de `sleep_insight_rules.dart`, adiciona à lista:

```dart
List<InsightRule> get allInsightRules => [
  // ... existentes ...
  MeuNovoInsightRule(),
];
```

### Passo 5: Adicionar ao mapper de UI (opcional)

Se a key usa placeholders, adiciona o caso em `_getLocalizedString()` no `insights_page_v2.dart`.

### Passo 6: Gerar l10n

```bash
flutter gen-l10n
```

### Checklist de QA

- [ ] ID adicionado em `content_ids.dart`
- [ ] Strings PT e EN adicionadas nos ARB
- [ ] Regra criada com `condition()` e `buildInsight()`
- [ ] Regra registada em `allInsightRules`
- [ ] `flutter gen-l10n` executado
- [ ] `flutter analyze` sem erros
- [ ] Testado na app (verifica que aparece quando esperado)

---

## Receita 2: Adicionar uma Nova Secção do Guia

### Passo 1: Definir o ID

Em `lib/domain/content/content_ids.dart`:

```dart
abstract class GuideSectionId {
  // ... existentes ...
  static const minhaNovaSecao = 'minha_nova_secao';
}
```

### Passo 2: Criar o Markdown

Em `assets/curated/guide/v1/pt_PT/minha_nova_secao.md`:
```markdown
**Título da subsecção**
Conteúdo aqui. Suporta:
• Bullet points
☐ Checkboxes
1. Listas numeradas
**Texto em negrito** inline.
```

Em `assets/curated/guide/v1/en_US/minha_nova_secao.md`:
```markdown
**Subsection title**
Content here.
```

### Passo 3: Adicionar ao índice

Em `assets/curated/guide/v1/guide_index.json`:

```json
{
  "id": "minha_nova_secao",
  "titleKey": "guide_minha_nova_secao_title",
  "subtitleKey": "guide_minha_nova_secao_subtitle",
  "icon": "lightbulb_outline",
  "order": 6,
  "hasAgeVariants": false,
  "sources": ["AAP", "NHS"]
}
```

### Passo 4: Adicionar strings l10n

Em `lib/l10n/app_pt.arb`:
```json
"guide_minha_nova_secao_title": "Título da secção",
"guide_minha_nova_secao_subtitle": "Subtítulo breve"
```

Em `lib/l10n/app_en.arb`:
```json
"guide_minha_nova_secao_title": "Section title",
"guide_minha_nova_secao_subtitle": "Brief subtitle"
```

### Passo 5: Adicionar ao mapper de títulos

Em `guide_detail_page_v2.dart`, adicionar o case em `_getLocalizedTitle()` e `_getLocalizedSubtitle()`.

### Passo 6: (Opcional) Adicionar à lista da UI

Se quiseres que apareça na lista do Guia em `insights_page_v2.dart`, adiciona um `_GuideItem` na `_GuideSection`.

### Checklist de QA

- [ ] ID adicionado em `content_ids.dart`
- [ ] Markdown PT e EN criados
- [ ] Entrada adicionada em `guide_index.json`
- [ ] Strings PT e EN adicionadas nos ARB
- [ ] Mappers de título atualizados
- [ ] `flutter gen-l10n` executado
- [ ] `flutter analyze` sem erros
- [ ] Testado na app (verifica que carrega corretamente)

---

## Receita 3: Adicionar uma Nova Fonte

Em `assets/curated/sources/v1/sources.json`:

```json
{
  "id": "MINHA_FONTE",
  "name": "Nome Completo da Fonte",
  "publisher": "Organização",
  "url": "https://exemplo.com"
}
```

Em `lib/domain/content/content_ids.dart`:

```dart
abstract class SourceId {
  // ... existentes ...
  static const minhaFonte = 'MINHA_FONTE';
}
```

---

## Boas Práticas

1. **IDs são imutáveis** - Uma vez criado, o ID não deve mudar (quebra cooldowns e favoritos).

2. **Cooldowns razoáveis** - Insights recorrentes: 24-48h. Dicas educativas: 168h (1 semana).

3. **Sem linguagem médica** - Tom empático, não diagnóstico.

4. **Sempre offline-first** - Todo o conteúdo vem dos assets, nunca de rede.

5. **Testar em ambos idiomas** - Muda o idioma do dispositivo e verifica.

6. **Placeholders tipados** - Usar tipos corretos nos ARB (`int`, `String`, etc.).

---

## Comandos Úteis

```bash
# Gerar l10n
flutter gen-l10n

# Analisar código
flutter analyze

# Limpar cache de assets (se markdown não atualizar)
flutter clean && flutter pub get
```
