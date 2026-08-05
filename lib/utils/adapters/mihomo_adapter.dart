// mihomo 内核配置适配器
// 将应用 ProxyConfig 转换为 mihomo (Clash Meta) 兼容的 JSON 配置
// 支持 VMess / VLESS / Trojan / Shadowsocks / Hysteria2 / TUIC / Hysteria
// 其他协议降级为 socks5

import '../../models/config.dart';
import 'dns_config_builder.dart';

/// MihomoAdapter - mihomo 内核配置适配器
///
/// 生成 mihomo (Clash Meta) 内核可识别的 JSON 配置
/// YAML 兼容格式，包含 proxies / proxy-groups / rules / DNS / TUN
///
/// 私有构造函数，禁止外部实例化（纯静态方法聚合）
class MihomoAdapter {
  /// 私有构造函数，防止外部实例化
  MihomoAdapter._();

  /// 生成 mihomo 内核配置
  ///
  /// 配置结构：
  /// - mixed-port / socks-port / port：代理端口
  /// - tun：TUN 模式配置
  /// - proxies：代理节点列表
  /// - proxy-groups：代理组（PROXY 选择组）
  /// - rules：路由规则（广告屏蔽 + 用户自定义规则 + MATCH 兜底）
  /// - dns：DNS 配置（fake-ip 模式）
  ///
  /// [proxyConfig] 代理配置（端口、TUN、DNS、广告屏蔽等）
  /// [activeNode] 当前活跃节点，为 null 时无代理节点
  /// [routingRules] 路由规则列表
  static Map<String, dynamic> toConfig(
    ProxyConfig proxyConfig,
    NodeConfig? activeNode,
    List<RoutingRule> routingRules,
  ) {
    final proxies = <Map<String, dynamic>>[];

    if (activeNode != null) {
      proxies.add(nodeToProxy(activeNode));
    }

    final rules = <String>[];

    if (proxyConfig.adBlocking) {
      rules.add('DOMAIN-KEYWORD,ads,BLOCK');
      rules.add('GEOSITE,category-ads-all,BLOCK');
    }

    for (final r in routingRules.where((r) => r.enabled)) {
      switch (r.type) {
        case 'domain':
          rules.add('DOMAIN,${r.match},${r.target.toUpperCase()}');
        case 'domain_keyword':
          rules.add('DOMAIN-KEYWORD,${r.match},${r.target.toUpperCase()}');
        case 'domain_suffix':
          rules.add('DOMAIN-SUFFIX,${r.match},${r.target.toUpperCase()}');
        case 'ip_cidr':
          rules.add('IP-CIDR,${r.match},${r.target.toUpperCase()}');
        case 'geoip':
          rules.add('GEOIP,${r.match},${r.target.toUpperCase()}');
        case 'geosite':
          rules.add('GEOSITE,${r.match},${r.target.toUpperCase()}');
        case 'process':
          rules.add('PROCESS-NAME,${r.match},${r.target.toUpperCase()}');
        case 'port':
          rules.add('DST-PORT,${r.match},${r.target.toUpperCase()}');
        default:
          rules.add('MATCH,${r.target.toUpperCase()}');
      }
    }

    rules.add('MATCH,${activeNode != null ? "PROXY" : "DIRECT"}');

    return {
      'mixed-port': proxyConfig.localPort,
      if (proxyConfig.socksPort != proxyConfig.localPort)
        'socks-port': proxyConfig.socksPort,
      if (proxyConfig.httpPort != proxyConfig.localPort)
        'port': proxyConfig.httpPort,
      'external-controller': proxyConfig.lanSharing
          ? '0.0.0.0:${proxyConfig.clashApiPort}'
          : '127.0.0.1:${proxyConfig.clashApiPort}',
      'allow-lan': proxyConfig.lanSharing,
      'bind-address': proxyConfig.lanSharing ? '*' : '127.0.0.1',
      'mode': 'rule',
      'log-level': 'info',
      if (proxyConfig.tunEnabled)
        'tun': {
          'enable': true,
          'stack': 'system',
          'auto-route': true,
          'auto-detect-interface': true,
        },
      if (proxies.isNotEmpty) 'proxies': proxies,
      'proxy-groups': [
        {
          'name': 'PROXY',
          'type': 'select',
          'proxies': activeNode != null ? [activeNode.name] : ['DIRECT'],
        },
      ],
      'rules': rules,
      ...DnsConfigBuilder.buildMihomo(proxyConfig.dnsConfig),
    };
  }

