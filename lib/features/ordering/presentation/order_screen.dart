import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/app_models.dart';
import '../../../app/state/app_state.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import 'kitchen_preview_screen.dart';
import '../../payments/presentation/payment_screen.dart';

part 'order/new_order_body.dart';
part 'order/existing_order_body.dart';
part 'order/table_order_history.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key, required this.tableId});

  final String tableId;

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final _noteController = TextEditingController();
  bool _isAddingItems = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().selectTable(widget.tableId);
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        showStateSnackBar(context, state);
        final table = state.tableById(widget.tableId);
        final order = state.orderForTable(widget.tableId);
        if (table == null) {
          return const Scaffold(
            body: EmptyState(
              icon: Icons.table_bar,
              title: 'Không tìm thấy bàn',
              message: 'Vui lòng quay lại danh sách bàn.',
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(table.name),
                Text(
                  table.status.label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            actions: [
              if (order != null &&
                  order.isActive &&
                  state.canManageOrder(order) &&
                  !_isAddingItems)
                IconButton(
                  tooltip: 'Thêm món',
                  onPressed: () => setState(() => _isAddingItems = true),
                  icon: const Icon(Icons.add_shopping_cart),
                ),
              if ((order == null || _isAddingItems) &&
                  state.cartItems.isNotEmpty)
                IconButton(
                  tooltip: 'Xóa giỏ hàng',
                  onPressed: state.clearCart,
                  icon: const Icon(Icons.remove_shopping_cart_outlined),
                ),
            ],
          ),
          body: order == null || _isAddingItems
              ? _NewOrderBody(
                  noteController: _noteController,
                  existingOrder: order,
                  onCancel: order == null
                      ? null
                      : () {
                          state.clearCart();
                          _noteController.clear();
                          setState(() => _isAddingItems = false);
                        },
                  onConfirmed: () {
                    if (order != null) {
                      setState(() => _isAddingItems = false);
                    }
                  },
                )
              : _ExistingOrderBody(
                  order: order,
                  onAddItems: state.canManageOrder(order)
                      ? () => setState(() => _isAddingItems = true)
                      : null,
                ),
        );
      },
    );
  }
}
