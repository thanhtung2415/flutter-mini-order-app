import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.receipt_long,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Flutter Mini Order App',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Quản lý order nội bộ cho quán nhỏ',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Consumer<AppState>(
                        builder: (context, state, _) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Đăng nhập',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 16),
                              if (kDebugMode)
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ChoiceChip(
                                      avatar: const Icon(
                                        Icons.admin_panel_settings,
                                        size: 18,
                                      ),
                                      label: const Text('Admin'),
                                      selected:
                                          _emailController.text ==
                                          'admin@miniorder.vn',
                                      onSelected: _isSubmitting
                                          ? null
                                          : (_) =>
                                                _fillDemo('admin@miniorder.vn'),
                                    ),
                                    ChoiceChip(
                                      avatar: const Icon(Icons.badge, size: 18),
                                      label: const Text('Nhân viên'),
                                      selected:
                                          _emailController.text ==
                                          'staff@miniorder.vn',
                                      onSelected: _isSubmitting
                                          ? null
                                          : (_) =>
                                                _fillDemo('staff@miniorder.vn'),
                                    ),
                                  ],
                                ),
                              if (kDebugMode) const SizedBox(height: 16),
                              TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.mail_outline),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                onSubmitted: (_) => _submit(context),
                                decoration: InputDecoration(
                                  labelText: 'Mật khẩu',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    tooltip: _obscurePassword
                                        ? 'Hiện mật khẩu'
                                        : 'Ẩn mật khẩu',
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed:
                                      _isSubmitting || _isResettingPassword
                                      ? null
                                      : _showForgotPasswordDialog,
                                  icon: const Icon(Icons.lock_reset),
                                  label: Text(
                                    _isResettingPassword
                                        ? 'Đang gửi...'
                                        : 'Quên mật khẩu?',
                                  ),
                                ),
                              ),
                              if (state.error != null) ...[
                                const SizedBox(height: 12),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: colorScheme.errorContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(
                                      state.error!,
                                      style: TextStyle(
                                        color: colorScheme.onErrorContainer,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 18),
                              FilledButton.icon(
                                onPressed: _isSubmitting
                                    ? null
                                    : () => _submit(context),
                                icon: _isSubmitting
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.login),
                                label: Text(
                                  _isSubmitting
                                      ? 'Đang xác thực...'
                                      : 'Đăng nhập',
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Expanded(child: Divider()),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(
                                      'hoặc',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                                  const Expanded(child: Divider()),
                                ],
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _isSubmitting
                                    ? null
                                    : () => _submitGoogle(context),
                                icon: const Icon(Icons.g_mobiledata, size: 28),
                                label: const Text('Tiếp tục với Google'),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Tài khoản demo dùng mật khẩu 123456',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
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
