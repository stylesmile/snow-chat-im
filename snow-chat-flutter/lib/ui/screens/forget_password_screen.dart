import 'dart:async';

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import 'login_screen.dart';

/// 忘记密码页面：输入邮箱 → 获取验证码 → 输入新密码 → 重置成功跳转登录
class ForgetPasswordScreen extends StatefulWidget {
  const ForgetPasswordScreen({super.key});

  @override
  State<ForgetPasswordScreen> createState() => _ForgetPasswordScreenState();
}

class _ForgetPasswordScreenState extends State<ForgetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _sendingCode = false;
  int _countdown = 0; // 倒计时剩余秒数，0 表示可发送
  Timer? _countdownTimer;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  /// 步骤：0=输入邮箱，1=输入验证码+新密码
  int _step = 0;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// 发送验证码到邮箱（POST /chat/user/send/email/code?type=reset_password）
  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.invalidEmail), backgroundColor: Colors.orange.shade700),
      );
      return;
    }
    setState(() => _sendingCode = true);
    final success = await context.read<AuthProvider>().sendVerificationCode(email, 'reset_password');
    setState(() => _sendingCode = false);
    if (!mounted) return;
    if (success) {
      _startCountdown();
      setState(() => _step = 1);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.codeSendFailed),
            backgroundColor: Colors.red.shade700, duration: const Duration(seconds: 3)),
      );
    }
  }

  /// 启动60秒倒计时
  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdown = 60;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        if (_countdown <= 1) { _countdown = 0; timer.cancel(); }
        else { _countdown--; }
      });
    });
  }

  /// 提交重置密码（POST /chat/user/reset/password）
  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;
    if (_newPasswordController.text != _confirmPasswordController.text) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.passwordNotMatch), duration: const Duration(seconds: 3)),
      );
      return;
    }

    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();
    final success = await auth.resetPassword(
      _emailController.text.trim(),
      _codeController.text.trim(),
      _newPasswordController.text,
    );
    setState(() => _isLoading = false);

    if (!mounted) return;
    if (success) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.passwordResetSuccess)),
      );
      // 重置完成后跳转登录页
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.lastError ?? AppLocalizations.of(context)!.codeExpired),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.resetPassword),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [primary.withAlpha(45), primary.withAlpha(18), AppTheme.background],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 96, height: 96,
                      decoration: BoxDecoration(color: primary.withAlpha(51), shape: BoxShape.circle),
                      child: Icon(Icons.admin_panel_settings_rounded, size: 48, color: primary),
                    ),
                    const SizedBox(height: 20),
                    Text(l10n.resetPassword, textAlign: TextAlign.center,
                        style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold, color: primary)),
                    const SizedBox(height: 8),
                    Text(
                      _step == 0 ? '请输入注册时使用的邮箱' : '请输入验证码和新密码',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 32),

                    // 步骤1：邮箱输入
                    TextFormField(
                      controller: _emailController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(labelText: l10n.email,
                          prefixIcon: Icon(Icons.email_outlined, color: primary)),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.isEmpty) return l10n.invalidEmail;
                        if (!v.contains('@')) return l10n.invalidEmail;
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    if (_step == 0)
                      ElevatedButton(
                        onPressed: _sendingCode ? null : _sendCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _sendingCode || _countdown > 0
                            ? Text(_countdown > 0 ? "${_countdown}s" : "...", style: const TextStyle(fontSize: 13))
                            : Text(l10n.sendCode),
                      )
                    else ...[
                      // 步骤2：验证码 + 新密码 + 确认密码
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _codeController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(labelText: l10n.verificationCode,
                                  prefixIcon: Icon(Icons.security_outlined, color: primary)),
                              keyboardType: const TextInputType.numberWithOptions(signed: true),
                              validator: (v) => v == null || v.isEmpty ? l10n.codeExpired : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // 可重新发送验证码按钮
                          _sendingCode || _countdown > 0
                              ? const SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 2))
                              : IconButton(
                                  icon: const Icon(Icons.refresh),
                                  color: primary,
                                  onPressed: _countdown > 0 ? null : _sendCode,
                                  tooltip: l10n.sendCode,
                                ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: _obscureNewPassword,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: l10n.newPassword,
                          prefixIcon: Icon(Icons.lock_outline, color: primary),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureNewPassword ? Icons.visibility_off : Icons.visibility, color: Colors.white70),
                            onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                          ),
                        ),
                        validator: (v) => v == null || v.isEmpty ? l10n.invalidPassword : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: l10n.confirmPassword,
                          prefixIcon: Icon(Icons.lock_outline, color: primary),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: Colors.white70),
                            onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                          ),
                        ),
                        validator: (v) => v == null || v.isEmpty ? l10n.confirmPasswordRequired : null,
                        onFieldSubmitted: (_) => _handleReset(),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleReset,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(height: 20, width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(l10n.resetPassword,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ],

                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (_) => false,
                      ),
                      style: TextButton.styleFrom(foregroundColor: primary),
                      child: Text(l10n.backToLogin),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
