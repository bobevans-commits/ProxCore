import 'package:flutter_test/flutter_test.dart';
import 'package:proxcore/models/config.dart';
import 'package:proxcore/utils/adapters/mihomo_adapter.dart';
import 'package:proxcore/utils/adapters/v2ray_adapter.dart';

/// MihomoAdapter 单元测试
///
/// 覆盖支持的 7 种协议：VMess / VLESS / Trojan / Shadowsocks /
/// Hysteria2 / Hysteria / TUIC（其他降级为 socks5）
void main() {
  group('MihomoAdapter.nodeToProxy', () {
    test('VMess + TLS + WS', () {
      final node = NodeConfig(
        id: '1',
        name: 'vm',
        protocol: ProxyProtocol.vmess,
        address: '1.2.3.4',
        port: 443,
        extra: {
          'uuid': 'u',
          'alterId': 0,
          'security': 'auto',
          'network': 'ws',
          'tls': true,
          'sni': 'ex.com',
          'wsPath': '/ws',
          'wsHost': 'ws.ex.com',
        },
      );
      final proxy = MihomoAdapter.nodeToProxy(node);
      expect(proxy['type'], 'vmess');
      expect(proxy['name'], 'vm');
      expect(proxy['network'], 'ws');
      expect(proxy['tls'], true);
      expect(proxy['servername'], 'ex.com');
      final wsOpts = proxy['ws-opts'] as Map<String, dynamic>;
      expect(wsOpts['path'], '/ws');
    });

    test('VMess gRPC transport', () {
      final node = NodeConfig(
        id: '1',
        name: 'vm-grpc',
        protocol: ProxyProtocol.vmess,
        address: '1.2.3.4',
        port: 443,
        extra: {
          'uuid': 'u',
          'alterId': 0,
          'security': 'auto',
          'network': 'grpc',
          'grpcServiceName': 'MyService',
        },
      );
      final proxy = MihomoAdapter.nodeToProxy(node);
      final grpcOpts = proxy['grpc-opts'] as Map<String, dynamic>;
      expect(grpcOpts['grpc-service-name'], 'MyService');
    });

    test('VLESS + Reality', () {
      final node = NodeConfig(
        id: '1',
        name: 'vless',
        protocol: ProxyProtocol.vless,
        address: '1.2.3.4',
        port: 443,
        extra: {
          'uuid': 'u',
          'security': 'reality',
          'sni': 'msft.com',
          'realityPublicKey': 'pub',
          'realityShortId': 'sid',
        },
      );
      final proxy = MihomoAdapter.nodeToProxy(node);
      expect(proxy['type'], 'vless');
      expect(proxy['tls'], true);
      expect(proxy['servername'], 'msft.com');
      final realityOpts = proxy['reality-opts'] as Map<String, dynamic>;
      expect(realityOpts['public-key'], 'pub');
      expect(realityOpts['short-id'], 'sid');
    });

    test('VLESS + Flow', () {
      final node = NodeConfig(
        id: '1',
        name: 'vless-flow',
        protocol: ProxyProtocol.vless,
        address: '1.2.3.4',
        port: 443,
        extra: {'uuid': 'u', 'flow': 'xtls-rprx-vision'},
      );
      final proxy = MihomoAdapter.nodeToProxy(node);
      expect(proxy['flow'], 'xtls-rprx-vision');
    });

    test('Trojan + WS + skip-cert-verify', () {
      final node = NodeConfig(
        id: '1',
        name: 'tj',
        protocol: ProxyProtocol.trojan,
        address: '1.2.3.4',
        port: 443,
        extra: {
          'password': 'pw',
          'sni': 'tj.com',
          'type': 'ws',
          'wsPath': '/ws',
          'allowInsecure': true,
        },
      );
      final proxy = MihomoAdapter.nodeToProxy(node);
      expect(proxy['type'], 'trojan');
      expect(proxy['network'], 'ws');
      expect(proxy['skip-cert-verify'], true);
    });

    test('Shadowsocks 基础配置', () {
      final node = NodeConfig(
        id: '1',
        name: 'ss',
        protocol: ProxyProtocol.shadowsocks,
        address: '1.2.3.4',
        port: 8388,
        extra: {'method': 'aes-128-gcm', 'password': 'ss-pw'},
      );
      final proxy = MihomoAdapter.nodeToProxy(node);
      expect(proxy['type'], 'ss');
      expect(proxy['cipher'], 'aes-128-gcm');
      expect(proxy['password'], 'ss-pw');
    });

    test('Hysteria2 基础配置', () {
      final node = NodeConfig(
        id: '1',
        name: 'hy2',
        protocol: ProxyProtocol.hysteria2,
        address: '1.2.3.4',
        port: 443,
        extra: {'password': 'hy2-pw', 'sni': 'hy.com'},
      );
      final proxy = MihomoAdapter.nodeToProxy(node);
      expect(proxy['type'], 'hysteria2');
      expect(proxy['password'], 'hy2-pw');
      expect(proxy['sni'], 'hy.com');
    });

    test('Hysteria 1.x 配置', () {
      final node = NodeConfig(
        id: '1',
        name: 'hy1',
        protocol: ProxyProtocol.hysteria,
        address: '1.2.3.4',
        port: 443,
        extra: {'auth': 'hy1-pw', 'sni': 'hy.com'},
      );
      final proxy = MihomoAdapter.nodeToProxy(node);
      expect(proxy['type'], 'hysteria');
      expect(proxy['auth'], 'hy1-pw');
    });

    test('TUIC 配置', () {
      final node = NodeConfig(
        id: '1',
        name: 'tuic',
        protocol: ProxyProtocol.tuic,
        address: '1.2.3.4',
        port: 443,
        extra: {'uuid': 'u', 'password': 'pw', 'sni': 'tuic.com'},
      );
      final proxy = MihomoAdapter.nodeToProxy(node);
      expect(proxy['type'], 'tuic');
      expect(proxy['uuid'], 'u');
    });

    test('不支持的协议降级为 socks5', () {
      final node = NodeConfig(
        id: '1',
        name: 'wg',
        protocol: ProxyProtocol.wireguard,
        address: '1.2.3.4',
        port: 51820,
        extra: {},
      );
      final proxy = MihomoAdapter.nodeToProxy(node);
      expect(proxy['type'], 'socks5');
    });
  });

  group('MihomoAdapter.toConfig', () {
    test('基础端口和 mode', () {
      final config = ProxyConfig(
        socksPort: 1080,
        httpPort: 1081,
        localPort: 1080,
      );
      final mihomo = MihomoAdapter.toConfig(config, null, []);
      expect(mihomo['mixed-port'], 1080);
      // socksPort 与 mixed-port 相同时不重复输出，避免内核启动报错
      expect(mihomo['socks-port'], isNull);
      expect(mihomo['port'], 1081);
      expect(mihomo['external-controller'], '127.0.0.1:9090');
      expect(mihomo['mode'], 'rule');
    });

    test('lanSharing 开启时 bind-address 为 *', () {
      final mihomo = MihomoAdapter.toConfig(
        ProxyConfig(lanSharing: true),
        null,
        [],
      );
      expect(mihomo['allow-lan'], true);
      expect(mihomo['bind-address'], '*');
    });

    test('TUN 开启时包含 tun 配置', () {
      final mihomo = MihomoAdapter.toConfig(
        ProxyConfig(tunEnabled: true),
        null,
        [],
      );
      expect((mihomo['tun'] as Map)['enable'], true);
    });

    test('有节点时包含 proxies 和 PROXY 组', () {
      final node = NodeConfig(
        id: '1',
        name: 'test-node',
        protocol: ProxyProtocol.shadowsocks,
        address: '1.1.1.1',
        port: 8388,
        extra: {'method': 'aes-256-gcm', 'password': 'pw'},
      );
      final mihomo = MihomoAdapter.toConfig(ProxyConfig(), node, []);
      expect(mihomo['proxies'], isA<List>());
      expect((mihomo['proxies'] as List).length, 1);
      final groups = mihomo['proxy-groups'] as List;
      expect(groups[0]['name'], 'PROXY');
      expect((groups[0]['proxies'] as List), contains('test-node'));
    });

    test('广告屏蔽开启时注入 ads 规则', () {
      final mihomo = MihomoAdapter.toConfig(
        ProxyConfig(adBlocking: true),
        null,
        [],
      );
      final rules = mihomo['rules'] as List;
      expect(rules.any((r) => r.toString().contains('category-ads-all')), true);
    });

    test('无节点时 MATCH 兜底指向 DIRECT', () {
      final mihomo = MihomoAdapter.toConfig(ProxyConfig(), null, []);
      final rules = mihomo['rules'] as List;
      expect(rules.last, 'MATCH,DIRECT');
    });
  });
}

