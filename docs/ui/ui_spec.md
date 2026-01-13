# UI/UX Specification - Baby Sleep MVP

Este documento define a identidade visual, componentes e fluxos de interface para a aplicação **Baby Sleep**, focada numa experiência noturna elegante e funcional.

## 1. Design System

### 1.1 Paleta de Cores (Night Theme)
A paleta baseia-se em tons escuros e profundos para evitar o cansaço visual durante a noite, com acentos suaves.

| Elemento | Hex | Exemplo/Uso |
| :--- | :--- | :--- |
| **Fundo Topo** | `#0F172A` | Início do gradiente de fundo (Slate 900) |
| **Fundo Base** | `#1E293B` | Fim do gradiente de fundo (Slate 800) |
| **Primária** | `#38BDF8` | Botão Start, ícone sono ativo (Sky 400) |
| **Secundária** | `#818CF8` | Botão End, destaques (Indigo 400) |
| **Acento (Estrelas)** | `#FDE047` | Estrelas subtis, alertas suaves (Yellow 300) |
| **Superfície** | `#1E293BCC` | Cards e Bottom Sheets (com 80% opacidade) |
| **Texto Principal** | `#F8FAFC` | Títulos e corpo (Slate 50) |
| **Texto Secundário**| `#94A3B8` | Notas, labels, microcopy (Slate 400) |
| **Erro/Alerta** | `#FB7185` | Erros de sincronização (Rose 400) |

### 1.2 Tipografia
- **Fonte Principal:** Inter ou Roboto (Sans Serif).
- **H1 (Título Home):** 32px, Bold, Slate 50.
- **H2 (Títulos Secção):** 24px, SemiBold, Slate 50.
- **Body:** 16px, Regular, Slate 200.
- **Caption/Small:** 12px, Regular, Slate 400.

### 1.3 Espaçamentos e Formas
- **Grid:** 8px base (8, 16, 24, 32, 48).
- **Border Radius:** 16px (Cards e Botões), 24px (Bottom Sheet).
- **Padding Global:** 20px nas laterais.

---

## 2. Componentes Reutilizáveis

| Componente | Descrição |
| :--- | :--- |
| `StarryBackground` | Fundo gradiente com estrelas fixas de opacidade variável (0.1 a 0.3). |
| `FloatingBottomBar` | Barra de navegação suspensa com blur (Glassmorphism). |
| `PrimarySleepButton` | Botão circular central (120x120) com feedback tátil e visual de estado. |
| `QuickTimeChip` | Chips de 5, 10, 15 min para ajustes rápidos de hora de início. |
| `SyncStatusChip` | Indicador minimalista no canto superior com estado de rede/sync. |
| `DaySummaryCard` | Card com total de horas dormidas e número de sestas. |
| `InsightCard` | Card de texto com "Dica do Dia" ou curiosidade sobre o sono. |

---

## 3. Layout das Páginas

### 3.1 Home (Tab: Sono)
- **Header:** Logo à esquerda, Título "Bebé [Nome]", Botão Calendário (Ícone) à direita.
- **Centro:** `PrimarySleepButton`.
  - Estado *Acordado*: Ícone Sol, Texto "Dormir Agora".
  - Estado *A Dormir*: Ícone Lua, Texto "Acordou", cronómetro central.
- **Quick Actions (embaixo do botão):** "Começar há:" 5min, 10min, 15min ou "Outra hora".
- **Footer:** `FloatingBottomBar`.

### 3.2 Dia (Detalhe Calendário)
- **Header:** Botão Voltar, Data (Ex: "Hoje, 13 Jan").
- **Resumo Superior:** `DaySummaryCard` (Total: 12h 30m | Sestas: 3).
- **Timeline:** Lista vertical de sessões.
  - Cada item: "21:30 - 07:15 (9h 45m)".
  - Ação de editar rápida.

### 3.3 Relaxar (Tab: Relaxar)
- **Categorias (Chips):** Sons, Técnicas, Rotina.
- **Lista de Conteúdos:** Cards com imagens suaves e títulos curtos.
  - Ex: "Ruído Branco", "Massagem de Relaxamento", "Shushing".
- **Player Minimalista:** Caso um som esteja ativo, barra flutuante acima da navegação.

### 3.4 Estatísticas (Tab: Estatísticas)
- **Toggle:** Semana / Mês.
- **Gráfico:** Barras simples com horas totais por dia.
- **Insights:** Lista de `InsightCard`.
  - Ex: "Esta semana o [Nome] dormiu mais 20min em média por sesta."

---

## 4. Estados da Interface

- **Empty State:** Ilustração subtil de um berço vazio com texto "Ainda sem registos hoje".
- **Loading:** Skeleton screens em tons de azul escuro.
- **Offline:** Banner discreto no topo ou `SyncStatusChip` com ícone de nuvem cortada.
- **Error:** SnackBar com cor Rose 400 e botão "Tentar novamente".

---

## 5. Microcopy (PT-PT)

A linguagem deve ser empática, curta e humana.

- **Boas-vindas:** "Olá, como correu a noite?"
- **Estado Ativo:** "O [Nome] está a dormir..."
- **Confirmação:** "Registo guardado com sucesso."
- **Erro Sync:** "Não conseguimos sincronizar, mas o dado está seguro no telemóvel."
- **Insight:** "Sabia que nesta fase o sono REM ajuda o cérebro a crescer?"

---

## 6. Navegação e Hierarquia

**Navegação Principal (Navigator 1.0):**
1. `BabiesPage` (Root se autenticado) -> Seleção de bebé.
2. `MainScaffold` (Wrapper para as Tabs):
   - `/home` (Default)
   - `/relax`
   - `/stats`
3. Rotas de detalhe (Push):
   - `/day-detail` (Calendário)
   - `/settings` (Opcional)

---

## 7. Checklist de Implementação

- [ ] Implementar `StarryBackground` (CustomPainter ou Stack de Widgets).
- [ ] Criar `ThemeData` customizado com as cores da spec.
- [ ] Construir `FloatingBottomBar` com `BackdropFilter` para o efeito glass.
- [ ] Implementar `PrimarySleepButton` com transição de ícones suave.
- [ ] Criar lógica de navegação entre as 3 tabs principais.
- [ ] Desenhar `DaySummaryCard` com gradientes suaves.
