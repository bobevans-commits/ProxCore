// v2ray (Xray) 内核配置适配器
// 将应用 ProxyConfig 转换为 v2ray JSON 格式
// 支持 VMess / VLESS / Trojan / Shadowsocks
// 其他协议降级为 socks

import '../../models/config.dart';
import 'dns_config_builder.dart';

/// V2rayAdapter - v2ray (Xray) 内核配置适配器
///
/// 生成 v2ray/Xray 内核可识别的 JSON 配置
/// 包含 inbounds / outbounds / routing / dns / log
///
/// 私有构造函数，禁止外部实例化（纯静态方法聚合）
class V2rayAdapter {
  /// 私有构造函数，防止外部实例化
  V2rayAdapter._();

  /// 生成 v2ray 内核配置
  ///
  /// 配置结构：
  /// - inbounds：SOCKS + HTTP 入站，TUN 模式时追加 dokodemo-door
  /// - outbounds：代理出站 + direct + block
  /// - routing：路由规则（广告屏蔽 + 用户自定义规则）
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
    final outbounds = <Map<String, dynamic>>[
      {'tag': 'direct', 'protocol': 'freedom'},
      {'tag': 'block', 'protocol': 'blackhole'},
    ];

    if (activeNode != null) {
      outbounds.insert(0, nodeToOutbound(activeNode));
    }

    final rules = <Map<String, dynamic>>[];

    if (proxyConfig.adBlocking) {
      rules.add({
        'type': 'field',
        'domain': ['geosite:category-ads-all'],
        'outboundTag': 'block',
      });
    }

    for (final r in routingRules.where((r) => r.enabled)) {
      switch (r.type) {
        case 'domain':
          rules.add({
            'type': 'field',
            'domain': [r.match],
            'outboundTag': r.target,
          });
        case 'domain_keyword':
          rules.add({
            'type': 'field',
            'domain': ['keyword:${r.match}'],
            'outboundTag': r.target,
          });
        case 'domain_suffix':
          rules.add({
            'type': 'field',
            'domain': ['domain-suffix:${r.match}'],
            'outboundTag': r.target,
          });
        case 'ip_cidr':
          rules.add({
            'type': 'field',
            'ip': [r.match],
            'outboundTag': r.target,
          });
        case 'geoip':
          rules.add({
            'type': 'field',
            'ip': ['geoip:${r.match}'],
            'outboundTag': r.target,
          });
        case 'geosite':
          rules.add({
            'type': 'field',
            'domain': ['geosite:${r.match}'],
            'outboundTag': r.target,
          });
        case 'process':
          rules.add({
            'type': 'field',
            'process': [r.match],
            'outboundTag': r.target,
          });
        case 'port':
          rules.add({
            'type': 'field',
            'port': r.match,
            'outboundTag': r.target,
          });
        default:
          rules.add({'type': 'field', 'outboundTag': r.target});
      }
    }

    final listenAddr = proxyConfig.lanSharing
        ? '0.0.0.0'
        : proxyConfig.localAddress;

