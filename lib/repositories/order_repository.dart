import '../models/app_models.dart';

abstract class OrderRepository {
  List<AppUser> get users;
  List<Area> get areas;
  List<RestaurantTable> get tables;
  List<Category> get categories;
  List<Product> get products;
  List<Order> get orders;
  List<Payment> get payments;

  AppUser? authenticate(String email, String password);

  Area? findArea(String id);
  RestaurantTable? findTable(String id);
  Category? findCategory(String id);
  Product? findProduct(String id);
  Order? findOrder(String id);
  Payment? findPayment(String id);
  Order? activeOrderForTable(String tableId);
  Payment? latestPaymentForOrder(String orderId);

  void upsertUser(AppUser user, {String password});
  void deleteUser(String id);
  void upsertArea(Area area);
  void deleteArea(String id);
  void upsertTable(RestaurantTable table);
  void deleteTable(String id);
  void upsertCategory(Category category);
  void deleteCategory(String id);
  void upsertProduct(Product product);
  void deleteProduct(String id);
  void updateProductStock(String productId, int stock);
  void addOrder(Order order);
  void updateOrder(Order order);
  void addPayment(Payment payment);
  void updatePayment(Payment payment);

  int revenueForDay(DateTime day);
  Map<String, int> soldQuantities();
}

abstract class PersistentOrderRepository extends OrderRepository {
  Future<void> restoreSavedData();
  Future<void> persistNow();
  Future<void> resetToSeedData();
  String exportBackupJson();
}
