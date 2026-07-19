# Kiến trúc Mini Order App

Project sử dụng cấu trúc lai giữa Clean Architecture và feature-first. Mục tiêu
là giữ phần nghiệp vụ độc lập với Firebase và chia giao diện theo chức năng.

## Các lớp chính

- `lib/app`: composition và trạng thái điều phối toàn ứng dụng.
- `lib/core`: cấu hình, Firebase options, tiện ích và widget dùng chung.
- `lib/domain`: model và repository contract thuần nghiệp vụ.
- `lib/data`: triển khai repository và cơ chế lưu trữ dùng chung.
- `lib/features`: code riêng của từng nghiệp vụ.

## Các feature

- `access_control`: duyệt tài khoản Google và quản trị tài khoản.
- `administration`: dashboard, quản lý và lịch sử dành cho Admin.
- `authentication`: đăng nhập và quên mật khẩu.
- `catalog`: ảnh và dữ liệu hỗ trợ sản phẩm.
- `ordering`: giỏ hàng, order, phiếu bếp và giao dịch Firestore của order.
- `payments`: thanh toán tiền mặt và VietQR.
- `reporting`: báo cáo và xuất file.
- `staff`: trang tổng quan bàn, order đang hoạt động và cảnh báo.

## Quy tắc đặt code

1. Model và quy tắc dữ liệu chung đặt trong `domain`.
2. Firebase, SharedPreferences và triển khai repository đặt trong `data` hoặc
   thư mục `data` của feature tương ứng.
3. Màn hình và widget chỉ dùng cho một nghiệp vụ đặt trong
   `features/<feature>/presentation`.
4. Widget hoặc formatter được nhiều feature sử dụng đặt trong `core`.
5. Không đưa thêm nghiệp vụ mới trực tiếp vào `main.dart`.
6. Sau mỗi thay đổi phải chạy `dart format`, `flutter analyze` và
   `flutter test`.
