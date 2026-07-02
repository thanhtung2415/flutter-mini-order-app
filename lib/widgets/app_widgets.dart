import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../state/app_state.dart';

Color tableStatusColor(TableStatus status) => switch (status) {
  TableStatus.available => const Color(0xFF2E7D32),
  TableStatus.ordering => const Color(0xFFF57C00),
  TableStatus.paid => const Color(0xFF1565C0),
};

Color orderStatusColor(OrderStatus status) => switch (status) {
  OrderStatus.pending => const Color(0xFF6A1B9A),
  OrderStatus.preparing => const Color(0xFFF57C00),
  OrderStatus.completed => const Color(0xFF00838F),
  OrderStatus.paid => const Color(0xFF2E7D32),
  OrderStatus.cancelled => const Color(0xFF757575),
};

Color stockColor(Product product) {
  if (product.stock == 0 || product.status == ProductStatus.soldOut) {
    return const Color(0xFFC62828);
  }
  if (product.isLowStock) return const Color(0xFFEF6C00);
  return const Color(0xFF2E7D32);
}

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class ProductAvatar extends StatelessWidget {
  const ProductAvatar({super.key, required this.product, this.size = 48});

  final Product product;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (product.imageUrl.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          product.imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              _ProductIconAvatar(product: product, size: size),
        ),
      );
    }
    return _ProductIconAvatar(product: product, size: size);
  }
}

class _ProductIconAvatar extends StatelessWidget {
  const _ProductIconAvatar({required this.product, required this.size});

  final Product product;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = product.categoryId == 'c_food'
        ? const Color(0xFF00838F)
        : const Color(0xFF6A1B9A);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(_iconForProduct(product), color: color, size: size * 0.52),
    );
  }
}

IconData _iconForProduct(Product product) {
  final name = product.name.toLowerCase();
  if (name.contains('cà phê') || name.contains('bạc')) return Icons.local_cafe;
  if (name.contains('trà')) return Icons.local_drink;
  if (name.contains('sinh tố')) return Icons.blender;
  if (name.contains('cơm')) return Icons.rice_bowl;
  if (name.contains('mì')) return Icons.ramen_dining;
  return product.categoryId == 'c_food'
      ? Icons.restaurant
      : Icons.emoji_food_beverage;
}

Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Xác nhận',
  String cancelLabel = 'Hủy',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  )
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

void showStateSnackBar(BuildContext context, AppState state) {
  final message = state.message;
  final error = state.error;
  if (message == null && error == null) return;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message ?? error!),
        backgroundColor: error == null
            ? colorScheme.primary
            : colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
    state.consumeMessages();
  });
}
