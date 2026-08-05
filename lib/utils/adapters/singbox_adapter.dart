// sing-box 内核配置适配器
// 将应用 ProxyConfig 转换为 sing-box JSON 格式
// 支持 9 种代理协议：VMess / VLESS / Trojan / Shadowsocks /
//                    Hysteria / Hysteria2 / TUIC / Naive / WireGuard

import '../../models/config.dart';
import '../../models/singbox_config.dart';
import 'dns_config_builder.dart';

/// SingboxAdapter - sing-box 内核配置适配器
///
/// 生成 sing-box 内核可识别的 JSON 配置
/// 包含入站 (inbounds)、出站 (outbounds)、路由 (route)、实验性 (experimental) 和 DNS
///
/// 私有构造函数，禁止外部实例化（纯静态方法聚合）
class SingboxAdapter {
  /// 私有构造函数，防止外部实例化
  SingboxAdapter._();

  /// 生成 sing-box 内核配置
  ///
  /// 配置结构：
  /// - inbounds：SOCKS + HTTP 入站，TUN 模式时追加 TUN 入站
  /// - outbounds：代理出站 + urltest 自动选择 + direct/block/dns
  /// - route：路由规则（广告屏蔽 + 用户自定义规则）
  /// - experimental：Clash API + TUN 配置
  /// - dns：DNS 服务器配置
  ///
  /// [proxyConfig] 代理配置（端口、TUN、DNS、广告屏蔽等）
  /// [activeNode] 当前活跃节点，为 null 时无代理出站
  /// [routingRules] 路由规则列表
  static Map<String, dynamic> toConfig(
    ProxyConfig proxyConfig,
    NodeConfig? activeNode,
    List<RoutingRule> routingRules,
  ) {
    final config = SingboxConfig.defaultConfig(
      socksPort: proxyConfig.socksPort,
      httpPort: proxyConfig.httpPort,
    );

    final outbounds = <SingboxOutbound>[];

    if (activeNode != null) {
      final proxyOutbound = nodeToOutbound(activeNode);
      outbounds.add(proxyOutbound);
      outbounds.add(
        const SingboxOutbound(
          type: 'urltest',
          tag: 'auto',
          options: {
            'outbounds': ['proxy'],
            'url': 'https://www.gstatic.com/generate_204',
            'interval': '5m',
          },
        ),
      );
    }

    outbounds.addAll(config.outbounds);

    final rules = <SingboxRouteRule>[];

    if (proxyConfig.adBlocking) {
      rules.add(
        const SingboxRouteRule(
          outbound: 'block',
          domain: [],
          ip: [],
          geosite: ['category-ads-all'],
        ),
      );
    }

    for (final r in routingRules.where((r) => r.enabled)) {
      // 端口规则解析失败时跳过该条规则，避免生成端口 0 的无效配置
      if (r.type == 'port' && int.tryParse(r.match) == null) {
        continue;
      }
      rules.add(
        SingboxRouteRule(
          outbound: r.target,
          domain: r.type == 'domain' ? [r.match] : [],
          domainKeyword: r.type == 'domain_keyword' ? [r.match] : [],
          domainSuffix: r.type == 'domain_suffix' ? [r.match] : [],
          ip: r.type == 'ip_cidr' ? [r.match] : [],
          geoip: r.type == 'geoip' ? [r.match] : [],
          geosite: r.type == 'geosite' ? [r.match] : [],
          process: r.type == 'process' ? [r.match] : [],
          protocol: r.type == 'protocol' ? [r.match] : [],
          port: r.type == 'port' ? [int.parse(r.match)] : [],
        ),
      );
    }

    final clashApi = {
      'clash_api': {
        'external_controller': proxyConfig.lanSharing
            ? '0.0.0.0:${proxyConfig.clashApiPort}'
            : '127.0.0.1:${proxyConfig.clashApiPort}',
        'secret': '',
      },
    };

    final experimental = <String, dynamic>{...clashApi};
    // 注意：TUN 配置通过下方 inbounds 中的 tun-in 入站生效，
    // 这里不再重复写入 experimental（sing-box 无此字段）

    final listenAddr = proxyConfig.lanSharing
        ? '0.0.0.0'
        : proxyConfig.localAddress;

    final result = SingboxConfig(
      inbounds: [
        SingboxInbound(
          type: 'socks',
          tag: 'socks-in',
          listenAddress: listenAddr,
          listenPort: proxyConfig.socksPort,
        ),
        SingboxInbound(
          type: 'http',
          tag: 'http-in',
          listenAddress: listenAddr,
          listenPort: proxyConfig.httpPort,
        ),
        if (proxyConfig.tunEnabled)
          const SingboxInbound(
            type: 'tun',
            tag: 'tun-in',
            extra: {
              'stack': 'system',
              'auto_route': true,
              'strict_route': true,
            },
          ),
      ],
      outbounds: outbounds,
      route: SingboxRoute(
        rules: rules,
        finalOutbound: activeNode != null ? 'auto' : 'direct',
      ),
      experimental: experimental,
    ).toJson();

    result.addAll(DnsConfigBuilder.buildSingbox(proxyConfig.dnsConfig));

    return result;
  }

