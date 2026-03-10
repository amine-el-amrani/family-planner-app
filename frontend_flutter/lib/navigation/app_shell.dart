import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: C.surface,
          border: Border(top: BorderSide(color: C.borderLight, width: 0.8)),
          boxShadow: [
            BoxShadow(
              color: Color(0x0F000000), // ~6% black
              blurRadius: 12,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (i) => navigationShell.goBranch(
            i,
            initialLocation: i == navigationShell.currentIndex,
          ),
          backgroundColor: Colors.transparent,
          indicatorColor: C.primaryLight,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.today_outlined, color: C.textTertiary),
              selectedIcon: Icon(Icons.today, color: C.primary),
              label: 'Auj.',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined, color: C.textTertiary),
              selectedIcon: Icon(Icons.calendar_today, color: C.primary),
              label: 'Agenda',
            ),
            NavigationDestination(
              icon: Icon(Icons.shopping_cart_outlined, color: C.textTertiary),
              selectedIcon: Icon(Icons.shopping_cart, color: C.primary),
              label: 'Courses',
            ),
            NavigationDestination(
              icon: Icon(Icons.group_outlined, color: C.textTertiary),
              selectedIcon: Icon(Icons.group, color: C.primary),
              label: 'Familles',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline, color: C.textTertiary),
              selectedIcon: Icon(Icons.person, color: C.primary),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
