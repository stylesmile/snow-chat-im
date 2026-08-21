import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.isLoggedIn && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } else {
      final l10n = AppLocalizations.of(context)!;
      final errorMsg = auth.lastError ?? l10n.loginFailed;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red.shade700,
          action: SnackBarAction(
            label: l10n.settings,
            textColor: Colors.white,
            onPressed: () => _showSettingsDialog(),
          ),
        ),
      );
    }
  }

  void _showSettingsDialog() {
    final l10n = AppLocalizations.of(context)!;
    final auth = context.read<AuthProvider>();
    final currentUrl = auth.apiClient.baseUrl;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.settings),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '当前服务器地址:',
              // 深色模式下辅助文字使用半透明白，保证对比度且不抢主信息
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 4),
            // 服务器地址：可选中复制，颜色跟随主题（深色模式下为浅色）
            SelectableText(
              currentUrl,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Text(
              '请在终端中重新启动应用并指定正确的 IP:',
              // 次要说明文字：比主文字更弱一层
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                // 命令行代码块：深色表面上叠一层浅色蒙版，形成"代码块"的视觉层次
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const SelectableText(
                'flutter run --dart-define=API_BASE_URL=http://YOUR_IP:8091',
                style: TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    // 主题主色（WINCHAT 品牌蓝），由 AppTheme.dark() 提供
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(),
            tooltip: l10n.settings,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          // 深色渐变背景：品牌蓝自左上角淡入，渐变到近黑页面背景
          // 与 WINCHAT 设计稿一致：深底 + 蓝色氛围，避免浅色刺眼
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primary.withAlpha(45),
              primary.withAlpha(18),
              AppTheme.background,
            ],
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
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        // 图标底：品牌蓝低透明度蒙版，深色下形成柔和光晕
                        color: primary.withAlpha(51),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.chat_rounded,
                        size: 48,
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.appTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '欢迎回来',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        // 深色模式下副标题使用半透明白，保证可读性
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 48),
                    TextFormField(
                      controller: _usernameController,
                      // 输入文字为浅色：深色背景上 grey.shade700 不可读
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: l10n.username,
                        prefixIcon: Icon(Icons.person_outline, color: primary),
                        // 边框/填充由主题 inputDecorationTheme 统一提供（深灰填充 + 蓝色聚焦边框）
                      ),
                      validator: (v) => v == null || v.isEmpty ? l10n.invalidUsername : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      // 输入文字为浅色，与用户名输入框一致
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: l10n.password,
                        prefixIcon: Icon(Icons.lock_outline, color: primary),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            // 密码可见性切换图标：半透明白，弱化视觉噪音
                            color: Colors.white70,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) => v == null || v.isEmpty ? l10n.invalidPassword : null,
                      onFieldSubmitted: (_) => _handleLogin(),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        // 主按钮：品牌蓝底 + 白字，对应设计稿的大按钮
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              l10n.login,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const RegisterScreen()),
                        );
                      },
                      // 文字按钮：品牌蓝前景，深色下清晰可点
                      style: TextButton.styleFrom(foregroundColor: primary),
                      child: Text(l10n.noAccountYet),
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
