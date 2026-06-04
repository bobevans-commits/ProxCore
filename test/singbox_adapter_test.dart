import 'package:flutter_test/flutter_test.dart';
import 'package:proxcore/models/config.dart';
import 'package:proxcore/utils/adapters/singbox_adapter.dart';

/// SingboxAdapter 单元测试
///
/// 覆盖 9 种协议的出站转换：
/// VMess / VLESS / Trojan / Shadowsocks / Hysteria2 / Hysteria / TUIC / Naive / WireGuard
/// 以及各协议的特殊配置：TLS、Reality、传输层（ws/grpc/http）
void main() {
  group('SingboxAdapter.nodeToOutbound - 协议类型', () {
    test('VMess 基础配置', () {
      final node = NodeConfig(
        id: '1',
        name: 'vmess-node',
        protocol: ProxyProtocol.vmess,
        address: '1.2.3.4',
        port: 443,
        extra: {
          'uuid': 'u-1',
          'alterId': 0,
          'security': 'auto',
          'network': 'tcp',
        },
      );
      final outbound = SingboxAdapter.nodeToOutbound(node);
      expect(outbound.type, 'vmess');
      expect(outbound.tag, 'proxy');
      final opts = outbound.options;
      expect(opts['server'], '1.2.3.4');
      expect(opts['server_port'], 443);
      expect(opts['uuid'], 'u-1');
      expect(opts['security'], 'auto');
    });

    test('VMess 启用 TLS + SNI', () {
      final node = NodeConfig(
        id: '1',
        name: 'vmess-tls',
        protocol: ProxyProtocol.vmess,
        address: '1.2.3.4',
        port: 443,
        extra: {
          'uuid': 'u-1',
          'alterId': 0,
          'security': 'aes-128-gcm',
          'network': 'tcp',
          'tls': true,
          'sni': 'example.com',
          'allowInsecure': false,
        },
      );
      final outbound = SingboxAdapter.nodeToOutbound(node);
      final opts = outbound.options;
      expect(opts['tls'], isA<Map>());
      final tls = opts['tls'] as Map<String, dynamic>;
      expect(tls['enabled'], true);
      expect(tls['server_name'], 'example.com');
    });

    test('VMess WebSocket 传输', () {
      final node = NodeConfig(
        id: '1',
        name: 'vmess-ws',
        protocol: ProxyProtocol.vmess,
        address: '1.2.3.4',
        port: 443,
        extra: {
          'uuid': 'u-1',
          'alterId': 0,
          'network': 'ws',
          'wsPath': '/ws',
          'wsHost': 'cdn.example.com',
        },
      );
      final outbound = SingboxAdapter.nodeToOutbound(node);
      final transport = outbound.options['transport'] as Map<String, dynamic>;
      expect(transport['type'], 'ws');
      expect(transport['path'], '/ws');
      expect(transport['headers']['Host'], 'cdn.example.com');
    });

    test('VMess gRPC 传输', () {
      final node = NodeConfig(
        id: '1',
        name: 'vmess-grpc',
        protocol: ProxyProtocol.vmess,
        address: '1.2.3.4',
        port: 443,
        extra: {
          'uuid': 'u-1',
          'alterId': 0,
          'network': 'grpc',
          'grpcServiceName': 'GunService',
        },
      );
      final outbound = SingboxAdapter.nodeToOutbound(node);
      final transport = outbound.options['transport'] as Map<String, dynamic>;
      expect(transport['type'], 'grpc');
      expect(transport['service_name'], 'GunService');
    });

    test('VLESS 基础配置', () {
      final node = NodeConfig(
        id: '1',
        name: 'vless-node',
        protocol: ProxyProtocol.vless,
        address: '1.2.3.4',
        port: 443,
        extra: {'uuid': 'u-2'},
      );
      final outbound = SingboxAdapter.nodeToOutbound(node);
      expect(outbound.type, 'vless');
      expect(outbound.options['uuid'], 'u-2');
    });

    test('VLESS + Reality + WebSocket', () {
      final node = NodeConfig(
        id: '1',
        name: 'vless-reality',
        protocol: ProxyProtocol.vless,
        address: '1.2.3.4',
        port: 443,
        extra: {
          'uuid': 'u-2',
          'flow': 'xtls-rprx-vision',
          'security': 'reality',
          'sni': 'www.microsoft.com',
          'realityPublicKey': 'pub-key',
          'realityShortId': 'short',
          'fingerprint': 'chrome',
          'type': 'ws',
          'wsPath': '/path',
          'wsHost': 'ws.example.com',
        },
      );
      final outbound = SingboxAdapter.nodeToOutbound(node);
      final opts = outbound.options;
      expect(opts['flow'], 'xtls-rprx-vision');
      final tls = opts['tls'] as Map<String, dynamic>;
      expect(tls['enabled'], true);
      expect(tls['server_name'], 'www.microsoft.com');
      final reality = tls['reality'] as Map<String, dynamic>;
      expect(reality['enabled'], true);
      expect(reality['public_key'], 'pub-key');
      expect(reality['short_id'], 'short');
      final utls = tls['utls'] as Map<String, dynamic>;
      expect(utls['fingerprint'], 'chrome');
      final transport = opts['transport'] as Map<String, dynamic>;
      expect(transport['type'], 'ws');
    });

    test('Trojan + TLS + gRPC', () {
      final node = NodeConfig(
        id: '1',
        name: 'trojan-grpc',
        protocol: ProxyProtocol.trojan,
        address: '1.2.3.4',
        port: 443,
        extra: {
          'password': 'pw-1',
          'sni': 'cdn.example.com',
          'type': 'grpc',
          'grpcServiceName': 'TROJAN',
        },
      );
      final outbound = SingboxAdapter.nodeToOutbound(node);
      final opts = outbound.options;
      expect(opts['password'], 'pw-1');
      final tls = opts['tls'] as Map<String, dynamic>;
      expect(tls['server_name'], 'cdn.example.com');
      final transport = opts['transport'] as Map<String, dynamic>;
      expect(transport['type'], 'grpc');
      expect(transport['service_name'], 'TROJAN');
    });

    test('Shadowsocks 基础配置', () {
      final node = NodeConfig(
        id: '1',
        name: 'ss-node',
        protocol: ProxyProtocol.shadowsocks,
        address: '1.2.3.4',
        port: 8388,
        extra: {'method': 'chacha20-ietf-poly1305', 'password': 'ss-pw'},
      );
      final outbound = SingboxAdapter.nodeToOutbound(node);
      expect(outbound.type, 'shadowsocks');
      final opts = outbound.options;
      expect(opts['method'], 'chacha20-ietf-poly1305');
      expect(opts['password'], 'ss-pw');
    });

    test('Hysteria2 基础配置', () {
      final node = NodeConfig(
        id: '1',
        name: 'hy2',
        protocol: ProxyProtocol.hysteria2,
        address: '1.2.3.4',
        port: 443,
        extra: {'password': 'hy2-pw', 'sni': 'hy.example.com'},
      );
      final outbound = SingboxAdapter.nodeToOutbound(node);
      expect(outbound.type, 'hysteria2');
      final opts = outbound.options;
      expect(opts['password'], 'hy2-pw');
      final tls = opts['tls'] as Map<String, dynamic>;
      expect(tls['server_name'], 'hy.example.com');
    });

    test('Hysteria 1.x 配置（auth 字段）', () {
      final node = NodeConfig(
        id: '1',
        name: 'hy1',
        protocol: ProxyProtocol.hysteria,
        address: '1.2.3.4',
        port: 443,
        extra: {'auth': 'hy1-auth', 'sni': 'hy.example.com'},
      );
      final outbound = SingboxAdapter.nodeToOutbound(node);
      expect(outbound.type, 'hysteria');
      expect(outbound.options['auth'], 'hy1-auth');
    });

    test('TUIC 配置 + alpn=h3', () {
      final node = NodeConfig(
        id: '1',
        name: 'tuic',
        protocol: ProxyProtocol.tuic,
        address: '1.2.3.4',
        port: 443,
        extra: {
          'uuid': 'tuic-uuid',
          'password': 'tuic-pw',
          'sni': 'tuic.example.com',
        },
      );
      final outbound = SingboxAdapter.nodeToOutbound(node);
      expect(outbound.type, 'tuic');
      final opts = outbound.options;
      expect(opts['uuid'], 'tuic-uuid');
      expect(opts['password'], 'tuic-pw');
      final tls = opts['tls'] as Map<String, dynamic>;
      expect(tls['alpn'], ['h3']);
    });

    test('NaiveProxy 配置（username + password）', () {
      final node = NodeConfig(
        id: '1',
        name: 'naive',
        protocol: ProxyProtocol.naive,
        address: '1.2.3.4',
        port: 443,
        extra: {
          'username': 'user1',
          'password': 'naive-pw',
          'sni': 'naive.example.com',
        },
      );
      final outbound = SingboxAdapter.nodeToOutbound(node);
      expect(outbound.type, 'naive');
      expect(outbound.options['username'], 'user1');
      expect(outbound.options['password'], 'naive-pw');
    });

    test('WireGuard 配置（string 类型的 localAddress）', () {
      final node = NodeConfig(
        id: '1',
        name: 'wg',
        protocol: ProxyProtocol.wireguard,
        address: '1.2.3.4',
        port: 51820,
        extra: {
          'privateKey': 'priv',
          'peerPublicKey': 'peer-pub',
          'localAddress': '10.0.0.2/32',
        },
      );
      final outbound = SingboxAdapter.nodeToOutbound(node);
      expect(outbound.type, 'wireguard');
      final opts = outbound.options;
      expect(opts['private_key'], 'priv');
      expect(opts['peer_public_key'], 'peer-pub');
      expect(opts['local_address'], ['10.0.0.2/32']);
    });
  });

  group('SingboxAdapter.toConfig', () {
    test('包含 socks + http 入站', () {
      final proxyConfig = ProxyConfig(socksPort: 1080, httpPort: 1081);
      final config = SingboxAdapter.toConfig(proxyConfig, null, []);
      final inbounds = config['inbounds'] as List;
      final types = inbounds.map((i) => (i as Map)['type']).toList();
      expect(types, containsAll(['socks', 'http']));
    });

    test('TUN 开启时追加 tun 入站', () {
      final proxyConfig = ProxyConfig(tunEnabled: true);
      final config = SingboxAdapter.toConfig(proxyConfig, null, []);
      final inbounds = config['inbounds'] as List;
      final types = inbounds.map((i) => (i as Map)['type']).toList();
      expect(types, contains('tun'));
    });

    test('有活跃节点时包含 auto (urltest) 出站', () {
      final proxyConfig = ProxyConfig();
      final node = NodeConfig(
        id: '1',
        name: 'n1',
        protocol: ProxyProtocol.vmess,
        address: '1.1.1.1',
        port: 443,
        extra: {'uuid': 'u'},
      );
      final config = SingboxAdapter.toConfig(proxyConfig, node, []);
      final outbounds = config['outbounds'] as List;
      final tags = outbounds.map((o) => (o as Map)['tag']).toList();
      expect(tags, contains('proxy'));
      expect(tags, contains('auto'));
    });

    test('无活跃节点时 finalOutbound 指向 direct', () {
      final proxyConfig = ProxyConfig();
      final config = SingboxAdapter.toConfig(proxyConfig, null, []);
      final route = config['route'] as Map<String, dynamic>;
      expect(route['final'], 'direct');
    });

    test('广告屏蔽开启时插入 ads rule', () {
      final proxyConfig = ProxyConfig(adBlocking: true);
      final config = SingboxAdapter.toConfig(proxyConfig, null, []);
      final rules = (config['route'] as Map<String, dynamic>)['rules'] as List;
      final hasAdRule = rules.any(
        (r) =>
            (r as Map).containsKey('geosite') &&
            (r['geosite'] as List).contains('category-ads-all'),
      );
      expect(hasAdRule, true);
    });

    test('lanSharing=true 时 listenAddress 为 0.0.0.0', () {
      final proxyConfig = ProxyConfig(lanSharing: true);
      final config = SingboxAdapter.toConfig(proxyConfig, null, []);
      final inbounds = config['inbounds'] as List;
      final socks = inbounds.firstWhere((i) => (i as Map)['type'] == 'socks');
      expect((socks as Map)['listen'], '0.0.0.0');
    });

    test('lanSharing=false 时 listenAddress 为 127.0.0.1', () {
      final proxyConfig = ProxyConfig(lanSharing: false);
      final config = SingboxAdapter.toConfig(proxyConfig, null, []);
      final inbounds = config['inbounds'] as List;
      final socks = inbounds.firstWhere((i) => (i as Map)['type'] == 'socks');
      expect((socks as Map)['listen'], '127.0.0.1');
    });

    test('包含 Clash API 实验性配置', () {
      final config = SingboxAdapter.toConfig(ProxyConfig(), null, []);
      final exp = config['experimental'] as Map<String, dynamic>;
      expect(exp.containsKey('clash_api'), true);
    });
  });
}
