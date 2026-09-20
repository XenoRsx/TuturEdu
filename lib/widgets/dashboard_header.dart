// lib/widgets/dashboard_header.dart
//
// Fixed (non-scrolling) header shown above a role dashboard's chat list - a
// stat row + a quick-action grid, so TeacherDashboard/StudentDashboard/
// ParentDashboard have real "home" content instead of being just a chat
// list with a handful of AppBar icons (see chat_list_screen.dart's
// `homeHeader` builder param, which renders this above the TabBarView).

import 'package:flutter/material.dart';
import 'icon_tile.dart';
import 'stat_tile.dart';

class QuickAction {
  const QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.stats,
    required this.actions,
  });

  final List<StatTile> stats;
  final List<QuickAction> actions;

  static List<Widget> _withGaps(List<Widget> widgets, double gap) {
    final result = <Widget>[];
    for (var i = 0; i < widgets.length; i++) {
      if (i > 0) result.add(SizedBox(width: gap));
      result.add(widgets[i]);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          Row(children: _withGaps(stats, 10)),
          const SizedBox(height: 14),
          Row(
            children: _withGaps([
              for (final action in actions)
                Expanded(child: _ActionButton(action: action)),
            ], 10),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action});

  final QuickAction action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: action.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              IconTile(icon: action.icon, color: action.color, size: 40),
              const SizedBox(height: 6),
              Text(
                action.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