  /// 将 NodeConfig 转换为 sing-box 出站代理格式
  ///
  /// 支持 9 种协议：VMess / VLESS / Trojan / Shadowsocks /
  /// Hysteria / Hysteria2 / TUIC / Naive / WireGuard
  ///
  /// [node] 节点配置，包含协议、地址、端口和协议特定参数
  static SingboxOutbound nodeToOutbound(NodeConfig node) {
    final extra = Map<String, dynamic>.from(node.extra);

    switch (node.protocol) {
      case ProxyProtocol.vmess:
        final vmessOpts = <String, dynamic>{
          'server': node.address,
          'server_port': node.port,
          'uuid': extra['uuid'] ?? '',
          'alter_id': extra['alterId'] ?? 0,
          'security': extra['security'] ?? 'auto',
        };

        // TLS 配置
        if (extra['tls'] == true) {
          vmessOpts['tls'] = {
            'enabled': true,
            'server_name': extra['sni'] ?? node.address,
            'insecure': extra['allowInsecure'] == true,
            if (extra['alpn'] != null)
              'alpn': (extra['alpn'] as String).split(','),
            if (extra['fingerprint'] != null)
              'utls': {'enabled': true, 'fingerprint': extra['fingerprint']},
          };
        }

        // 传输层配置
        final network = extra['network'] ?? 'tcp';
        if (network == 'ws') {
          vmessOpts['transport'] = {
            'type': 'ws',
            'path': extra['wsPath'] ?? '/',
            if (extra['wsHost'] != null) 'headers': {'Host': extra['wsHost']},
          };
        } else if (network == 'grpc') {
          vmessOpts['transport'] = {
            'type': 'grpc',
            if (extra['grpcServiceName'] != null)
              'service_name': extra['grpcServiceName'],
          };
        } else if (network == 'http') {
          vmessOpts['transport'] = {
            'type': 'http',
            if (extra['wsPath'] != null) 'path': extra['wsPath'],
            if (extra['wsHost'] != null) 'headers': {'Host': extra['wsHost']},
          };
        }

        return SingboxOutbound(type: 'vmess', tag: 'proxy', options: vmessOpts);

      case ProxyProtocol.vless:
        final vlessOpts = <String, dynamic>{
          'server': node.address,
          'server_port': node.port,
          'uuid': extra['uuid'] ?? '',
        };

        // Flow (xtls-rprx-vision 等)
        if (extra['flow'] != null && (extra['flow'] as String).isNotEmpty) {
          vlessOpts['flow'] = extra['flow'];
        }

        // TLS 配置
        final security = extra['security'] ?? 'none';
        if (security == 'tls' || security == 'reality') {
          vlessOpts['tls'] = {
            'enabled': true,
            'server_name': extra['sni'] ?? node.address,
            'insecure': extra['allowInsecure'] == true,
            if (extra['alpn'] != null)
              'alpn': (extra['alpn'] as String).split(','),
            // reality 强制要求 utls.fingerprint，未配置时使用默认值
            if (security == 'reality' || extra['fingerprint'] != null)
              'utls': {
                'enabled': true,
                'fingerprint': extra['fingerprint'] ?? 'chrome',
              },
          };

          // Reality 配置
          if (security == 'reality') {
            (vlessOpts['tls'] as Map<String, dynamic>)['reality'] = {
              'enabled': true,
              'public_key':
                  extra['realityPublicKey'] ?? extra['publicKey'] ?? '',
              'short_id': extra['realityShortId'] ?? extra['shortId'] ?? '',
            };
          }
        }

        // 传输层配置
        final transportType = extra['type'] ?? 'tcp';
        if (transportType == 'ws') {
          vlessOpts['transport'] = {
            'type': 'ws',
            'path': extra['wsPath'] ?? extra['path'] ?? '/',
            if (extra['wsHost'] != null || extra['host'] != null)
              'headers': {'Host': extra['wsHost'] ?? extra['host']},
          };
        } else if (transportType == 'grpc') {
          vlessOpts['transport'] = {
            'type': 'grpc',
            if (extra['grpcServiceName'] != null ||
                extra['serviceName'] != null)
              'service_name': extra['grpcServiceName'] ?? extra['serviceName'],
          };
        } else if (transportType == 'http') {
          vlessOpts['transport'] = {
            'type': 'http',
            if (extra['wsPath'] != null) 'path': extra['wsPath'],
            if (extra['wsHost'] != null) 'headers': {'Host': extra['wsHost']},
          };
        }

        return SingboxOutbound(type: 'vless', tag: 'proxy', options: vlessOpts);

      case ProxyProtocol.trojan:
        final trojanOpts = <String, dynamic>{
          'server': node.address,
          'server_port': node.port,
          'password': extra['password'] ?? '',
          'tls': {
            'enabled': true,
            'server_name': extra['sni'] ?? node.address,
            'insecure': extra['allowInsecure'] == true,
            if (extra['alpn'] != null)
              'alpn': (extra['alpn'] as String).split(','),
            if (extra['fingerprint'] != null)
              'utls': {'enabled': true, 'fingerprint': extra['fingerprint']},
          },
        };

        // 传输层配置
        final transportType = extra['type'] ?? 'tcp';
        if (transportType == 'ws') {
          trojanOpts['transport'] = {
            'type': 'ws',
            'path': extra['wsPath'] ?? '/',
            if (extra['wsHost'] != null) 'headers': {'Host': extra['wsHost']},
          };
        } else if (transportType == 'grpc') {
          trojanOpts['transport'] = {
            'type': 'grpc',
            if (extra['grpcServiceName'] != null)
              'service_name': extra['grpcServiceName'],
          };
        }

        return SingboxOutbound(
          type: 'trojan',
          tag: 'proxy',
          options: trojanOpts,
        );

      case ProxyProtocol.shadowsocks:
        return SingboxOutbound(
          type: 'shadowsocks',
          tag: 'proxy',
          options: {
            'server': node.address,
            'server_port': node.port,
            'method': extra['method'] ?? 'aes-256-gcm',
            'password': extra['password'] ?? '',
          },
        );

      case ProxyProtocol.hysteria2:
        return SingboxOutbound(
          type: 'hysteria2',
          tag: 'proxy',
          options: {
            'server': node.address,
            'server_port': node.port,
            'password': extra['password'] ?? '',
            'tls': {
              'enabled': true,
              'server_name': extra['sni'] ?? node.address,
              'insecure': extra['insecure'] == true,
            },
          },
        );

      case ProxyProtocol.hysteria:
        return SingboxOutbound(
          type: 'hysteria',
          tag: 'proxy',
          options: {
            'server': node.address,
            'server_port': node.port,
            'auth': extra['auth'] ?? extra['password'] ?? '',
            'tls': {
              'enabled': true,
              'server_name': extra['sni'] ?? node.address,
              'insecure': extra['insecure'] == true,
            },
          },
        );

      case ProxyProtocol.tuic:
        return SingboxOutbound(
          type: 'tuic',
          tag: 'proxy',
          options: {
            'server': node.address,
            'server_port': node.port,
            'uuid': extra['uuid'] ?? '',
            'password': extra['password'] ?? '',
            'tls': {
              'enabled': true,
              'server_name': extra['sni'] ?? node.address,
              'alpn': ['h3'],
            },
          },
        );

      case ProxyProtocol.naive:
        return SingboxOutbound(
          type: 'naive',
          tag: 'proxy',
          options: {
            'server': node.address,
            'server_port': node.port,
            'username': extra['username'] ?? '',
            'password': extra['password'] ?? '',
            'tls': {
              'enabled': true,
              'server_name': extra['sni'] ?? node.address,
              // sing-box naive 要求 alpn http/1.1，缺失会导致握手失败
              'alpn': ['http/1.1'],
            },
          },
        );

      case ProxyProtocol.wireguard:
        final localAddress = extra['localAddress'];
        final localAddressList = localAddress is String
            ? [localAddress]
            : (localAddress as List?)?.cast<String>() ?? [];
        return SingboxOutbound(
          type: 'wireguard',
          tag: 'proxy',
          options: {
            'server': node.address,
            'server_port': node.port,
            'private_key': extra['privateKey'] ?? '',
            'peer_public_key': extra['peerPublicKey'] ?? '',
            'local_address': localAddressList,
          },
        );
    }
  }
}
