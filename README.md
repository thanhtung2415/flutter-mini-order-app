# Flutter Mini Order App

Ứng dụng quản lý order nội bộ cho quán nhỏ, được xây dựng bằng Flutter theo SRS của đồ án Phát triển ứng dụng di động.

## Phạm vi nền tảng mobile

- Đây là **Flutter mobile app** viết bằng Dart, sử dụng giao diện Material 3.
- Android là nền tảng triển khai và demo final; package là `vn.umt.mini_order_app` và APK release được cung cấp cùng bài nộp.
- Source có Flutter host project cho iOS để thể hiện kiến trúc đa nền tảng. Firebase iOS chưa được đăng ký/cấu hình, vì vậy chỉ công bố iOS là hướng mở rộng, chưa phải nền tảng đã nghiệm thu.
- Web, Windows, macOS và Linux không thuộc phạm vi final. Khi chạy demo phải chọn Android emulator hoặc điện thoại Android, không chọn Windows desktop.

## Tài khoản demo Firebase (chỉ bản debug)

- Admin: `admin@miniorder.vn` / `123456`
- Nhân viên: `staff@miniorder.vn` / `123456`

Hai tài khoản được xác thực bằng Firebase Authentication. Vai trò, trạng thái tài khoản và dữ liệu nghiệp vụ được quản lý trong ứng dụng.

## Chức năng chính

- Đăng nhập Email/Password hoặc Google và phân quyền Admin/Nhân viên theo UID.
- Gmail Google mới tự tạo yêu cầu chờ duyệt, bị đăng xuất và chỉ truy cập
  sau khi Admin cấp vai trò; Admin có thể duyệt hoặc từ chối ngay trong app.
- Các collection nghiệp vụ được theo dõi realtime để những thiết bị đang
  đăng nhập tự tải lại bàn, món, order, thanh toán và trạng thái tài khoản.
- Quản lý khu vực, bàn, người dùng, danh mục, món, ảnh món và tồn kho.
- Chọn bàn, tìm món, giỏ hàng, tính tiền, xác nhận order và trừ tồn kho.
- Gửi bếp, preview/copy phiếu bếp và xuất PDF.
- Trạng thái order, cảnh báo tồn kho và cảnh báo đơn quá 10 phút.
- Thanh toán QR hiệu lực 15 phút hoặc tiền mặt; xác nhận và dọn bàn.
- Xem người tạo order, lịch sử order theo bàn và chuyển order sang bàn trống.
- Dashboard doanh thu, món bán chạy và lịch sử thanh toán.
- Lọc báo cáo theo khoảng ngày; xuất CSV, Excel và PDF.
- Backup JSON và reset dữ liệu mẫu có xác nhận.

## Kiến trúc và dữ liệu

- `View`: các màn hình Flutter cho Admin và Nhân viên.
- `AppState`: ViewModel dùng Provider/ChangeNotifier.
- `OrderRepository`: quản lý nghiệp vụ và dữ liệu trong bộ nhớ.
- `FirebaseAuthenticationService`: đăng nhập Email/Password hoặc Google bằng Firebase Authentication.
- `FirestoreDatabaseStorage`: tải toàn bộ collection, gồm hồ sơ `users`; client chỉ ghi dữ liệu nghiệp vụ.
- `FirebaseUserAdministrationService`: gọi Cloud Functions để tạo/sửa/khóa/xóa cả Firebase Authentication và hồ sơ `users/{uid}`.
- `FirebaseAccessRequestService`: gửi và theo dõi yêu cầu cấp quyền Google;
  Admin duyệt vai trò thông qua Cloud Functions.
- `FirestoreOrderTransactionService`: dùng transaction khi tạo order, trừ tồn, tạo thanh toán, chuyển bàn và xác nhận thanh toán.
- `SharedPreferences`: cache local-first và lưu giỏ hàng nháp để demo ổn định khi mạng gián đoạn.

Ảnh món được chọn từ thư viện/camera hoặc nhập URL và lưu dạng data URL. Firebase Storage không thuộc baseline final.

## Cấu hình Firebase

Project Firebase: `mini-order-app-umt`

```powershell
firebase use mini-order-app-umt
cd functions
npm ci
npm run build
cd ..
firebase deploy --only functions,firestore:rules,firestore:indexes
```

Firestore và Functions Node.js 22 được triển khai tại `asia-southeast1` trên project Blaze. Rules trong `firestore.rules` kiểm tra hồ sơ `active`, phân quyền theo collection và không cho client ghi collection `users`.

## Chạy và kiểm tra

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
flutter build apk --release
```

APK được tạo tại:

```text
build/app/outputs/flutter-apk/app-release.apk
```
