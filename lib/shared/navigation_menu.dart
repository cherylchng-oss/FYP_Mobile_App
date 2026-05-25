import 'package:flutter/material.dart';

class DrawerMenuItem {
  final IconData icon;
  final String label;

  const DrawerMenuItem(this.icon, this.label);
}

enum UserRole { admin, moderator, customer, owner }

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

List<DrawerMenuItem> drawerMenuItemsForRole(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return const [
        DrawerMenuItem(Icons.dashboard_rounded, 'Dashboard'),
        DrawerMenuItem(Icons.people_rounded, 'User Management'),
        DrawerMenuItem(Icons.apartment_rounded, 'Properties'),
        DrawerMenuItem(Icons.list_alt_rounded, 'Activity Logs'),
        DrawerMenuItem(Icons.account_balance_wallet_rounded, 'Ledger'),
        DrawerMenuItem(Icons.inventory_2_rounded, 'Stock Manager'),
        DrawerMenuItem(Icons.star_rate_rounded, 'Customer Reviews'),
        DrawerMenuItem(Icons.person_rounded, 'Profile'),
      ];

    case UserRole.moderator:
      return const [
        DrawerMenuItem(Icons.dashboard_rounded, 'Dashboard'),
        DrawerMenuItem(Icons.people_rounded, 'User Management'),
        DrawerMenuItem(Icons.apartment_rounded, 'Properties'),
        DrawerMenuItem(Icons.list_alt_rounded, 'Activity Logs'),
        DrawerMenuItem(Icons.account_balance_wallet_rounded, 'Ledger'),
        DrawerMenuItem(Icons.inventory_2_rounded, 'Stock Manager'),
        DrawerMenuItem(Icons.star_rate_rounded, 'Customer Reviews'),
        DrawerMenuItem(Icons.person_rounded, 'Profile'),
      ];

    case UserRole.customer:
      return const [
        DrawerMenuItem(Icons.home_rounded, 'Rooms'),
        DrawerMenuItem(Icons.shopping_cart_rounded, 'Cart'),
        DrawerMenuItem(Icons.calendar_today_rounded, 'Bookings'),
        DrawerMenuItem(Icons.notifications_rounded, 'Notifications'),
        DrawerMenuItem(Icons.person_rounded, 'Profile'),
      ];

    case UserRole.owner:
      return const [
        DrawerMenuItem(Icons.dashboard_rounded, 'Dashboard'),
        DrawerMenuItem(Icons.people_rounded, 'Customer'),
        DrawerMenuItem(Icons.admin_panel_settings_rounded, 'Moderator/Admin'),
        DrawerMenuItem(Icons.apartment_rounded, 'Properties'),
        DrawerMenuItem(Icons.calendar_today_rounded, 'Bookings'),
        DrawerMenuItem(Icons.receipt_long_rounded, 'BooknPayLog'),
        DrawerMenuItem(Icons.history_rounded, 'AuditTrails'),
        DrawerMenuItem(Icons.location_city_rounded, 'Cluster'),
        DrawerMenuItem(Icons.person_rounded, 'Profile'),
      ];
  }
}