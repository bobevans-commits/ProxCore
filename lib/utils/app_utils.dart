import 'dart:io';

import 'dart:io';

import '../models/config.dart';

class AppUtils {
  AppUtils._();

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  static String formatTimestamp(DateTime dt) {
    return '${dt.year}-${_twoDigits(dt.month)}-${_twoDigits(dt.day)} '
        '${_twoDigits(dt.hour)}:${_twoDigits(dt.minute)}:${_twoDigits(dt.second)}';
  }

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');

  static String getPlatformName() {
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    return 'Unknown';
  }

  /// 获取当前 CPU 架构名称
  ///
  /// 检测顺序：
  /// 1. Dart VM 版本字符串中的 arm64/aarch64
  /// 2. Windows PROCESSOR_ARCHITECTURE 环境变量
  /// 3. macOS/Linux uname -m 命令输出
  /// 默认返回 amd64
  static String getArchName() {
    final version = Platform.version.toLowerCase();
    if (version.contains('arm64') || version.contains('aarch64')) return 'arm64';
    if (Platform.isWindows) {
      final procArch =
          Platform.environment['PROCESSOR_ARCHITECTURE']?.toUpperCase() ?? '';
      if (procArch.contains('ARM64')) return 'arm64';
    }
    if (Platform.isMacOS || Platform.isLinux) {
      try {
        final result = Process.runSync('uname', ['-m']);
        final arch = result.stdout.toString().trim().toLowerCase();
        if (arch.contains('arm64') || arch.contains('aarch64')) return 'arm64';
      } catch (_) {}
    }
    return 'amd64';
  }

  static String protocolIcon(ProxyProtocol protocol) {
    switch (protocol) {
      case ProxyProtocol.vmess:
        return '🟣';
      case ProxyProtocol.vless:
        return '🔵';
      case ProxyProtocol.trojan:
        return '🔴';
      case ProxyProtocol.shadowsocks:
        return '🟡';
      case ProxyProtocol.hysteria:
      case ProxyProtocol.hysteria2:
        return '🟢';
      case ProxyProtocol.tuic:
        return '🟠';
      case ProxyProtocol.naive:
        return '⚪';
      case ProxyProtocol.wireguard:
        return '🔒';
    }
  }

  /// 格式化延迟标签
  ///
  /// 返回格式：
  /// - ms < 0: "超时"
  /// - ms >= 0: "{ms} ms"
  static String latencyLabel(int ms) {
    if (ms < 0) return '超时';
    return '$ms ms';
  }

  static int latencyColor(int ms) {
    if (ms < 0) return 0xFFE53935;
    if (ms < 100) return 0xFF43A047;
    if (ms < 300) return 0xFFFFA000;
    return 0xFFE53935;
  }

  static bool isValidPort(int port) {
    return port > 0 && port <= 65535;
  }

  static bool isValidAddress(String address) {
    if (address.isEmpty) return false;
    final ipv4 = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    final ipv6 = RegExp(r'^\[?([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}\]?$');
    final domain = RegExp(r'^[a-zA-Z0-9]([a-zA-Z0-9\-]*\.)+[a-zA-Z]{2,}$');
    return ipv4.hasMatch(address) || ipv6.hasMatch(address) || domain.hasMatch(address);
  }

  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.scheme == 'http' || uri.scheme == 'https';
    } catch (_) {
      return false;
    }
  }
}
