import 'package:flutter/material.dart';

import '../../domain/models/app_models.dart';
import '../../features/catalog/data/product_image_local_service.dart';
import '../../app/state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

Color tableStatusColor(TableStatus status) => switch (status) {
  TableStatus.available => AppColors.success,
  TableStatus.ordering => AppColors.warning,
  TableStatus.paid => AppColors.paid,
};

Color orderStatusColor(OrderStatus status) => switch (status) {
  OrderStatus.pending => AppColors.info,
  OrderStatus.preparing => AppColors.warning,
  OrderStatus.completed => AppColors.paid,
  OrderStatus.paid => AppColors.success,
  OrderStatus.cancelled => AppColors.neutral,
};

Color stockColor(Product product) {
  if (product.stock == 0 || product.status == ProductStatus.soldOut) {
    return AppColors.danger;
  }
  if (product.isLowStock) return AppColors.warning;
  return AppColors.success;
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.status),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
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
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 19),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleLarge?.copyWith(
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xxs),
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppTextStyles.sectionTitle)),
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
    final imageValue = product.imageUrl.trim();
    final localImageBytes = ProductImageLocalService.tryDecodeDataUrl(
      imageValue,
    );

    if (localImageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.small),
        child: Image.memory(
          localImageBytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              _ProductIconAvatar(product: product, size: size),
        ),
      );
    }

    if (imageValue.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.small),
        child: Image.network(
          imageValue,
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
        ? AppColors.paid
        : AppColors.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.small),
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
