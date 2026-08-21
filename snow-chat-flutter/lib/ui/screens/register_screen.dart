import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/api_constants.dart';
import 'home_screen.dart';
import 'forget_password_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _sendingCode = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nicknameController.dispose();
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  /// 发送验证码到邮箱
  /// 调用 POST /chat/user/send/email/code?type=register
  Future<void> _sendVerificationCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.invalidEmail), backgroundColor: Colors.orange.shade700),
      );
      return;
    }
    setState(() => _sendingCode = true);
    final success = await context.read<AuthProvider>().sendVerificationCode(email, 'register');
    setState(() => _sendingCode = false);
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.codeSent)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.codeSendFailed), backgroundColor: Colors.red.shade700),
      );
    }
  }

  /// 处理注册提交
  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.passwordNotMatch)),
      );
      return;
    }

    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      _usernameController.text.trim(),
      _passwordController.text,
      _nicknameController.text.trim().isEmpty ? _usernameController.text.trim() : _nicknameController.text.trim(),
      _emailController.text.trim(),
      _codeController.text.trim(),
    );
    setState(() => _isLoading = false);

    if (!mounted) return;
    if (success) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.registerSuccess)),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.lastError ?? AppLocalizations.of(context)!.registerFailed),
          backgroundColor: Colors.red.shade700,
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
        title: Text(l10n.register),
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
                    // Logo 图标
                    Container(
                      width: 96, height: 96,
                      decoration: BoxDecoration(color: primary.withAlpha(51), shape: BoxShape.circle),
                      child: Icon(Icons.person_add_rounded, size: 48, color: primary),
                    ),
                    const SizedBox(height: 20),
                    Text(l10n.register, textAlign: TextAlign.center,
                        style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold, color: primary)),
                    const SizedBox(height: 8),
                    Text('创建您的新账号', textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                    const SizedBox(height: 32),

                    // 用户名
                    TextFormField(
                      controller: _usernameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(labelText: l10n.username,
                          prefixIcon: Icon(Icons.person_outline, color: primary)),
                      validator: (v) => v == null || v.isEmpty ? l10n.invalidUsername : null,
                    ),
                    const SizedBox(height: 16),

                    // 昵称（可选）
                    TextFormField(
                      controller: _nicknameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(labelText: l10n.nickname,
                          prefixIcon: Icon(Icons.badge_outlined, color: primary)),
                    ),
                    const SizedBox(height: 16),

                    // 邮箱
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

                    // 验证码 + 发送按钮
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _codeController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: l10n.verificationCode,
                              prefixIcon: Icon(Icons.security_outlined, color: primary),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(signed: true),
                            validator: (v) => v == null || v.isEmpty ? l10n.codeExpired : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 100,
                          child: ElevatedButton(
                            onPressed: _sendingCode ? null : _sendVerificationCode,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _sendingCode
                                ? const SizedBox(height: 16, width: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text(l10n.sendCode, style: const TextStyle(fontSize: 13)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 密码
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: l10n.password,
                        prefixIcon: Icon(Icons.lock_outline, color: primary),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white70),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) => v == null || v.isEmpty ? l10n.invalidPassword : null,
                    ),
                    const SizedBox(height: 16),

                    // 确认密码
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
                      onFieldSubmitted: (_) => _handleRegister(),
                    ),
                    const SizedBox(height: 32),

                    // 注册按钮
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(l10n.register, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(foregroundColor: primary),
                      child: Text(l10n.alreadyHaveAccount),
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
