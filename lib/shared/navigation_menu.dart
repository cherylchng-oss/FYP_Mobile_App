import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// DrawerMenuItem — icon + label pair for side drawer
// ---------------------------------------------------------------------------
class DrawerMenuItem {
  final IconData icon;
  final String label;

  const DrawerMenuItem(this.icon, this.label);
}

// ---------------------------------------------------------------------------
// UserRole — all platform roles
// ---------------------------------------------------------------------------
enum UserRole { admin, moderator, customer, owner }

// ---------------------------------------------------------------------------
// userRoleFromString — parse API role string to enum
// ---------------------------------------------------------------------------
UserRole? userRoleFromString(String? role) {
  final normalized = role?.toLowerCase().trim() ?? '';
  if (normalized == 'admin' || normalized == 'administrator') {
    return UserRole.admin;
  }
  if (normalized == 'moderator') {
    return UserRole.moderator;
  }
  if (normalized == 'customer') {
    return UserRole.customer;
  }
  if (normalized == 'owner') {
    return UserRole.owner;
  }
  return null;
}

// ---------------------------------------------------------------------------
// drawerMenuItemsForRole — items shown in the side drawer per role
// ---------------------------------------------------------------------------
List<DrawerMenuItem> drawerMenuItemsForRole(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return const [
        DrawerMenuItem(Icons.dashboard, 'Dashboard'),
        DrawerMenuItem(Icons.people, 'User Management'),
        DrawerMenuItem(Icons.apartment, 'Properties'),
        DrawerMenuItem(Icons.list_alt, 'Activity Logs'),
        DrawerMenuItem(Icons.account_balance_wallet, 'Ledger'),
        DrawerMenuItem(Icons.inventory_2, 'Stock Manager'),
        DrawerMenuItem(Icons.star_rate, 'Customer Review'),
        DrawerMenuItem(Icons.person, 'Profile'),
      ];
    case UserRole.moderator:
      return const [
        DrawerMenuItem(Icons.dashboard, 'Dashboard'),
        DrawerMenuItem(Icons.people, 'User Management'),
        DrawerMenuItem(Icons.apartment, 'Properties'),
        DrawerMenuItem(Icons.list_alt, 'Activity Logs'),
        DrawerMenuItem(Icons.account_balance_wallet, 'Ledger'),
        DrawerMenuItem(Icons.inventory_2, 'Stock Manager'),
        DrawerMenuItem(Icons.star_rate, 'Customer Reviews'),
        DrawerMenuItem(Icons.person, 'Profile'),
      ];
    case UserRole.customer:
      return const [
        DrawerMenuItem(Icons.dashboard, 'Rooms'),
        DrawerMenuItem(Icons.shopping_cart, 'Cart'),
        DrawerMenuItem(Icons.calendar_today, 'Bookings'),
        DrawerMenuItem(Icons.notifications, 'Notifications'),
        DrawerMenuItem(Icons.person, 'Profile'),
      ];
    case UserRole.owner:
      // Owner uses bottom nav only — no drawer. These items are kept for
      // consistency but the owner scaffold does not render a side drawer.
      return const [
        DrawerMenuItem(Icons.dashboard_rounded, 'Dashboard'),
        DrawerMenuItem(Icons.people_rounded, 'Users'),
        DrawerMenuItem(Icons.location_city_rounded, 'Clusters'),
        DrawerMenuItem(Icons.receipt_long_rounded, 'Logs'),
        DrawerMenuItem(Icons.person_rounded, 'Profile'),
      ];
  }
}