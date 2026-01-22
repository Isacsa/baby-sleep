import 'package:flutter/material.dart';
import 'package:temp_flutter/core/l10n/l10n.dart';
import 'package:temp_flutter/presentation/theme/night_theme.dart';

/// RelaxPage - Tab Relaxar
/// 
/// Placeholder com categorias e cards
/// Sem áudio real por enquanto
class RelaxPage extends StatefulWidget {
  const RelaxPage({super.key});

  @override
  State<RelaxPage> createState() => _RelaxPageState();
}

class _RelaxPageState extends State<RelaxPage> {
  String _selectedCategory = 'Sons';

  final List<String> _categories = ['Sons', 'Técnicas', 'Rotina'];

  final Map<String, List<_RelaxItem>> _items = {
    'Sons': [
      _RelaxItem(
        title: 'Ruído Branco',
        subtitle: 'Som contínuo relaxante',
        icon: Icons.waves,
      ),
      _RelaxItem(
        title: 'Chuva',
        subtitle: 'Som de chuva suave',
        icon: Icons.water_drop,
      ),
      _RelaxItem(
        title: 'Shushing',
        subtitle: 'Som calmante tradicional',
        icon: Icons.air,
      ),
      _RelaxItem(
        title: 'Batimento Cardíaco',
        subtitle: 'Lembra o útero',
        icon: Icons.favorite,
      ),
    ],
    'Técnicas': [
      _RelaxItem(
        title: 'Massagem Relaxante',
        subtitle: '5 passos simples',
        icon: Icons.self_improvement,
      ),
      _RelaxItem(
        title: '5 S de Harvey Karp',
        subtitle: 'Swaddle, Side, Shush...',
        icon: Icons.stars,
      ),
      _RelaxItem(
        title: 'Respiração Calma',
        subtitle: 'Guia para pais',
        icon: Icons.spa,
      ),
    ],
    'Rotina': [
      _RelaxItem(
        title: 'Rotina do Sono',
        subtitle: 'Passo a passo noturno',
        icon: Icons.bedtime,
      ),
      _RelaxItem(
        title: 'Banho Relaxante',
        subtitle: 'Preparar para dormir',
        icon: Icons.bathtub,
      ),
      _RelaxItem(
        title: 'Música Calma',
        subtitle: 'Playlist sugerida',
        icon: Icons.music_note,
      ),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final items = _items[_selectedCategory] ?? [];

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              context.l10n.relaxTitle,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: NightTheme.textPrimary,
              ),
            ),
          ),
          
          // Category chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 8,
              children: _categories.map((category) {
                final isSelected = category == _selectedCategory;
                return FilterChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => _selectedCategory = category);
                  },
                  backgroundColor: NightTheme.surface,
                  selectedColor: NightTheme.primary.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: isSelected ? NightTheme.primary : NightTheme.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  side: BorderSide(
                    color: isSelected ? NightTheme.primary : Colors.transparent,
                  ),
                );
              }).toList(),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Content
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return _RelaxCard(item: item);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RelaxItem {
  final String title;
  final String subtitle;
  final IconData icon;

  const _RelaxItem({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _RelaxCard extends StatelessWidget {
  final _RelaxItem item;

  const _RelaxCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: NightTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${item.title} - ${context.l10n.relaxComingSoon}'),
                backgroundColor: NightTheme.surface,
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: NightTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    item.icon,
                    color: NightTheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: NightTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: NightTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: NightTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