/// V2rayAdapter 单元测试
void mainV2ray() {
  group('V2rayAdapter.nodeToOutbound', () {
    test('VMess + TLS + WS', () {
      final node = NodeConfig(
        id: '1',
        name: 'vm',
        protocol: ProxyProtocol.vmess,
        address: '1.2.3.4',
        port: 443,
        extra: {
          'uuid': 'u',
          'alterId': 0,
          'security': 'auto',
          'network': 'ws',
          'tls': true,
          'sni': 'ex.com',
          'wsPath': '/ws',
          'wsHost': 'ws.ex.com',
        },
      );
      final outbound = V2rayAdapter.nodeToOutbound(node);
      expect(outbound['protocol'], 'vmess');
      final stream = outbound['streamSettings'] as Map<String, dynamic>;
      expect(stream['network'], 'ws');
      expect(stream['security'], 'tls');
      final vnext = (outbound['settings'] as Map)['vnext'] as List;
      expect(vnext[0]['users'][0]['id'], 'u');
    });

    test('VLESS + Reality', () {
      final node = NodeConfig(
        id: '1',
        name: 'vless',
        protocol: ProxyProtocol.vless,
        address: '1.2.3.4',
        port: 443,
        extra: {
          'uuid': 'u',
          'security': 'reality',
          'sni': 'msft.com',
          'realityPublicKey': 'pub',
          'realityShortId': 'sid',
          'fingerprint': 'chrome',
        },
      );
      final outbound = V2rayAdapter.nodeToOutbound(node);
      final stream = outbound['streamSettings'] as Map<String, dynamic>;
      final reality = stream['realitySettings'] as Map<String, dynamic>;
      expect(reality['serverName'], 'msft.com');
      expect(reality['publicKey'], 'pub');
      expect(reality['shortId'], 'sid');
    });

    test('Trojan 基础配置', () {
      final node = NodeConfig(
        id: '1',
        name: 'tj',
        protocol: ProxyProtocol.trojan,
        address: '1.2.3.4',
        port: 443,
        extra: {'password': 'pw', 'sni': 'tj.com'},
      );
      final outbound = V2rayAdapter.nodeToOutbound(node);
      expect(outbound['protocol'], 'trojan');
      final servers = (outbound['settings'] as Map)['servers'] as List;
      expect(servers[0]['password'], 'pw');
    });

    test('Shadowsocks 基础配置', () {
      final node = NodeConfig(
        id: '1',
        name: 'ss',
        protocol: ProxyProtocol.shadowsocks,
        address: '1.2.3.4',
        port: 8388,
        extra: {'method': 'aes-256-gcm', 'password': 'pw'},
      );
      final outbound = V2rayAdapter.nodeToOutbound(node);
      expect(outbound['protocol'], 'shadowsocks');
    });

    test('不支持的协议降级为 socks', () {
      final node = NodeConfig(
        id: '1',
        name: 'wg',
        protocol: ProxyProtocol.wireguard,
        address: '1.2.3.4',
        port: 51820,
        extra: {},
      );
      final outbound = V2rayAdapter.nodeToOutbound(node);
      expect(outbound['protocol'], 'socks');
    });
  });

  group('V2rayAdapter.toConfig', () {
    test('包含 socks + http 入站', () {
      final v2 = V2rayAdapter.toConfig(ProxyConfig(), null, []);
      final inbounds = v2['inbounds'] as List;
      final protocols = inbounds.map((i) => (i as Map)['protocol']).toList();
      expect(protocols, containsAll(['socks', 'http']));
    });

    test('TUN 开启时追加 dokodemo-door 入站', () {
      final v2 = V2rayAdapter.toConfig(ProxyConfig(tunEnabled: true), null, []);
      final inbounds = v2['inbounds'] as List;
      final hasDokodemo = inbounds.any(
        (i) => (i as Map)['protocol'] == 'dokodemo-door',
      );
      expect(hasDokodemo, true);
    });

    test('有节点时 outbounds 第一个是 proxy', () {
      final node = NodeConfig(
        id: '1',
        name: 'n',
        protocol: ProxyProtocol.shadowsocks,
        address: '1.1.1.1',
        port: 8388,
        extra: {'method': 'aes-256-gcm', 'password': 'pw'},
      );
      final v2 = V2rayAdapter.toConfig(ProxyConfig(), node, []);
      final outbounds = v2['outbounds'] as List;
      expect(outbounds.first['tag'], 'proxy');
      expect(outbounds.first['protocol'], 'shadowsocks');
    });

    test('无节点时 outbounds 包含 direct + block', () {
      final v2 = V2rayAdapter.toConfig(ProxyConfig(), null, []);
      final outbounds = v2['outbounds'] as List;
      final tags = outbounds.map((o) => (o as Map)['tag']).toList();
      expect(tags, contains('direct'));
      expect(tags, contains('block'));
    });

    test('广告屏蔽开启时插入 geosite ads 规则', () {
      final v2 = V2rayAdapter.toConfig(ProxyConfig(adBlocking: true), null, []);
      final rules = (v2['routing'] as Map)['rules'] as List;
      final hasAd = rules.any(
        (r) => (r as Map).toString().contains('category-ads-all'),
      );
      expect(hasAd, true);
    });

    test('domain/keyword/suffix/ip_cidr 各类规则映射正确', () {
      final rules = [
        RoutingRule(
          id: '1',
          name: 'a',
          type: 'domain',
          match: 'a.com',
          target: 'proxy',
          enabled: true,
        ),
        RoutingRule(
          id: '2',
          name: 'b',
          type: 'domain_keyword',
          match: 'kw',
          target: 'block',
          enabled: true,
        ),
        RoutingRule(
          id: '3',
          name: 'c',
          type: 'domain_suffix',
          match: 'suffix.com',
          target: 'direct',
          enabled: true,
        ),
        RoutingRule(
          id: '4',
          name: 'd',
          type: 'ip_cidr',
          match: '192.168.0.0/16',
          target: 'proxy',
          enabled: true,
        ),
      ];
      final v2 = V2rayAdapter.toConfig(ProxyConfig(), null, rules);
      final v2Rules = (v2['routing'] as Map)['rules'] as List;
      expect(v2Rules.length, 4);
    });
  });
}
