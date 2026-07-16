# Hoàn thiện backend và bản final 1.3

## Bước 2 — An toàn đăng nhập release

- Chế độ đăng nhập demo offline chỉ hoạt động trong debug (`kReleaseMode == false`).
- Bản release không điền sẵn email/mật khẩu và không hiển thị tài khoản demo.
- Khi mất mạng, bản release trả lỗi Firebase thay vì chấp nhận mật khẩu `123456`.

## Bước 3 — FR-03 và Firebase Authentication

- Thêm callable Cloud Functions trong `functions/src/index.ts`:
  - `adminCreateUser`
  - `adminUpdateUser`
  - `adminSetUserDisabled`
  - `adminDeleteUser`
- Function kiểm tra người gọi có hồ sơ `users/{uid}` với `vaiTro == admin` và `trangThai == active`.
- Tài khoản mới được tạo đồng thời trong Firebase Authentication và Firestore với Document ID bằng Auth UID.
- Khóa/mở khóa cập nhật cả `disabled` của Firebase Authentication và `trangThai` Firestore.
- Không cho xóa tài khoản đang đăng nhập hoặc tài khoản đã có lịch sử order.
- Cloud Functions đã được triển khai bằng Node.js 22 tại `asia-southeast1`.

## Google Sign-In

- Đã thêm `google_sign_in`, SHA-1/SHA-256 và OAuth client Android/Web.
- Google chỉ xác thực danh tính; ứng dụng vẫn yêu cầu hồ sơ `users/{uid}` active để xác định vai trò.
- Email/Password được giữ làm phương thức đăng nhập chính và dự phòng.

## Bước 4 — Transaction cho nghiệp vụ đồng thời

`FirestoreOrderTransactionService` dùng Firestore transaction cho:

- Tạo order + kiểm tra/trừ tồn kho + giữ bàn.
- Tạo payment và thay thế payment chờ cũ.
- Chuyển order giữa hai bàn và làm hết hạn payment chờ.
- Xác nhận payment + đóng order + cập nhật trạng thái bàn.

Sau khi transaction thành công, local cache được cập nhật mà không phát sinh ngay một snapshot cloud có thể ghi đè kết quả của thiết bị khác.

## Kết quả kiểm tra

- `flutter analyze`: không có lỗi.
- `flutter test`: 21/21 test đạt.
- `npm run build` trong `functions`: TypeScript biên dịch thành công.
- `flutter build apk --release`: thành công.

## Triển khai backend

Cloud Functions, Rules và indexes đã được triển khai. Lệnh triển khai lại:

```powershell
firebase use mini-order-app-umt
cd functions
npm ci
npm run build
cd ..
firebase deploy --only functions,firestore:rules,firestore:indexes
```

Kiểm thử E2E đã đạt chuỗi tạo -> khóa -> mở -> xóa tài khoản Auth; tài khoản kiểm thử tạm đã được dọn.
# Bổ sung bản 1.3.1+4

- Gmail Google chưa có hồ sơ `users/{uid}` được ghi vào
  `access_requests/{uid}` với trạng thái `pending`, sau đó đăng xuất.
- Admin nhận danh sách yêu cầu theo thời gian thực và có thể cấp quyền
  Admin/Nhân viên hoặc từ chối.
- Hai callable Functions mới: `requestGoogleAccess` và
  `adminReviewGoogleAccess`.
- Listener Firestore có debounce giúp các thiết bị đang đăng nhập tự đồng bộ
  các collection nghiệp vụ; transaction vẫn là lớp bảo vệ xung đột cho order,
  tồn kho, chuyển bàn và thanh toán.
