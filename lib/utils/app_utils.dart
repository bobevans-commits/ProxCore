import 'dart:convert';
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

  /// 获取当前平台标识字符串
  ///
  /// 返回：windows / darwin / linux / android / unknown
  static String getPlatformName() {
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'darwin';
    if (Platform.isLinux) return 'linux';
    if (Platform.isAndroid) return 'android';
    return 'unknown';
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

  // ---- 代理链接解析 ----

  /// 从代理链接 URI 自动检测协议类型
  ///
  /// 支持：vmess://, vless://, trojan://, ss://, hysteria://, hysteria2://, hy2://, tuic://
  static ProxyProtocol? detectProtocol(String uri) {
    final trimmed = uri.trim();
    if (trimmed.startsWith('vmess://')) return ProxyProtocol.vmess;
    if (trimmed.startsWith('vless://')) return ProxyProtocol.vless;
    if (trimmed.startsWith('trojan://')) return ProxyProtocol.trojan;
    if (trimmed.startsWith('ss://')) return ProxyProtocol.shadowsocks;
    if (trimmed.startsWith('hysteria2://') || trimmed.startsWith('hy2://')) return ProxyProtocol.hysteria2;
    if (trimmed.startsWith('hysteria://')) return ProxyProtocol.hysteria;
    if (trimmed.startsWith('tuic://')) return ProxyProtocol.tuic;
    return null;
  }

  /// 解析代理链接为 NodeConfig
  ///
  /// 统一入口方法，自动检测协议并调用对应解析器
  /// 不支持的协议抛出 UnimplementedError
  static NodeConfig parseProxyLink(String uri) {
    final protocol = detectProtocol(uri);
    if (protocol == null) {
      throw FormatException('无法识别的协议格式: $uri');
    }

    switch (protocol) {
      case ProxyProtocol.vmess:
        return _parseVmess(uri);
      case ProxyProtocol.vless:
      case ProxyProtocol.trojan:
      case ProxyProtocol.hysteria2:
        return _parseUriBased(uri, protocol);
      case ProxyProtocol.shadowsocks:
        return _parseShadowsocks(uri);
      case ProxyProtocol.hysteria:
        return _parseHysteria(uri);
      case ProxyProtocol.tuic:
        return _parseTuic(uri);
      case ProxyProtocol.naive:
      case ProxyProtocol.wireguard:
        throw UnimplementedError(
          '${protocol.label} 协议链接解析暂不支持，请手动添加节点',
        );
    }
  }

  /// 解析 VMess 协议 URI
  ///
  /// 格式：vmess://{Base64编码的JSON}
  /// JSON 字段：ps(名称), add(地址), port(端口), id(UUID), aid(alterId),
  ///   net(传输协议), type(伪装类型), host(WS主机), path(WS路径),
  ///   tls(TLS), sni, alpn, scy(加密方式)
  static NodeConfig _parseVmess(String uri) {
    final encoded = uri.replaceFirst('vmess://', '');
    final decoded = utf8.decode(base64Decode(encoded));
    final json = jsonDecode(decoded) as Map<String, dynamic>;
    return NodeConfig(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['ps'] as String? ?? 'VMess',
      protocol: ProxyProtocol.vmess,
      address: json['add'] as String? ?? '',
      port: int.tryParse(json['port']?.toString() ?? '0') ?? 0,
      extra: {
        'uuid': json['id'],
        'alterId': json['aid'] ?? 0,
        'security': json['scy'] ?? 'auto',
        'network': json['net'] ?? 'tcp',
        'wsPath': json['path'],
        'wsHost': json['host'],
        'tls': json['tls'] == 'tls',
        'sni': json['sni'],
        'alpn': json['alpn'],
        'fingerprint': json['fp'],
      },
    );
  }

  /// 解析基于 URI 格式的协议链接（VLESS / Trojan / Hysteria2）
  ///
  /// 格式：{protocol}://{userInfo}@{host}:{port}?{params}#{name}
  /// 通用参数：security, type, sni, alpn, fp, pbk, sid, flow, headerType
  static NodeConfig _parseUriBased(String uri, ProxyProtocol protocol) {
    final parsed = Uri.parse(uri);
    final params = parsed.queryParameters;
    final name = params['name'] ?? parsed.fragment;
    final effectiveName = name.isEmpty ? protocol.label : name;
    final security = params['security'] ?? 'none';

    Map<String, dynamic> extra;
    switch (protocol) {
      case ProxyProtocol.vless:
        extra = {
          'uuid': parsed.userInfo,
          'flow': params['flow'],
          'security': security,
          'type': params['type'] ?? 'tcp',
          'sni': params['sni'],
          'alpn': params['alpn'],
          'fingerprint': params['fp'],
          'tls': security == 'tls' || security == 'reality',
          'reality': security == 'reality',
          'realityPublicKey': params['pbk'],
          'realityShortId': params['sid'],
          'wsPath': params['path'],
          'wsHost': params['host'],
          'grpcServiceName': params['serviceName'],
        };
      case ProxyProtocol.trojan:
        extra = {
          'password': parsed.userInfo,
          'sni': params['sni'],
          'type': params['type'] ?? 'tcp',
          'security': security,
          'alpn': params['alpn'],
          'fingerprint': params['fp'],
          'tls': true,
          'wsPath': params['path'],
          'wsHost': params['host'],
          'grpcServiceName': params['serviceName'],
          'allowInsecure': params['allowInsecure'] == '1',
        };
      case ProxyProtocol.hysteria2:
        extra = {
          'password': parsed.userInfo,
          'sni': params['sni'],
          'insecure': params['insecure'] == '1',
          'alpn': params['alpn'],
          'fingerprint': params['fp'],
          'obfs': params['obfs'],
          'obfsPassword': params['obfs-password'],
        };
      default:
        extra = {'rawUri': uri};
    }

    return NodeConfig(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: effectiveName,
      protocol: protocol,
      address: parsed.host.isEmpty ? '0.0.0.0' : parsed.host,
      port: parsed.port == 0 ? 443 : parsed.port,
      extra: extra,
    );
  }

  /// 解析 Shadowsocks 协议 URI
  ///
  /// 支持两种格式：
  /// 1. 传统格式：ss://{Base64(method:password)}@{host}:{port}#{name}
  /// 2. SIP002 格式：ss://{Base64(method:password)}@{host}:{port}?{params}#{name}
  /// 3. SS 2022 格式：ss://{Base64(method:base64key)}@{host}:{port}#{name}
  static NodeConfig _parseShadowsocks(String uri) {
    final content = uri.replaceFirst('ss://', '');
    final hashIndex = content.indexOf('#');
    final name = hashIndex >= 0
        ? Uri.decodeComponent(content.substring(hashIndex + 1))
        : 'Shadowsocks';
    final body = hashIndex >= 0 ? content.substring(0, hashIndex) : content;

    final atIndex = body.indexOf('@');
    if (atIndex < 0) throw const FormatException('Invalid SS URI format');

    final encodedPart = body.substring(0, atIndex);
    String method;
    String password;

    try {
      final decoded = utf8.decode(base64Decode(encodedPart));
      final colonIndex = decoded.indexOf(':');
      method = decoded.substring(0, colonIndex);
      password = decoded.substring(colonIndex + 1);
    } catch (_) {
      // SIP002 格式：method:password 可能未编码
      final colonIndex = encodedPart.indexOf(':');
      if (colonIndex >= 0) {
        method = encodedPart.substring(0, colonIndex);
        password = encodedPart.substring(colonIndex + 1);
      } else {
        throw const FormatException('Invalid SS URI: cannot decode credentials');
      }
    }

    final serverPart = body.substring(atIndex + 1);
    final colonPos = serverPart.lastIndexOf(':');
    if (colonPos < 0) throw const FormatException('Invalid SS URI: missing port');

    // 解析 SIP002 查询参数（如 plugin）
    final questionPos = serverPart.indexOf('?');
    final hostPort = questionPos >= 0
        ? serverPart.substring(0, questionPos)
        : serverPart;
    final hostColon = hostPort.lastIndexOf(':');

    return NodeConfig(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      protocol: ProxyProtocol.shadowsocks,
      address: hostPort.substring(0, hostColon),
      port: int.parse(hostPort.substring(hostColon + 1)),
      extra: {
        'method': method,
        'password': password,
      },
    );
  }

  /// 解析 Hysteria 协议 URI
  ///
  /// 格式：hysteria://{auth}@{host}:{port}?{params}#{name}
  static NodeConfig _parseHysteria(String uri) {
    final parsed = Uri.parse(uri);
    final params = parsed.queryParameters;
    final name = params['name'] ?? parsed.fragment;
    final effectiveName = name.isEmpty ? 'Hysteria' : name;
    return NodeConfig(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: effectiveName,
      protocol: ProxyProtocol.hysteria,
      address: parsed.host.isEmpty ? '0.0.0.0' : parsed.host,
      port: parsed.port == 0 ? 443 : parsed.port,
      extra: {
        'auth': params['auth'] ?? parsed.userInfo,
        'sni': params['sni'],
        'insecure': params['insecure'] == '1',
      },
    );
  }

  /// 解析 TUIC 协议 URI
  ///
  /// 格式：tuic://{uuid}:{password}@{host}:{port}?{params}#{name}
  static NodeConfig _parseTuic(String uri) {
    final parsed = Uri.parse(uri);
    final params = parsed.queryParameters;
    final name = params['name'] ?? parsed.fragment;
    final effectiveName = name.isEmpty ? 'TUIC' : name;
    final userInfo = parsed.userInfo.split(':');
    return NodeConfig(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: effectiveName,
      protocol: ProxyProtocol.tuic,
      address: parsed.host.isEmpty ? '0.0.0.0' : parsed.host,
      port: parsed.port == 0 ? 443 : parsed.port,
      extra: {
        'uuid': userInfo.isNotEmpty ? userInfo[0] : '',
        'password': userInfo.length > 1 ? userInfo[1] : '',
        'sni': params['sni'],
      },
    );
  }
}
