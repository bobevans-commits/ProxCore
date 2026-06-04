import 'package:flutter/material.dart';

import '../services/proxy_service.dart';
import '../widgets/kernel_install_screen.dart';

/// TunHelper - TUN 模式切换辅助函数
///
/// 提供统一的 TUN 开关逻辑：检测内核安装状态、引导安装、显示状态通知
/// 供 HomeScreen 和 SettingsScreen 复用
class TunHelper {
  /// TUN 模式切换处理
  ///
  /// [context] 上下文（用于弹对话框和导航）
  /// [proxyService] 代理服务实例
  /// [enable] 是否开启 TUN
  ///
  /// 流程：
  /// 1. 关闭时直接调用 toggleTun(false)
  /// 2. 开启时若内核已安装则直接开启
  /// 3. 开启时若内核未安装，弹对话框引导用户安装
  /// 4. 安装成功后自动开启 TUN 并显示 SnackBar
  static Future<void> onTunToggle(
    BuildContext context,
    ProxyService proxyService,
    bool enable,
  ) async {
    if (!enable) {
      proxyService.toggleTun(false);
      return;
    }

    if (proxyService.isKernelInstalled()) {
      proxyService.toggleTun(true);
      return;
    }

    final kernelType = proxyService.activeKernelType;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.vpn_lock, size: 32),
        title: const Text('需要安装内核'),
        content: Text('TUN 模式需要 ${kernelType.label} 内核支持。当前未检测到已安装的内核，是否前往安装？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'install'),
            child: const Text('前往安装'),
          ),
        ],
      ),
    );

    if (result == 'install' && context.mounted) {
      final kernelManager = proxyService.kernelManager;
      final installed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => KernelInstallScreen(
            kernelType: kernelType,
            kernelManager: kernelManager,
          ),
        ),
      );

      if (installed == true && context.mounted) {
        proxyService.toggleTun(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('TUN 模式已开启'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
