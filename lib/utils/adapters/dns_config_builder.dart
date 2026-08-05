// DNS 配置构建器
// 跨内核共享的 DNS 配置生成工具
// 支持 sing-box / mihomo / v2ray 三种内核的 DNS 配置

import '../../../models/config.dart';

/// DnsConfigBuilder - DNS 配置构建器
///
/// 提供各内核 DNS 配置生成的共享工具方法
/// 私有构造函数，禁止外部实例化
class DnsConfigBuilder {
  /// 私有构造函数，防止外部实例化
  DnsConfigBuilder._();

  /// 构建 sing-box 风格的 DNS 配置
  ///
  /// 返回顶层包含 'dns' 键的 Map，可直接 merge 到 sing-box 配置根节点
  ///
  /// 包含：
  /// - servers: DNS 服务器列表（remote + local fallback）
  /// - rules: 出口 DNS 规则（仅当存在 fallback 时输出，避免引用不存在的 tag）
  /// - strategy: 解析策略（ipv4_only 或 prefer_ipv4）
  ///
  /// [dns] DNS 配置对象（包含模式、服务器列表、DoH/DoT 等）
  static Map<String, dynamic> buildSingbox(DnsConfig dns) {
    if (dns.mode == DnsMode.system) return {};

    final servers = <Map<String, dynamic>>[];
    final fallback = <Map<String, dynamic>>[];

    switch (dns.mode) {
      case DnsMode.system:
        break;
      case DnsMode.custom:
        for (final s in dns.servers) {
          servers.add({'address': s, 'tag': _serverTag('remote', s)});
        }
      case DnsMode.doh:
        servers.add({'address': dns.dohUrl, 'tag': 'remote_doh'});
      case DnsMode.dot:
        servers.add({'address': 'tls://${dns.dotServer}', 'tag': 'remote_dot'});
    }

    // 备用 DNS 各模式共用
    for (final s in dns.fallbackServers) {
      fallback.add({'address': s, 'tag': _serverTag('local', s)});
    }

    return {
      'dns': {
        'servers': [...servers, ...fallback],
        if (fallback.isNotEmpty)
          'rules': [
            {'outbound': 'any', 'server': fallback.first['tag']},
          ],
        'strategy': dns.remoteResolve ? 'prefer_ipv4' : 'ipv4_only',
        'independent_cache': true,
      },
    };
  }

  /// 生成合法的 sing-box server tag
  ///
  /// 服务器地址可能包含 IPv6 冒号、端口等字符，
  /// 而 sing-box 的 tag 仅允许字母数字下划线横线，其余字符替换为下划线
  static String _serverTag(String prefix, String address) {
    final sanitized = address.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    return '${prefix}_$sanitized';
  }

  /// 构建 mihomo 风格的 DNS 配置
  ///
  /// 返回包含 'dns' 键的 Map，仅当非 system 模式时返回
  ///
  /// 包含：
  /// - enable: 是否启用 DNS
  /// - listen: DNS 监听地址
  /// - enhanced-mode: fake-ip 模式
  /// - nameserver: 主 DNS 服务器列表
  /// - fallback: 备用 DNS 服务器列表
  ///
  /// [dns] DNS 配置对象
  static Map<String, dynamic> buildMihomo(DnsConfig dns) {
    if (dns.mode == DnsMode.system) return {};

    return {
      'dns': {
        'enable': true,
        'listen': '0.0.0.0:1053',
        'enhanced-mode': 'fake-ip',
        'nameserver': dns.servers,
        'fallback': dns.fallbackServers,
      },
    };
  }

  /// 构建 v2ray 风格的 DNS 配置
  ///
  /// 返回包含 'dns' 键的 Map，仅当非 system 模式时返回
  ///
  /// 包含：
  /// - servers: DNS 服务器列表（主+备用，标记 skipFallback）
  /// - queryStrategy: 查询策略（UseIP）
  ///
  /// [dns] DNS 配置对象
  static Map<String, dynamic> buildV2ray(DnsConfig dns) {
    if (dns.mode == DnsMode.system) return {};

    return {
      'dns': {
        'servers': [
          ...dns.servers.map((s) => {'address': s, 'skipFallback': false}),
          ...dns.fallbackServers.map(
            (s) => {'address': s, 'skipFallback': true},
          ),
        ],
        'queryStrategy': 'UseIP',
      },
    };
  }
}
