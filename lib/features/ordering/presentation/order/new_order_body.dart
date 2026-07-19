part of '../order_screen.dart';

class _NewOrderBody extends StatelessWidget {
  const _NewOrderBody({
    required this.noteController,
    required this.onConfirmed,
    this.existingOrder,
    this.onCancel,
  });

  final TextEditingController noteController;
  final Order? existingOrder;
  final VoidCallback? onCancel;
  final VoidCallback onConfirmed;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return CustomScrollView(
      slivers: [
        if (existingOrder != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.add_shopping_cart),
                  title: const Text('Thêm món vào order hiện tại'),
                  subtitle: Text(
                    '${existingOrder!.totalQuantity} món hiện có · ${money(existingOrder!.total)}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Hủy thêm món',
                    onPressed: onCancel,
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                TextField(
                  onChanged: state.searchMenu,
                  decoration: const InputDecoration(
                    labelText: 'Tìm kiếm món',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 12),
                _CategoryFilter(state: state),
              ],
            ),
          ),
        ),
        if (state.filteredProducts.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.restaurant_menu,
              title: 'Không tìm thấy món',
              message: 'Thử đổi danh mục hoặc từ khóa tìm kiếm.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.crossAxisExtent;
                final count = width >= 900
                    ? 4
                    : width >= 640
                    ? 3
                    : 2;
                return SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _ProductCard(product: state.filteredProducts[index]),
                    childCount: state.filteredProducts.length,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: count,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 184,
                  ),
                );
              },
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: _CartPanel(
              noteController: noteController,
              isAddingItems: existingOrder != null,
              onConfirmed: onConfirmed,
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: const Text('Tất cả món'),
                selected: state.selectedCategoryId == 'all',
                onSelected: (_) => state.selectCategory('all'),
              ),
            ),
            for (final category in state.categories)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(category.name),
                  selected: state.selectedCategoryId == category.id,
                  onSelected: (_) => state.selectCategory(category.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final color = stockColor(product);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProductAvatar(product: product, size: 52),
                const Spacer(),
                StatusChip(
                  label: product.stock == 0 ? 'Hết' : 'Còn ${product.stock}',
                  color: color,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              product.shortDescription,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    money(product.price),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton.filled(
                  tooltip: 'Thêm ${product.name}',
                  onPressed: product.canOrder
                      ? () => state.addToCart(product)
                      : null,
                  icon: const Icon(Icons.add, size: 20),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CartPanel extends StatelessWidget {
  const _CartPanel({
    required this.noteController,
    required this.isAddingItems,
    required this.onConfirmed,
  });

  final TextEditingController noteController;
  final bool isAddingItems;
  final VoidCallback onConfirmed;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final table = state.selectedTable;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Giỏ hàng ${table == null ? '' : '· ${table.name}'}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                StatusChip(
                  label: '${state.cartItems.length} món',
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (state.cartItems.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: EmptyState(
                  icon: Icons.shopping_cart_outlined,
                  title: 'Giỏ hàng trống',
                  message: 'Chọn món trong menu để tạo order.',
                ),
              )
            else ...[
              for (final item in state.cartItems) _CartItemTile(item: item),
              const Divider(height: 24),
              TextField(
                controller: noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú order',
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tổng tiền',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    money(state.cartTotal),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () async {
                  final order = await state.confirmOrder(noteController.text);
                  if (order != null) {
                    noteController.clear();
                    onConfirmed();
                  }
                },
                icon: const Icon(Icons.check_circle),
                label: Text(
                  isAddingItems ? 'Xác nhận thêm món' : 'Xác nhận order',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final product = state.productById(item.productId);
    final canIncrease =
        product?.canOrder == true && item.quantity < (product?.stock ?? 0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(money(item.total)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Giảm',
                onPressed: () => state.decreaseCartItem(item.productId),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              SizedBox(
                width: 28,
                child: Text(
                  '${item.quantity}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Tăng',
                onPressed: canIncrease
                    ? () => state.increaseCartItem(item.productId)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
              IconButton(
                tooltip: 'Xóa món',
                onPressed: () => state.removeCartItem(item.productId),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.button),
            onTap: () => _editNote(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Row(
                children: [
                  Icon(
                    item.note.isEmpty ? Icons.note_add_outlined : Icons.notes,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.note.isEmpty ? 'Thêm ghi chú cho món' : item.note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: item.note.isEmpty
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontStyle: item.note.isEmpty
                            ? FontStyle.normal
                            : FontStyle.italic,
                      ),
                    ),
                  ),
                  const Icon(Icons.edit_outlined, size: 17),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editNote(BuildContext context) async {
    final controller = TextEditingController(text: item.note);
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Ghi chú cho ${item.productName}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 120,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Ví dụ: ít đá, không hành, ít cay...',
            prefixIcon: Icon(Icons.notes),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Lưu'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (note == null || !context.mounted) return;
    context.read<AppState>().updateCartItemNote(item.productId, note);
  }
}
