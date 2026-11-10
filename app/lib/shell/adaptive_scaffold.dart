import 'package:flutter/material.dart';

import '../theme/ow_colors.dart';
import 'breakpoints.dart';

class AdaptiveDestination {
  const AdaptiveDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// 导航外壳：窄屏用底部导航，中屏用图标侧栏，宽屏用带文字的侧栏。
///
/// 页面内容不关心自己处在哪种外壳里。
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
    required this.body,
  });

  final List<AdaptiveDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final size = Breakpoints.of(context);
    if (size == ScreenSize.compact) {
      return Scaffold(
        body: body,
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: context.ow.line)),
          ),
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onSelect,
            destinations: [
              for (final d in destinations)
                NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: d.label,
                ),
            ],
          ),
        ),
      );
    }
    final extended = size == ScreenSize.expanded;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              extended: extended,
              minExtendedWidth: 200,
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              selectedIndex: selectedIndex,
              onDestinationSelected: onSelect,
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
            VerticalDivider(width: 1, color: context.ow.line),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
