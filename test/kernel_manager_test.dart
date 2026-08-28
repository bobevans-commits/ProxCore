// KernelManager 服务层单元测试
//
// 覆盖范围（不涉及网络下载与真实删除操作）：
// - getBinaryName 平台相关二进制命名
// - 未初始化时的默认状态（notInstalled / false）
// - clearError 错误清除与通知
// - getBinaryPath 未安装时返回默认路径
// - init() 安装检测流程（所有类型状态被填充，不抛异常）
//
// 附带 KernelInfo 模型纯逻辑测试：
// - fileName / displayName / buildDownloadUrl
// - KernelReleaseInfo.version 去 'v' 前缀

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:proxcore/models/config.dart';
import 'package:proxcore/models/kernel_info.dart';
import 'package:proxcore/services/kernel_manager.dart';

void main() {
  group('KernelManager 二进制命名', () {
    final manager = KernelManager();

    test('getBinaryName 三种内核类型命名正确', () {
      final ext = Platform.isWindows ? '.exe' : '';
      expect(manager.getBinaryName(KernelType.singbox), 'sing-box$ext');
      expect(manager.getBinaryName(KernelType.mihomo), 'mihomo$ext');
      expect(manager.getBinaryName(KernelType.v2ray), 'xray$ext');
    });
  });

  group('KernelManager 默认状态', () {
    test('getStatus 未初始化返回 notInstalled', () {
      final manager = KernelManager();
      for (final type in KernelType.values) {
        expect(manager.getStatus(type), KernelStatus.notInstalled);
      }
    });

    test('isInstalled 未初始化返回 false', () {
      final manager = KernelManager();
      for (final type in KernelType.values) {
        expect(manager.isInstalled(type), isFalse);
      }
    });

    test('error 初始为 null', () {
      expect(KernelManager().error, isNull);
    });
  });

  group('KernelManager clearError', () {
    test('clearError 触发通知且 error 为 null', () {
      final manager = KernelManager();
      var notified = false;
      manager.addListener(() => notified = true);

      manager.clearError();

      expect(manager.error, isNull);
      expect(notified, isTrue);
    });
  });

  group('KernelManager getBinaryPath', () {
    test('未安装时返回内核目录下的默认路径', () async {
      final manager = KernelManager();
      final ext = Platform.isWindows ? '.exe' : '';

      final path = await manager.getBinaryPath(KernelType.mihomo);
      expect(path, contains('assets'));
      expect(path, endsWith('mihomo$ext'));
    });
  });

  group('KernelManager init', () {
    test('init 为所有内核类型填充状态且不抛异常', () async {
      final manager = KernelManager();
      await manager.init();

      // 具体状态取决于本机 assets/bin 实际内容，只断言状态被填充
      for (final type in KernelType.values) {
        expect(manager.statusMap.containsKey(type), isTrue,
            reason: '${type.name} 状态应被 init 填充');
      }
    });

    test('init 后 isInstalled 与 statusMap 状态一致', () async {
      final manager = KernelManager();
      await manager.init();

      for (final type in KernelType.values) {
        final status = manager.getStatus(type);
        final expected = status == KernelStatus.installed ||
            status == KernelStatus.running;
        expect(manager.isInstalled(type), expected,
            reason: '${type.name} isInstalled 应与状态一致');
      }
    });
  });

  group('KernelInfo 模型', () {
    test('fileName 按平台追加 .exe 后缀', () {
      final win = KernelInfo(type: KernelType.singbox, platform: 'windows');
      final linux = KernelInfo(type: KernelType.singbox, platform: 'linux');

      expect(win.fileName, 'sing-box.exe');
      expect(linux.fileName, 'sing-box');
    });

    test('displayName 三种内核显示名正确', () {
      expect(
        KernelInfo(type: KernelType.singbox).displayName,
        'sing-box',
      );
      expect(
        KernelInfo(type: KernelType.mihomo).displayName,
        'Mihomo (Clash Meta)',
      );
      expect(
        KernelInfo(type: KernelType.v2ray).displayName,
        'Xray (v2ray)',
      );
    });

    test('copyWith 仅覆盖指定字段', () {
      final info = KernelInfo(
        type: KernelType.v2ray,
        version: '1.8.0',
        binaryPath: '/bin/xray',
      );
      final copied = info.copyWith(version: '1.9.0');

      expect(copied.version, '1.9.0');
      expect(copied.binaryPath, '/bin/xray');
      expect(copied.type, KernelType.v2ray);
    });

    test('buildDownloadUrl sing-box windows/amd64', () {
      final url = KernelInfo.buildDownloadUrl(
        KernelType.singbox,
        '1.10.0',
        'windows',
        'amd64',
      );
      expect(url,
          'https://github.com/SagerNet/sing-box/releases/download/v1.10.0/sing-box-1.10.0-windows-amd64.zip');
    });

    test('buildDownloadUrl mihomo linux/arm64', () {
      final url = KernelInfo.buildDownloadUrl(
        KernelType.mihomo,
        '1.18.0',
        'linux',
        'arm64',
      );
      expect(url,
          'https://github.com/MetaCubeX/mihomo/releases/download/v1.18.0/mihomo-linux-arm64-v1.18.0.gz');
    });

    test('buildDownloadUrl v2ray windows/amd64 使用 64 后缀', () {
      final url = KernelInfo.buildDownloadUrl(
        KernelType.v2ray,
        '25.1.1',
        'windows',
        'amd64',
      );
      expect(url,
          'https://github.com/XTLS/Xray-core/releases/download/v25.1.1/Xray-windows-64.zip');
    });
  });

  group('KernelReleaseInfo 模型', () {
    test('version 去除 v 前缀', () {
      const release = KernelReleaseInfo(
        tagName: 'v1.8.0',
        name: 'Release 1.8.0',
        publishedAt: '2025-01-01T00:00:00Z',
        htmlUrl: 'https://github.com/example',
      );
      expect(release.version, '1.8.0');
    });

    test('无 v 前缀的标签原样返回', () {
      const release = KernelReleaseInfo(
        tagName: '25.1.1',
        name: 'Release',
        publishedAt: '2025-01-01T00:00:00Z',
        htmlUrl: 'https://github.com/example',
      );
      expect(release.version, '25.1.1');
    });
  });
}