    return {
      'log': {'loglevel': 'info'},
      'inbounds': [
        {
          'tag': 'socks',
          'protocol': 'socks',
          'listen': listenAddr,
          'port': proxyConfig.socksPort,
        },
        {
          'tag': 'http',
          'protocol': 'http',
          'listen': listenAddr,
          'port': proxyConfig.httpPort,
        },
        if (proxyConfig.tunEnabled)
          {
            'tag': 'tun',
            'protocol': 'dokodemo-door',
            'listen': '0.0.0.0',
            'port': 0,
            'settings': {'network': 'tcp,udp', 'followRedirect': true},
            'streamSettings': {
              'sockopt': {'tproxy': 'tun'},
            },
          },
      ],
      'outbounds': outbounds,
      'routing': {'rules': rules, 'domainStrategy': 'IPIfNonMatch'},
      ...DnsConfigBuilder.buildV2ray(proxyConfig.dnsConfig),
    };
  }

  /// 将 NodeConfig 转换为 v2ray 出站代理格式
  ///
  /// 支持 VMess / VLESS / Trojan / Shadowsocks
  /// 其他协议降级为 socks
  ///
  /// [node] 节点配置，包含协议、地址、端口和协议特定参数
  static Map<String, dynamic> nodeToOutbound(NodeConfig node) {
    final extra = Map<String, dynamic>.from(node.extra);

    switch (node.protocol) {
      case ProxyProtocol.vmess:
        final vmessStreamSettings = <String, dynamic>{
          'network': extra['network'] ?? 'tcp',
          'security': extra['tls'] == true ? 'tls' : 'none',
        };

        // TLS 配置
        if (extra['tls'] == true) {
          vmessStreamSettings['tlsSettings'] = {
            'serverName': extra['sni'] ?? node.address,
            'allowInsecure': extra['allowInsecure'] == true,
            if (extra['alpn'] != null)
              'alpn': (extra['alpn'] as String).split(','),
            if (extra['fingerprint'] != null)
              'fingerprint': extra['fingerprint'],
          };
        }

        // WebSocket 传输
        if ((extra['network'] ?? 'tcp') == 'ws') {
          vmessStreamSettings['wsSettings'] = {
            'path': extra['wsPath'] ?? '/',
            if (extra['wsHost'] != null) 'headers': {'Host': extra['wsHost']},
          };
        }

        // gRPC 传输
        if ((extra['network'] ?? 'tcp') == 'grpc') {
          vmessStreamSettings['grpcSettings'] = {
            'serviceName': extra['grpcServiceName'] ?? '',
          };
        }

        return {
          'tag': 'proxy',
          'protocol': 'vmess',
          'settings': {
            'vnext': [
              {
                'address': node.address,
                'port': node.port,
                'users': [
                  {
                    'id': extra['uuid'] ?? '',
                    'alterId': extra['alterId'] ?? 0,
                    'security': extra['security'] ?? 'auto',
                  },
                ],
              },
            ],
          },
          'streamSettings': vmessStreamSettings,
        };
      case ProxyProtocol.vless:
        final vlessStreamSettings = <String, dynamic>{
          'network': extra['type'] ?? 'tcp',
          'security': extra['security'] ?? 'none',
        };

        // TLS 配置
        if (extra['security'] == 'tls') {
          vlessStreamSettings['tlsSettings'] = {
            'serverName': extra['sni'] ?? node.address,
            'allowInsecure': extra['allowInsecure'] == true,
            if (extra['alpn'] != null)
              'alpn': (extra['alpn'] as String).split(','),
            if (extra['fingerprint'] != null)
              'fingerprint': extra['fingerprint'],
          };
        }

        // Reality 配置
        if (extra['security'] == 'reality') {
          vlessStreamSettings['realitySettings'] = {
            'serverName': extra['sni'] ?? node.address,
            'publicKey': extra['realityPublicKey'] ?? extra['publicKey'] ?? '',
            'shortId': extra['realityShortId'] ?? extra['shortId'] ?? '',
            'fingerprint': extra['fingerprint'] ?? 'chrome',
          };
        }

        // WebSocket 传输
        if ((extra['type'] ?? 'tcp') == 'ws') {
          vlessStreamSettings['wsSettings'] = {
            'path': extra['wsPath'] ?? '/',
            if (extra['wsHost'] != null) 'headers': {'Host': extra['wsHost']},
          };
        }

        // gRPC 传输
        if ((extra['type'] ?? 'tcp') == 'grpc') {
          vlessStreamSettings['grpcSettings'] = {
            'serviceName': extra['grpcServiceName'] ?? '',
          };
        }

        return {
          'tag': 'proxy',
          'protocol': 'vless',
          'settings': {
            'vnext': [
              {
                'address': node.address,
                'port': node.port,
                'users': [
                  {
                    'id': extra['uuid'] ?? '',
                    'flow': extra['flow'] ?? '',
                    'encryption': 'none',
                  },
                ],
              },
            ],
          },
          'streamSettings': vlessStreamSettings,
        };
      case ProxyProtocol.trojan:
        final trojanStreamSettings = <String, dynamic>{
          'network': extra['type'] ?? 'tcp',
          'security': 'tls',
          'tlsSettings': {
            'serverName': extra['sni'] ?? node.address,
            'allowInsecure': extra['allowInsecure'] == true,
            if (extra['alpn'] != null)
              'alpn': (extra['alpn'] as String).split(','),
            if (extra['fingerprint'] != null)
              'fingerprint': extra['fingerprint'],
          },
        };

        // WebSocket 传输
        if ((extra['type'] ?? 'tcp') == 'ws') {
          trojanStreamSettings['wsSettings'] = {
            'path': extra['wsPath'] ?? '/',
            if (extra['wsHost'] != null) 'headers': {'Host': extra['wsHost']},
          };
        }

        // gRPC 传输
        if ((extra['type'] ?? 'tcp') == 'grpc') {
          trojanStreamSettings['grpcSettings'] = {
            'serviceName': extra['grpcServiceName'] ?? '',
          };
        }

        return {
          'tag': 'proxy',
          'protocol': 'trojan',
          'settings': {
            'servers': [
              {
                'address': node.address,
                'port': node.port,
                'password': extra['password'] ?? '',
              },
            ],
          },
          'streamSettings': trojanStreamSettings,
        };
      case ProxyProtocol.shadowsocks:
        return {
          'tag': 'proxy',
          'protocol': 'shadowsocks',
          'settings': {
            'servers': [
              {
                'address': node.address,
                'port': node.port,
                'method': extra['method'] ?? 'aes-256-gcm',
                'password': extra['password'] ?? '',
              },
            ],
          },
        };
      default:
        return {
          'tag': 'proxy',
          'protocol': 'socks',
          'settings': {
            'servers': [
              {'address': node.address, 'port': node.port},
            ],
          },
        };
    }
  }
}
