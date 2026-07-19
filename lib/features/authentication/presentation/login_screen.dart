import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController(
    text: kDebugMode ? 'admin@miniorder.vn' : '',
  );
  final _passwordController = TextEditingController(
    text: kDebugMode ? '123456' : '',
  );
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  bool _isResettingPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final topInset = MediaQuery.paddingOf(context).top;
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Stack(
                children: [
                  _LoginHero(topInset: topInset),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      252 + topInset,
                      AppSpacing.md,
                      AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Consumer<AppState>(
                          builder: (context, state, _) => _LoginFormPanel(
                            state: state,
                            emailController: _emailController,
                            passwordController: _passwordController,
                            obscurePassword: _obscurePassword,
                            isSubmitting: _isSubmitting,
                            isResettingPassword: _isResettingPassword,
                            onEmailChanged: (_) => setState(() {}),
                            onTogglePassword: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            onFillDemo: _fillDemo,
                            onForgotPassword: _showForgotPasswordDialog,
                            onSubmit: () => _submit(context),
                            onSubmitGoogle: () => _submitGoogle(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _fillDemo(String email) {
    setState(() {
      _emailController.text = email;
      _passwordController.text = '123456';
    });
  }

  Future<void> _submit(BuildContext context) async {
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);
    await context.read<AppState>().login(
      _emailController.text,
      _passwordController.text,
    );
    if (mounted) setState(() => _isSubmitting = false);
  }

  Future<void> _submitGoogle(BuildContext context) async {
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);
    await context.read<AppState>().loginWithGoogle();
    if (mounted) setState(() => _isSubmitting = false);
  }

  Future<void> _showForgotPasswordDialog() async {
    final email = await showDialog<String>(
      context: context,
      builder: (_) =>
          _ForgotPasswordDialog(initialEmail: _emailController.text),
    );
    if (email == null || !mounted) return;

    FocusScope.of(context).unfocus();
    setState(() => _isResettingPassword = true);
    final state = context.read<AppState>();
    final sent = await state.requestPasswordReset(email);
    if (!mounted) return;
    setState(() => _isResettingPassword = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sent
              ? 'Nếu email tồn tại, hướng dẫn đặt lại mật khẩu đã được gửi.'
              : state.error ?? 'Không thể gửi email đặt lại mật khẩu.',
        ),
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero({required this.topInset});

  final double topInset;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const _LoginWaveClipper(),
      child: Container(
        width: double.infinity,
        height: 330 + topInset,
        color: AppColors.primary,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                topInset + AppSpacing.lg,
                AppSpacing.lg,
                84,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.32),
                      ),
                    ),
                    child: const Icon(
                      Icons.receipt_long_outlined,
                      color: Colors.white,
                      size: 27,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'Flutter Mini Order App',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 29,
                      height: 1.12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Nhanh gọn cho từng đơn hàng',
                    style: AppTextStyles.body.copyWith(
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginFormPanel extends StatelessWidget {
  const _LoginFormPanel({
    required this.state,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.isSubmitting,
    required this.isResettingPassword,
    required this.onEmailChanged,
    required this.onTogglePassword,
    required this.onFillDemo,
    required this.onForgotPassword,
    required this.onSubmit,
    required this.onSubmitGoogle,
  });

  final AppState state;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool isSubmitting;
  final bool isResettingPassword;
  final ValueChanged<String> onEmailChanged;
  final VoidCallback onTogglePassword;
  final ValueChanged<String> onFillDemo;
  final VoidCallback onForgotPassword;
  final VoidCallback onSubmit;
  final VoidCallback onSubmitGoogle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.dialog),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Đăng nhập',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              height: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          const Text(
            'Chào mừng bạn trở lại hệ thống',
            style: AppTextStyles.caption,
          ),
          if (kDebugMode) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                ChoiceChip(
                  avatar: const Icon(
                    Icons.admin_panel_settings_outlined,
                    size: 17,
                  ),
                  label: const Text('Admin'),
                  selected: emailController.text == 'admin@miniorder.vn',
                  onSelected: isSubmitting
                      ? null
                      : (_) => onFillDemo('admin@miniorder.vn'),
                ),
                ChoiceChip(
                  avatar: const Icon(Icons.badge_outlined, size: 17),
                  label: const Text('Nhân viên'),
                  selected: emailController.text == 'staff@miniorder.vn',
                  onSelected: isSubmitting
                      ? null
                      : (_) => onFillDemo('staff@miniorder.vn'),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('EMAIL'),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onChanged: onEmailChanged,
            decoration: const InputDecoration(
              hintText: 'name@miniorder.vn',
              prefixIcon: Icon(Icons.mail_outline),
              fillColor: AppColors.background,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('MẬT KHẨU'),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: passwordController,
            obscureText: obscurePassword,
            onSubmitted: (_) => onSubmit(),
            decoration: InputDecoration(
              hintText: 'Nhập mật khẩu',
              prefixIcon: const Icon(Icons.lock_outline),
              fillColor: AppColors.background,
              suffixIcon: IconButton(
                tooltip: obscurePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                onPressed: onTogglePassword,
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: isSubmitting || isResettingPassword
                  ? null
                  : onForgotPassword,
              icon: const Icon(Icons.lock_reset, size: 18),
              label: Text(
                isResettingPassword ? 'Đang gửi...' : 'Quên mật khẩu?',
              ),
            ),
          ),
          if (state.error != null) ...[
            DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Text(
                  state.error!,
                  style: TextStyle(color: colorScheme.onErrorContainer),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isSubmitting ? null : onSubmit,
              icon: isSubmitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: Text(isSubmitting ? 'Đang xác thực...' : 'Đăng nhập'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Text('hoặc tiếp tục với', style: AppTextStyles.caption),
              ),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isSubmitting ? null : onSubmitGoogle,
              icon: const Text(
                'G',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              label: const Text('Tiếp tục với Google'),
            ),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Tài khoản demo dùng mật khẩu 123456',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            ),
          ],
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.caption.copyWith(
        color: AppColors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _LoginWaveClipper extends CustomClipper<Path> {
  const _LoginWaveClipper();

  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(0, size.height - 64)
      ..quadraticBezierTo(
        size.width * 0.52,
        size.height + 32,
        size.width,
        size.height - 86,
      )
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({required this.initialEmail});

  final String initialEmail;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late String _email;

  @override
  void initState() {
    super.initState();
    _email = widget.initialEmail;
  }

  void _submit() {
    Navigator.of(context).pop(_email.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Đặt lại mật khẩu'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nhập email của tài khoản Email/Password. Firebase sẽ gửi liên kết tạo mật khẩu mới.',
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('forgot-password-email'),
            initialValue: widget.initialEmail,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.mail_outline),
            ),
            onChanged: (value) => _email = value,
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          Text(
            'Tài khoản Google cần khôi phục mật khẩu tại Google. Email demo @miniorder.vn không có hộp thư thật để nhận liên kết.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('forgot-password-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton.icon(
          key: const Key('forgot-password-send'),
          onPressed: _submit,
          icon: const Icon(Icons.send_outlined),
          label: const Text('Gửi email'),
        ),
      ],
    );
  }
}
