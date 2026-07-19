part of '../admin_home_screen.dart';

class ProductsAdminTab extends StatelessWidget {
  const ProductsAdminTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        SectionTitle(
          title: 'Món ăn và tồn kho',
          action: IconButton.filled(
            tooltip: 'Thêm món',
            onPressed: () => _showProductDialog(context),
            icon: const Icon(Icons.add),
          ),
        ),
        for (final product in state.products)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ProductAvatar(product: product),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '${money(product.price)} · Tồn ${product.stock} · ${product.status.label}',
                          ),
                          Text(
                            state.categoryById(product.categoryId)?.name ??
                                'Chưa có danh mục',
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Giảm tồn',
                      onPressed: () =>
                          context.read<AppState>().adjustStock(product.id, -1),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    IconButton(
                      tooltip: 'Tăng tồn',
                      onPressed: () =>
                          context.read<AppState>().adjustStock(product.id, 1),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'edit') {
                          _showProductDialog(context, existing: product);
                        } else if (value == 'delete') {
                          final confirmed = await showConfirmDialog(
                            context: context,
                            title: 'Xóa món?',
                            message:
                                'Món ${product.name} sẽ không còn hiển thị trong menu.',
                            confirmLabel: 'Xóa',
                            destructive: true,
                          );
                          if (confirmed && context.mounted) {
                            context.read<AppState>().deleteProduct(product.id);
                          }
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Sửa')),
                        PopupMenuItem(value: 'delete', child: Text('Xóa')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showProductDialog(BuildContext context, {Product? existing}) {
    final state = context.read<AppState>();
    if (state.categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cần tạo ít nhất một danh mục trước khi thêm món.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final name = TextEditingController(text: existing?.name ?? '');
    final description = TextEditingController(
      text: existing?.shortDescription ?? '',
    );
    final imageUrl = TextEditingController(text: existing?.imageUrl ?? '');
    final price = TextEditingController(text: '${existing?.price ?? 0}');
    final stock = TextEditingController(text: '${existing?.stock ?? 0}');
    final warning = TextEditingController(
      text: '${existing?.warningThreshold ?? 5}',
    );
    final productId =
        existing?.id ?? 'P${DateTime.now().millisecondsSinceEpoch % 100000}';
    final imagePicker = ImagePicker();
    final imageLocalService = ProductImageLocalService();
    var categoryId = existing?.categoryId ?? state.categories.first.id;
    var status = existing?.status ?? ProductStatus.available;
    var pickingImage = false;
    String? imagePickError;

    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? 'Thêm món' : 'Sửa món'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Tên món'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: description,
                      decoration: const InputDecoration(
                        labelText: 'Mô tả ngắn',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: imageUrl,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Link ảnh món hoặc ảnh local',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: pickingImage
                            ? null
                            : () async {
                                final source =
                                    await showModalBottomSheet<ImageSource>(
                                      context: context,
                                      builder: (context) {
                                        return SafeArea(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ListTile(
                                                leading: const Icon(
                                                  Icons.photo_library_outlined,
                                                ),
                                                title: const Text(
                                                  'Chọn từ thư viện ảnh',
                                                ),
                                                onTap: () => Navigator.pop(
                                                  context,
                                                  ImageSource.gallery,
                                                ),
                                              ),
                                              ListTile(
                                                leading: const Icon(
                                                  Icons.photo_camera_outlined,
                                                ),
                                                title: const Text(
                                                  'Chụp bằng camera',
                                                ),
                                                onTap: () => Navigator.pop(
                                                  context,
                                                  ImageSource.camera,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                if (source == null) return;

                                final pickedFile = await imagePicker.pickImage(
                                  source: source,
                                  imageQuality: 70,
                                  maxWidth: 900,
                                );
                                if (pickedFile == null) return;

                                setDialogState(() {
                                  pickingImage = true;
                                  imagePickError = null;
                                });

                                try {
                                  final bytes = await pickedFile.readAsBytes();
                                  final dataUrl = imageLocalService
                                      .buildDataUrl(
                                        bytes: bytes,
                                        contentType: pickedFile.mimeType,
                                      );
                                  if (!context.mounted) return;
                                  setDialogState(() {
                                    imageUrl.text = dataUrl;
                                    pickingImage = false;
                                  });
                                } catch (error) {
                                  if (!context.mounted) return;
                                  setDialogState(() {
                                    pickingImage = false;
                                    imagePickError =
                                        'Không đọc được ảnh đã chọn.';
                                  });
                                }
                              },
                        icon: pickingImage
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add_photo_alternate_outlined),
                        label: Text(
                          pickingImage
                              ? 'Đang xử lý ảnh...'
                              : 'Chọn/chụp ảnh lưu local',
                        ),
                      ),
                    ),
                    if (imagePickError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        imagePickError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextField(
                      controller: price,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Giá'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: stock,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Tồn kho'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: warning,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Ngưỡng cảnh báo',
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: categoryId,
                      decoration: const InputDecoration(labelText: 'Danh mục'),
                      items: state.categories
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setDialogState(
                        () => categoryId = value ?? categoryId,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<ProductStatus>(
                      initialValue: status,
                      decoration: const InputDecoration(
                        labelText: 'Trạng thái',
                      ),
                      items: ProductStatus.values
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => status = value ?? status),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () {
                    final now = DateTime.now();
                    final product = Product(
                      id: productId,
                      name: name.text.trim(),
                      price: int.tryParse(price.text.trim()) ?? 0,
                      imageUrl: imageUrl.text.trim(),
                      shortDescription: description.text.trim(),
                      categoryId: categoryId,
                      stock: int.tryParse(stock.text.trim()) ?? 0,
                      warningThreshold: int.tryParse(warning.text.trim()) ?? 5,
                      status: status,
                      createdAt: existing?.createdAt ?? now,
                      updatedAt: now,
                    );
                    if (state.upsertProduct(product)) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
