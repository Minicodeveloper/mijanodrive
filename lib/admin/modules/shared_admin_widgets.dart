import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../models/trip_model.dart';

// Encabezado reutilizable de cada módulo.
class AdminHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const AdminHeader(this.title, this.subtitle, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 26, fontWeight: FontWeight.w900, color: MijanoTheme.ink)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 20),
      ],
    );
  }
}

Widget adminCard({
  required Widget child,
  EdgeInsetsGeometry padding = const EdgeInsets.all(20),
}) =>
    Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: child,
    );

// ---------- Tarjetas de estadísticas responsivas ----------
class AdminStat {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const AdminStat(this.label, this.value, this.icon, this.color);
}

class AdminStatsGrid extends StatelessWidget {
  final List<AdminStat> items;
  const AdminStatsGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const gap = 12.0;
      final compact = c.maxWidth < 700;
      final cols = compact ? 2 : items.length.clamp(1, 4);
      final cardW = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: List.generate(items.length, (i) {
          final isLoneLast = compact && i == items.length - 1 && items.length.isOdd;
          return SizedBox(
            width: isLoneLast ? c.maxWidth : cardW,
            child: _AdminStatCard(items[i], compact: compact),
          );
        }),
      );
    });
  }
}

class _AdminStatCard extends StatelessWidget {
  final AdminStat s;
  final bool compact;
  const _AdminStatCard(this.s, {required this.compact});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w500)),
                SizedBox(height: compact ? 4 : 8),
                Text(s.value,
                    style: TextStyle(
                        fontSize: compact ? 20 : 24,
                        fontWeight: FontWeight.w900,
                        color: MijanoTheme.ink)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: EdgeInsets.all(compact ? 8 : 12),
            decoration: BoxDecoration(
              color: s.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(s.icon, color: s.color, size: compact ? 22 : 28),
          ),
        ],
      ),
    );
  }
}

// ---------- Filtros + buscador responsivos ----------
class AdminFilterBar extends StatelessWidget {
  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onSelected;
  final TextEditingController searchCtrl;
  final String searchHint;
  final ValueChanged<String> onSearch;

  const AdminFilterBar({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelected,
    required this.searchCtrl,
    required this.searchHint,
    required this.onSearch,
  });

  Widget _chips() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: List.generate(tabs.length, (i) {
      final isSelected = selected == i;
      return FilterChip(
        label: Text(tabs[i]),
        selected: isSelected,
        onSelected: (_) => onSelected(i),
        selectedColor: MijanoTheme.sol,
        checkmarkColor: MijanoTheme.ink,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: isSelected ? MijanoTheme.ink : Colors.black12),
        ),
      );
    }),
  );

  Widget _search() => TextField(
    controller: searchCtrl,
    decoration: InputDecoration(
      hintText: searchHint,
      prefixIcon: const Icon(Icons.search),
      border: const OutlineInputBorder(),
      isDense: true,
    ),
    onChanged: onSearch,
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 700) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [_search(), const SizedBox(height: 12), _chips()],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _chips()),
          const SizedBox(width: 16),
          SizedBox(width: 280, child: _search()),
        ],
      );
    });
  }
}

Color getTripStatusColor(TripStatus s) {
  switch (s) {
    case TripStatus.active:
      return Colors.green;
    case TripStatus.accepted:
      return Colors.orange;
    default:
      return Colors.blueGrey;
  }
}

String getTripStatusEs(TripStatus s) {
  switch (s) {
    case TripStatus.pending:
      return 'Buscando conductor';
    case TripStatus.accepted:
      return 'Conductor asignado';
    case TripStatus.active:
      return 'En curso';
    case TripStatus.completed:
      return 'Completado';
    case TripStatus.cancelled:
      return 'Cancelado';
  }
}