  /// 将 NodeConfig 转换为 mihomo 代理格式
  ///
  /// 支持 VMess / VLESS / Trojan / Shadowsocks / Hysteria2
  /// 其他协议降级为 socks5
  ///
  /// [node] 节点配置，包含协议、地址、端口和协议特定参数
  static Map<String, dynamic> nodeToProxy(NodeConfig node) {
    final extra = Map<String, dynamic>.from(node.extra);

    switch (node.protocol) {
      case ProxyProtocol.vmess:
        final vmessProxy = <String, dynamic>{
          'name': node.name,
          'type': 'vmess',
          'server': node.address,
          'port': node.port,
          'uuid': extra['uuid'] ?? '',
          'alterId': extra['alterId'] ?? 0,
          'cipher': extra['security'] ?? 'auto',
          'network': extra['network'] ?? 'tcp',
        };

        // TLS 配置
        if (extra['tls'] == true) {
          vmessProxy['tls'] = true;
          if (extra['sni'] != null) vmessProxy['servername'] = extra['sni'];
          if (extra['allowInsecure'] == true) {
            vmessProxy['skip-cert-verify'] = true;
          }
        }

        // WebSocket 传输
        if (extra['network'] == 'ws') {
          vmessProxy['ws-opts'] = {
            'path': extra['wsPath'] ?? '/',
            if (extra['wsHost'] != null) 'headers': {'Host': extra['wsHost']},
          };
        }

        // gRPC 传输
        if (extra['network'] == 'grpc') {
          vmessProxy['grpc-opts'] = {
            'grpc-service-name': extra['grpcServiceName'] ?? '',
          };
        }

        return vmessProxy;
      case ProxyProtocol.vless:
        final vlessProxy = <String, dynamic>{
          'name': node.name,
          'type': 'vless',
          'server': node.address,
          'port': node.port,
          'uuid': extra['uuid'] ?? '',
          'network': extra['type'] ?? extra['network'] ?? 'tcp',
        };

        // Flow
        if (extra['flow'] != null && (extra['flow'] as String).isNotEmpty) {
          vlessProxy['flow'] = extra['flow'];
        }

        // TLS 配置
        final security = extra['security'] ?? 'none';
        if (security == 'tls' || security == 'reality') {
          vlessProxy['tls'] = true;
          vlessProxy['servername'] = extra['sni'] ?? node.address;
          if (extra['allowInsecure'] == true) {
            vlessProxy['skip-cert-verify'] = true;
          }
        }

        // Reality 配置
        if (security == 'reality') {
          vlessProxy['reality-opts'] = {
            'public-key': extra['realityPublicKey'] ?? extra['publicKey'] ?? '',
            'short-id': extra['realityShortId'] ?? extra['shortId'] ?? '',
          };
        }

        // WebSocket 传输
        if ((extra['type'] ?? 'tcp') == 'ws') {
          vlessProxy['ws-opts'] = {
            'path': extra['wsPath'] ?? '/',
            if (extra['wsHost'] != null) 'headers': {'Host': extra['wsHost']},
          };
        }

        // gRPC 传输
        if ((extra['type'] ?? 'tcp') == 'grpc') {
          vlessProxy['grpc-opts'] = {
            'grpc-service-name': extra['grpcServiceName'] ?? '',
          };
        }

        return vlessProxy;
      case ProxyProtocol.trojan:
        final trojanProxy = <String, dynamic>{
          'name': node.name,
          'type': 'trojan',
          'server': node.address,
          'port': node.port,
          'password': extra['password'] ?? '',
          'sni': extra['sni'] ?? node.address,
        };

        if (extra['allowInsecure'] == true) {
          trojanProxy['skip-cert-verify'] = true;
        }

        // WebSocket 传输
        if ((extra['type'] ?? 'tcp') == 'ws') {
          trojanProxy['network'] = 'ws';
          trojanProxy['ws-opts'] = {
            'path': extra['wsPath'] ?? '/',
            if (extra['wsHost'] != null) 'headers': {'Host': extra['wsHost']},
          };
        }

        // gRPC 传输
        if ((extra['type'] ?? 'tcp') == 'grpc') {
          trojanProxy['network'] = 'grpc';
          trojanProxy['grpc-opts'] = {
            'grpc-service-name': extra['grpcServiceName'] ?? '',
          };
        }

        return trojanProxy;
      case ProxyProtocol.shadowsocks:
        return {
          'name': node.name,
          'type': 'ss',
          'server': node.address,
          'port': node.port,
          'cipher': extra['method'] ?? 'aes-256-gcm',
          'password': extra['password'] ?? '',
        };
      case ProxyProtocol.hysteria2:
        return {
          'name': node.name,
          'type': 'hysteria2',
          'server': node.address,
          'port': node.port,
          'password': extra['password'] ?? '',
          'sni': extra['sni'] ?? node.address,
        };
      case ProxyProtocol.hysteria:
        return {
          'name': node.name,
          'type': 'hysteria',
          'server': node.address,
          'port': node.port,
          'auth': extra['auth'] ?? extra['password'] ?? '',
          'sni': extra['sni'] ?? node.address,
        };
      case ProxyProtocol.tuic:
        return {
          'name': node.name,
          'type': 'tuic',
          'server': node.address,
          'port': node.port,
          'uuid': extra['uuid'] ?? '',
          'password': extra['password'] ?? '',
          'sni': extra['sni'] ?? node.address,
        };
      default:
        return {
          'name': node.name,
          'type': 'socks5',
          'server': node.address,
          'port': node.port,
        };
    }
  }
}
