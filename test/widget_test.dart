import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:proxcore/models/config.dart';
import 'package:proxcore/models/singbox_config.dart';
import 'package:proxcore/utils/app_utils.dart';
import 'package:proxcore/utils/config_adapter.dart';

void main() {
  group('KernelType', () {
    test('fromName returns correct type', () {
      expect(KernelType.fromName('singbox'), KernelType.singbox);
      expect(KernelType.fromName('mihomo'), KernelType.mihomo);
      expect(KernelType.fromName('v2ray'), KernelType.v2ray);
    });

    test('fromName returns singbox for unknown name', () {
      expect(KernelType.fromName('unknown'), KernelType.singbox);
    });

    test('label is correct', () {
      expect(KernelType.singbox.label, 'sing-box');
      expect(KernelType.mihomo.label, 'mihomo');
      expect(KernelType.v2ray.label, 'v2ray');
    });
  });

  group('KernelStatus', () {
    test('description is not empty', () {
      for (final status in KernelStatus.values) {
        expect(status.description, isNotEmpty);
      }
    });
  });

  group('ProxyProtocol', () {
    test('fromString returns correct protocol', () {
      expect(ProxyProtocol.fromString('vmess'), ProxyProtocol.vmess);
      expect(ProxyProtocol.fromString('vless'), ProxyProtocol.vless);
      expect(ProxyProtocol.fromString('trojan'), ProxyProtocol.trojan);
      expect(
        ProxyProtocol.fromString('shadowsocks'),
        ProxyProtocol.shadowsocks,
      );
    });

    test('fromString is case insensitive', () {
      expect(ProxyProtocol.fromString('VMESS'), ProxyProtocol.vmess);
      expect(ProxyProtocol.fromString('VLess'), ProxyProtocol.vless);
    });

    test('fromString returns vmess for unknown', () {
      expect(ProxyProtocol.fromString('unknown'), ProxyProtocol.vmess);
    });

    test('label is correct', () {
      expect(ProxyProtocol.vmess.label, 'VMess');
      expect(ProxyProtocol.vless.label, 'VLESS');
      expect(ProxyProtocol.trojan.label, 'Trojan');
    });
  });

  group('NodeConfig', () {
    test('toJson and fromJson round-trip', () {
      final node = NodeConfig(
        id: 'test-id',
        name: 'Test Node',
        protocol: ProxyProtocol.vmess,
        address: '1.2.3.4',
        port: 443,
        extra: {'uuid': 'test-uuid', 'alterId': 0},
      );

      final json = node.toJson();
      final restored = NodeConfig.fromJson(json);

      expect(restored.id, node.id);
      expect(restored.name, node.name);
      expect(restored.protocol, node.protocol);
      expect(restored.address, node.address);
      expect(restored.port, node.port);
      expect(restored.extra['uuid'], 'test-uuid');
    });

    test('fromJsonString works', () {
      final node = NodeConfig(
        id: 'test-id',
        name: 'Test Node',
        protocol: ProxyProtocol.trojan,
        address: '5.6.7.8',
        port: 8443,
      );

      final jsonString = node.toJsonString();
      final restored = NodeConfig.fromJsonString(jsonString);

      expect(restored.id, node.id);
      expect(restored.protocol, ProxyProtocol.trojan);
    });

    test('copyWith works', () {
      final node = NodeConfig(
        id: '1',
        name: 'Original',
        protocol: ProxyProtocol.vmess,
        address: '1.1.1.1',
        port: 443,
      );

      final copied = node.copyWith(name: 'Modified', port: 8443);
      expect(copied.name, 'Modified');
      expect(copied.port, 8443);
      expect(copied.id, '1');
      expect(copied.address, '1.1.1.1');
    });
  });

  group('ProxyConfig', () {
    test('default values', () {
      final config = ProxyConfig();
      expect(config.kernelType, KernelType.singbox);
      expect(config.localAddress, '127.0.0.1');
      expect(config.socksPort, 1080);
      expect(config.httpPort, 1081);
      expect(config.tunEnabled, false);
      expect(config.systemProxy, false);
      expect(config.nodes, isEmpty);
    });

    test('toJson and fromJson round-trip', () {
      final config = ProxyConfig(
        kernelType: KernelType.mihomo,
        socksPort: 2080,
        httpPort: 2081,
        tunEnabled: true,
        nodes: [
          NodeConfig(
            id: '1',
            name: 'Node1',
            protocol: ProxyProtocol.trojan,
            address: '1.2.3.4',
            port: 443,
          ),
        ],
      );

      final json = config.toJson();
      final restored = ProxyConfig.fromJson(json);

      expect(restored.kernelType, KernelType.mihomo);
      expect(restored.socksPort, 2080);
      expect(restored.httpPort, 2081);
      expect(restored.tunEnabled, true);
      expect(restored.nodes.length, 1);
      expect(restored.nodes[0].name, 'Node1');
    });
  });

  group('RoutingRule', () {
    test('toJson and fromJson round-trip', () {
      final rule = RoutingRule(
        id: 'rule-1',
        name: 'Block Ads',
        type: 'domain',
        match: 'ads.example.com',
        target: 'block',
        enabled: true,
      );

      final json = rule.toJson();
      final restored = RoutingRule.fromJson(json);

      expect(restored.id, 'rule-1');
      expect(restored.name, 'Block Ads');
      expect(restored.type, 'domain');
      expect(restored.match, 'ads.example.com');
      expect(restored.target, 'block');
      expect(restored.enabled, true);
    });

    test('typeOptions and targetOptions are not empty', () {
      expect(RoutingRule.typeOptions, isNotEmpty);
      expect(RoutingRule.targetOptions, isNotEmpty);
    });
  });

  group('SingboxConfig', () {
    test('defaultConfig has inbounds and outbounds', () {
      final config = SingboxConfig.defaultConfig();
      final json = config.toJson();

      expect(json['inbounds'], isNotNull);
      expect(json['outbounds'], isNotNull);
      expect((json['inbounds'] as List).length, 2);
      expect((json['outbounds'] as List).length, 2);
    });

    test('defaultConfig uses custom ports', () {
      final config = SingboxConfig.defaultConfig(
        socksPort: 2080,
        httpPort: 2081,
      );
      final json = config.toJson();
      final inbounds = json['inbounds'] as List;

      final socksInbound = inbounds.firstWhere((i) => i['type'] == 'socks');
      final httpInbound = inbounds.firstWhere((i) => i['type'] == 'http');

      expect(socksInbound['listen_port'], 2080);
      expect(httpInbound['listen_port'], 2081);
    });

    test('toJson produces valid JSON string', () {
      final config = SingboxConfig.defaultConfig();
      final jsonString = config.toJsonString();

      final parsed = jsonDecode(jsonString);
      expect(parsed, isA<Map>());
      expect(parsed['log'], isNotNull);
      expect(parsed['route'], isNotNull);
    });

    test('fromJson reconstructs config', () {
      final config = SingboxConfig.defaultConfig();
      final json = config.toJson();
      final restored = SingboxConfig.fromJson(json);

      expect(restored.inbounds.length, 2);
      expect(restored.outbounds.length, 2);
    });
  });

  group('AppUtils', () {
    test('formatBytes formats correctly', () {
      expect(AppUtils.formatBytes(0), '0 B');
      expect(AppUtils.formatBytes(512), '512 B');
      expect(AppUtils.formatBytes(1024), '1.0 KB');
      expect(AppUtils.formatBytes(1024 * 1024), '1.0 MB');
      expect(AppUtils.formatBytes(1024 * 1024 * 1024), '1.00 GB');
    });

    test('formatDuration formats correctly', () {
      expect(AppUtils.formatDuration(const Duration(seconds: 30)), '30s');
      expect(
        AppUtils.formatDuration(const Duration(minutes: 5, seconds: 30)),
        '5m 30s',
      );
      expect(
        AppUtils.formatDuration(
          const Duration(hours: 1, minutes: 30, seconds: 45),
        ),
        '1h 30m 45s',
      );
    });

    test('formatTimestamp formats correctly', () {
      final dt = DateTime(2024, 1, 15, 10, 30, 45);
      expect(AppUtils.formatTimestamp(dt), '2024-01-15 10:30:45');
    });

    test('isValidPort validates correctly', () {
      expect(AppUtils.isValidPort(0), false);
      expect(AppUtils.isValidPort(-1), false);
      expect(AppUtils.isValidPort(1), true);
      expect(AppUtils.isValidPort(80), true);
      expect(AppUtils.isValidPort(443), true);
      expect(AppUtils.isValidPort(65535), true);
      expect(AppUtils.isValidPort(65536), false);
    });

    test('isValidAddress validates correctly', () {
      expect(AppUtils.isValidAddress(''), false);
      expect(AppUtils.isValidAddress('1.2.3.4'), true);
      expect(AppUtils.isValidAddress('example.com'), true);
      expect(AppUtils.isValidAddress('sub.example.com'), true);
      expect(AppUtils.isValidAddress('not valid!'), false);
    });

    test('isValidUrl validates correctly', () {
      expect(AppUtils.isValidUrl('https://example.com'), true);
      expect(AppUtils.isValidUrl('http://example.com'), true);
      expect(AppUtils.isValidUrl('ftp://example.com'), false);
      expect(AppUtils.isValidUrl('not a url'), false);
    });

    test('protocolIcon returns non-empty string', () {
      for (final protocol in ProxyProtocol.values) {
        expect(AppUtils.protocolIcon(protocol), isNotEmpty);
      }
    });

    test('latencyLabel formats correctly', () {
      expect(AppUtils.latencyLabel(-1), '超时');
      expect(AppUtils.latencyLabel(0), '0 ms');
      expect(AppUtils.latencyLabel(50), '50 ms');
      expect(AppUtils.latencyLabel(200), '200 ms');
      expect(AppUtils.latencyLabel(1000), '1000 ms');
    });

    test('detectProtocol returns correct type', () {
      expect(AppUtils.detectProtocol('vmess://abc'), ProxyProtocol.vmess);
      expect(AppUtils.detectProtocol('vless://abc'), ProxyProtocol.vless);
      expect(AppUtils.detectProtocol('trojan://abc'), ProxyProtocol.trojan);
      expect(AppUtils.detectProtocol('ss://abc'), ProxyProtocol.shadowsocks);
      expect(
        AppUtils.detectProtocol('hysteria2://abc'),
        ProxyProtocol.hysteria2,
      );
      expect(AppUtils.detectProtocol('hy2://abc'), ProxyProtocol.hysteria2);
      expect(AppUtils.detectProtocol('hysteria://abc'), ProxyProtocol.hysteria);
      expect(AppUtils.detectProtocol('tuic://abc'), ProxyProtocol.tuic);
      expect(AppUtils.detectProtocol('unknown://abc'), isNull);
      expect(AppUtils.detectProtocol(''), isNull);
    });

    test('parseProxyLink throws for unknown protocol', () {
      expect(
        () => AppUtils.parseProxyLink('unknown://abc'),
        throwsFormatException,
      );
    });
  });

  group('ConfigAdapter', () {
    final testNode = NodeConfig(
      id: 'test-id',
      name: 'TestNode',
      protocol: ProxyProtocol.vmess,
      address: '1.2.3.4',
      port: 443,
      extra: {
        'uuid': 'test-uuid',
        'alterId': 0,
        'security': 'auto',
        'network': 'tcp',
      },
    );
    final testConfig = ProxyConfig(
      kernelType: KernelType.singbox,
      socksPort: 1080,
      httpPort: 1081,
    );

    test('toSingboxConfig produces valid sing-box config', () {
      final config = ConfigAdapter.toSingboxConfig(testConfig, testNode, []);
      expect(config['inbounds'], isNotNull);
      expect(config['outbounds'], isNotNull);
      expect(config['route'], isNotNull);
      final outbounds = config['outbounds'] as List;
      expect(outbounds.length, greaterThan(0));
      final firstOutbound = outbounds[0] as Map<String, dynamic>;
      expect(firstOutbound['type'], 'vmess');
      expect(firstOutbound['tag'], 'proxy');
    });

    test('toSingboxConfig with null node uses direct', () {
      final config = ConfigAdapter.toSingboxConfig(testConfig, null, []);
      final route = config['route'] as Map<String, dynamic>;
      expect(route['final'], 'direct');
    });

    test('toMihomoConfig produces valid mihomo config', () {
      final config = ConfigAdapter.toMihomoConfig(testConfig, testNode, []);
      expect(config['mixed-port'], 1080);
      expect(config['socks-port'], 1080);
      expect(config['port'], 1081);
      expect(config['mode'], 'rule');
      expect(config['rules'], isNotNull);
    });

    test('toV2rayConfig produces valid v2ray config', () {
      final config = ConfigAdapter.toV2rayConfig(testConfig, testNode, []);
      expect(config['log'], isNotNull);
      expect(config['inbounds'], isNotNull);
      expect(config['outbounds'], isNotNull);
      expect(config['routing'], isNotNull);
      final outbounds = config['outbounds'] as List;
      expect(outbounds.length, greaterThanOrEqualTo(2));
      final firstOutbound = outbounds[0] as Map<String, dynamic>;
      expect(firstOutbound['tag'], 'proxy');
      expect(firstOutbound['protocol'], 'vmess');
    });

    test('toSingboxConfig with routing rules', () {
      final rules = [
        RoutingRule(
          id: '1',
          name: 'Block',
          type: 'domain',
          match: 'ads.com',
          target: 'block',
          enabled: true,
        ),
        RoutingRule(
          id: '2',
          name: 'Direct',
          type: 'ip',
          match: '10.0.0.0',
          target: 'direct',
          enabled: true,
        ),
        RoutingRule(
          id: '3',
          name: 'Disabled',
          type: 'domain',
          match: 'skip.com',
          target: 'proxy',
          enabled: false,
        ),
      ];
      final config = ConfigAdapter.toSingboxConfig(testConfig, testNode, rules);
      final route = config['route'] as Map<String, dynamic>;
      final routeRules = route['rules'] as List;
      expect(routeRules.length, 2);
    });
  });

  group('ConfigAdapter.deepMerge', () {
    test('空 Map 合并', () {
      final m1 = <String, dynamic>{};
      final m2 = <String, dynamic>{'a': 1};
      final result = ConfigAdapter.deepMerge(m1, m2);
      expect(result['a'], 1);
    });

    test('简单 key 覆盖（map2 覆盖 map1）', () {
      final m1 = <String, dynamic>{'a': 1, 'b': 2};
      final m2 = <String, dynamic>{'b': 99, 'c': 3};
      final result = ConfigAdapter.deepMerge(m1, m2);
      expect(result['a'], 1);
      expect(result['b'], 99);
      expect(result['c'], 3);
    });

    test('嵌套 Map 递归合并', () {
      final m1 = <String, dynamic>{
        'a': {'x': 1, 'y': 2},
      };
      final m2 = <String, dynamic>{
        'a': {'y': 99, 'z': 3},
      };
      final result = ConfigAdapter.deepMerge(m1, m2);
      final a = result['a'] as Map<String, dynamic>;
      expect(a['x'], 1);
      expect(a['y'], 99);
      expect(a['z'], 3);
    });

    test('List/基本类型直接替换不递归', () {
      final m1 = <String, dynamic>{
        'list': [1, 2, 3],
      };
      final m2 = <String, dynamic>{
        'list': [4, 5],
      };
      final result = ConfigAdapter.deepMerge(m1, m2);
      expect(result['list'], [4, 5]);
    });

    test('不修改原 Map', () {
      final m1 = <String, dynamic>{'a': 1};
      final m2 = <String, dynamic>{'b': 2};
      ConfigAdapter.deepMerge(m1, m2);
      expect(m1.containsKey('b'), false);
      expect(m2.containsKey('a'), false);
    });

    test('非字符串 key 转换为字符串', () {
      final m1 = <dynamic, dynamic>{1: 'a'};
      final m2 = <dynamic, dynamic>{2: 'b'};
      final result = ConfigAdapter.deepMerge(m1, m2);
      expect(result['1'], 'a');
      expect(result['2'], 'b');
    });
  });
}
