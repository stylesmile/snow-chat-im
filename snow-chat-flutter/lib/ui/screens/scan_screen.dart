import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../core/utils/qr_payload.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../services/contact_service.dart';
import 'user_preview_screen.dart';

/// 扫一扫页面
///
/// 使用相机扫描二维码，解析出 userId 后拉取对方公开资料并跳转到
/// [UserPreviewScreen] 完成添加好友。
///
/// 二维码内容格式约定见 [MyQrPayload]：`snowchat://user/{userId}`。
/// 为便于单测，允许通过 [scannerBuilder] 注入扫描组件（默认使用 [MobileScanner]）。
class ScanScreen extends StatefulWidget {
  /// 可选的扫描组件构建器；为空时使用真实的 [MobileScanner]。
  ///
  /// 测试中通过它注入一个伪扫描器，直接回调解析出的二维码内容，从而
  /// 在无相机环境下验证「解析 → 拉用户 → 跳转」的完整链路。
  final Widget Function(ValueChanged<String> onCode)? scannerBuilder;

  const ScanScreen({super.key, this.scannerBuilder});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  // 相机控制器：用于启动/停止扫描，以及在解析到有效码后停止一次性识别
  MobileScannerController? _controller;
  // 处理中标记：防止同一二维码被连续回调导致重复跳转或重复请求
  bool _processing = false;
  // 相机权限是否已授予；进入页面即主动申请，避免真机上不弹窗直接黑屏
  bool _cameraPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    // 生产环境（未注入伪扫描器）进入页面立即申请相机运行时权限；
    // 测试注入 scannerBuilder 时跳过，避免测试环境走真实平台权限链路。
    if (widget.scannerBuilder == null) {
      _requestCameraPermission();
    }
  }

  /// 主动申请相机权限
  ///
  /// permission_handler 会在真机上弹出系统授权对话框；若用户已授权则直接放行，
  /// 未授权则保持 [_cameraPermissionGranted] 为 false，渲染友好占位而非纯黑屏。
  Future<void> _requestCameraPermission() async {
    // 请求后无论结果如何都更新状态，通知界面重绘以决定展示取景框或错误占位
    final PermissionStatus status = await Permission.camera.request();
    if (!mounted) return;
    setState(() {
      _cameraPermissionGranted = status.isGranted;
    });
  }

  @override
  void dispose() {
    // 释放相机资源，避免内存泄漏与相机占用
    _controller?.dispose();
    super.dispose();
  }

  /// 相机扫描回调（MobileScanner 提供）
  ///
  /// 遍历本次识别到的所有条码，取第一个可解析出 userId 的二维码，
  /// 解析成功后立即调用 [_handleCode] 进入后续流程。
  void _onScan(BarcodeCapture capture) {
    for (final Barcode barcode in capture.barcodes) {
      final String? raw = barcode.rawValue;
      if (raw != null) {
        // 有一个有效码就处理一次，避免循环浪费
        _handleCode(raw);
        return;
      }
    }
  }

  /// 统一的二维码处理入口（供相机与注入的伪扫描器共同调用）
  ///
  /// 关键流程：
  /// 1. 用 [MyQrPayload.decode] 解析出 userId；解析失败 → 提示无效二维码
  /// 2. 调用 [ContactService.getUserById] 拉取对方公开资料
  /// 3. 查不到用户 → 提示未找到；成功 → 跳转 [UserPreviewScreen]
  Future<void> _handleCode(String raw) async {
    // 已在处理中则忽略，防止重复触发
    if (_processing) return;
    _processing = true;

    final l10n = AppLocalizations.of(context)!;
    final auth = context.read<AuthProvider>();

    // 步骤1：从二维码内容还原 userId（自定义协议，见 MyQrPayload）
    final int? userId = MyQrPayload.decode(raw);
    if (userId == null) {
      // 不是我们约定的二维码格式，直接提示无效
      _showSnackBar(l10n.invalidQr);
      _processing = false;
      return;
    }

    // 步骤2：拉取目标用户公开资料（网络层自行捕获异常）
    final ContactService service = ContactService(auth.apiClient);
    final UserSearchResult? user = await service.getUserById(userId);
    if (!mounted) {
      _processing = false;
      return;
    }

    if (user == null) {
      // 余额查询失败或用户不存在，统一提示未找到
      _showSnackBar(l10n.scanNotFound);
      _processing = false;
      return;
    }

    // 步骤3：跳转到用户预览页，由该页完成"添加到通讯录"操作
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserPreviewScreen(user: user),
      ),
    );
    _processing = false;
  }

  /// 轻量 SnackBar 提示（统一入口，便于调用处聚焦业务）
  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// 真正嵌入请求的扫描组件
  ///
  /// 生产环境返回 [MobileScanner]；测试环境可被 [widget.scannerBuilder] 替换。
  Widget _buildScanner() {
    // 允许测试注入伪扫描器以规避相机依赖
    if (widget.scannerBuilder != null) {
      return widget.scannerBuilder!(_handleCode);
    }
    // 相机权限未授予时展示友好占位，避免在未授权情况下直接创建相机导致黑屏
    if (!_cameraPermissionGranted) {
      return _buildCameraError();
    }
    _controller ??= MobileScannerController(
      // 只识别二维码，提升识别精度与性能
      formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
    );
    return MobileScanner(
      controller: _controller,
      onDetect: _onScan,
      // 相机不可用（如权限被拒）时展示友好提示而非崩溃
      errorBuilder: (context, error, _) => _buildCameraError(),
    );
  }

  /// 相机错误占位：提示需要相机权限
  Widget _buildCameraError() {
    final l10n = AppLocalizations.of(context)!;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography, color: Colors.white54, size: 48),
            const SizedBox(height: 12),
            Text(
              l10n.scanCameraDenied,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(l10n.scan),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // 扫描区域（四周围黑，中间透明取景框）
          Column(
            children: [
              Expanded(child: SizedBox.expand(child: _buildScanner())),
            ],
          ),
          // 提示文案遮罩（不影响点击）
          const Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.only(bottom: 32),
                child: Text(
                  '将二维码放入框内，即可自动识别',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}