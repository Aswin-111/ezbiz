// lib/widgets/shop_item_card.dart
import 'package:flutter/material.dart';

class ShopItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final double rate;
  final int stock;
  final String uom;
  final VoidCallback onAdd;
  // final VoidCallback? onAdd;
  final bool showAddButton; // ✅ NEW


   const ShopItemCard({
    super.key,
    required this.item,
    required this.rate,
    required this.stock,
    required this.uom,
    required this.onAdd,
    this.showAddButton = true, // ✅ default ON
  });


  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF8B83FF)],
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['item_name'] ?? 'No Name',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEEDFF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.inventory,
                          size: 14, color: Color(0xFF6C63FF)),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Stock: $stock',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.currency_rupee,
                        size: 14, color: Colors.grey),
                    Text(
                      '$rate${uom.isNotEmpty ? ' / $uom' : ''}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
         if (showAddButton)
  Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF6C63FF), Color(0xFF8B83FF)],
      ),
      borderRadius: BorderRadius.circular(15),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF6C63FF).withOpacity(0.3),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: IconButton(
      icon: const Icon(Icons.add, color: Colors.white, size: 24),
      onPressed: onAdd,
    ),
  ),

        ],
      ),
    );
  }
}
