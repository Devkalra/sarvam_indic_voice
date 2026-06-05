import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;

// ── Data classes ─────────────────────────────────────────────────────────────

/// A single item available on the menu.
class MenuItem {
  final String id;
  final String name;
  final String emoji; // displayed as a big icon in the card
  final String category;
  final double priceINR;
  final Color accentColor; // gradient accent per card

  const MenuItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.category,
    required this.priceINR,
    required this.accentColor,
  });
}

// ── Menu catalogue ────────────────────────────────────────────────────────────
// These names MUST match what the backend returns in `detected_item`.
// Extend this list to add more cards to the grid instantly.
const List<MenuItem> kMenuItems = [
  MenuItem(
    id: 'chicken_biryani',
    name: 'Chicken Biryani',
    emoji: '🍛',
    category: 'Main Course',
    priceINR: 249,
    accentColor: Color(0xFFFF6D3F),
  ),
  MenuItem(
    id: 'veg_biryani',
    name: 'Veg Biryani',
    emoji: '🌿',
    category: 'Main Course',
    priceINR: 199,
    accentColor: Color(0xFF4CAF50),
  ),
  MenuItem(
    id: 'veg_pizza',
    name: 'Veg Pizza',
    emoji: '🍕',
    category: 'Pizza',
    priceINR: 299,
    accentColor: Color(0xFFE91E63),
  ),
  MenuItem(
    id: 'paneer_pizza',
    name: 'Paneer Pizza',
    emoji: '🧀',
    category: 'Pizza',
    priceINR: 329,
    accentColor: Color(0xFFFF9800),
  ),
  MenuItem(
    id: 'coca_cola',
    name: 'Coca-Cola',
    emoji: '🥤',
    category: 'Drinks',
    priceINR: 60,
    accentColor: Color(0xFFB71C1C),
  ),
  MenuItem(
    id: 'pepsi',
    name: 'Pepsi',
    emoji: '🫙',
    category: 'Drinks',
    priceINR: 60,
    accentColor: Color(0xFF1565C0),
  ),
  MenuItem(
    id: 'mango_lassi',
    name: 'Mango Lassi',
    emoji: '🥭',
    category: 'Drinks',
    priceINR: 89,
    accentColor: Color(0xFFFFC107),
  ),
  MenuItem(
    id: 'veg_burger',
    name: 'Veg Burger',
    emoji: '🍔',
    category: 'Burger',
    priceINR: 129,
    accentColor: Color(0xFF795548),
  ),
  MenuItem(
    id: 'chicken_burger',
    name: 'Chicken Burger',
    emoji: '🐔',
    category: 'Burger',
    priceINR: 159,
    accentColor: Color(0xFFFF7043),
  ),
  MenuItem(
    id: 'paneer_wrap',
    name: 'Paneer Wrap',
    emoji: '🌯',
    category: 'Wraps',
    priceINR: 149,
    accentColor: Color(0xFF9C27B0),
  ),
  MenuItem(
    id: 'french_fries',
    name: 'French Fries',
    emoji: '🍟',
    category: 'Sides',
    priceINR: 99,
    accentColor: Color(0xFFFFEB3B),
  ),
  MenuItem(
    id: 'gulab_jamun',
    name: 'Gulab Jamun',
    emoji: '🍮',
    category: 'Dessert',
    priceINR: 79,
    accentColor: Color(0xFF880E4F),
  ),
];

// ── CartModel 

/* Holds the current cart state and exposes mutation methods.
Extend with ChangeNotifier and call notifyListeners() after every mutation, So the UI rebuilds automatically.*/

class CartModel extends ChangeNotifier {
  // item.id → quantity in cart
  final Map<String, int> _quantities = {};

  // Raw JSON log entries shown in the "Activity Log" drawer
  final List<Map<String, dynamic>> _activityLog = [];


  int quantityOf(String itemId) => _quantities[itemId] ?? 0;

  Map<String, int> get allQuantities => Map.unmodifiable(_quantities);

  List<Map<String, dynamic>> get activityLog => List.unmodifiable(_activityLog);

  int get totalItems => _quantities.values.fold(0, (sum, qty) => sum + qty);

  double get totalPrice {
    double total = 0;
    _quantities.forEach((id, qty) {
      final item = kMenuItems.firstWhere(
        (m) => m.id == id,
        orElse: () => kMenuItems.first,
      );
      total += item.priceINR * qty;
    });
    return total;
  }


  /// Increments the quantity for a given item by [delta] (can be negative).
  void adjustQuantity(String itemId, int delta) {
    final current = _quantities[itemId] ?? 0;
    final updated = (current + delta).clamp(0, 99);
    if (updated == 0) {
      _quantities.remove(itemId);
    } else {
      _quantities[itemId] = updated;
    }
    notifyListeners();
  }

  /// Called by VoiceController after a successful API response.
  /// Finds the MenuItem whose name matches [detectedName] (case-insensitive)
  /// and adds [quantity] to its cart count.
  ///
  /// Returns true if the item was found and updated.
  bool applyVoiceOrder({
    required String detectedName,
    required int quantity,
  }) {
    // Try to find a menu item whose name matches
    final idx = kMenuItems.indexWhere(
      (m) => m.name.toLowerCase() == detectedName.toLowerCase(),
    );
    if (idx == -1) return false;

    final item = kMenuItems[idx];
    _quantities[item.id] =
        ((_quantities[item.id] ?? 0) + quantity).clamp(0, 99);
    notifyListeners();
    return true;
  }

  /// Applies ALL detected items from the backend's `all_detected_items` list.
  void applyAllVoiceOrders(List<Map<String, dynamic>> items) {
    for (final entry in items) {
      final name = (entry['item'] as String?) ?? '';
      final qty = (entry['quantity'] as int?) ?? 1;
      applyVoiceOrder(detectedName: name, quantity: qty);
    }
  }

  /// Pushes a new log entry (the raw JSON from the backend) into the log.
  void addLog(Map<String, dynamic> entry) {
    _activityLog.insert(0, entry); // newest first
    if (_activityLog.length > 50) _activityLog.removeLast();
    notifyListeners();
  }

  void clearCart() {
    _quantities.clear();
    notifyListeners();
  }
}
