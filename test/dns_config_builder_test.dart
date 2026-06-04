import 'package:flutter_test/flutter_test.dart';
import 'package:proxcore/models/config.dart';
import 'package:proxcore/utils/adapters/dns_config_builder.dart';

/// DnsConfigBuilder 单元测试
///
/// 覆盖三种内核的 DNS 配置生成（sing-box / mihomo / v2ray）
/// 验证各种 DNS 模式（system / custom / doh / dot）的输出
void main() {
  group('DnsConfigBuilder.buildSingbox', () {
    test('system 模式返回空 Map', () {
      final dns = DnsConfig(mode: DnsMode.system);
      expect(DnsConfigBuilder.buildSingbox(dns), isEmpty);
    });

    test('custom 模式生成 remote + fallback servers', () {
      final dns = DnsConfig(
        mode: DnsMode.custom,
        servers: ['1.1.1.1', '8.8.8.8'],
        fallbackServers: ['114.114.114.114'],
      );
      final result = DnsConfigBuilder.buildSingbox(dns);
      final dnsCfg = result['dns'] as Map<String, dynamic>;
      final servers = dnsCfg['servers'] as List;

      // 2 remote + 1 fallback = 3 servers
      expect(servers.length, 3);
      expect(servers[0]['address'], '1.1.1.1');
      expect(servers[2]['address'], '114.114.114.114');
    });

    test('doh 模式使用 dohUrl', () {
      final dns = DnsConfig(
        mode: DnsMode.doh,
        dohUrl: 'https://dns.quad9.net/dns-query',
        fallbackServers: ['1.1.1.1'],
      );
      final result = DnsConfigBuilder.buildSingbox(dns);
      final servers =
          (result['dns'] as Map<String, dynamic>)['servers'] as List;
      expect(servers[0]['address'], 'https://dns.quad9.net/dns-query');
    });

    test('dot 模式使用 tls:// 前缀', () {
      final dns = DnsConfig(
        mode: DnsMode.dot,
        dotServer: 'dns.google',
        fallbackServers: [],
      );
      final result = DnsConfigBuilder.buildSingbox(dns);
      final servers =
          (result['dns'] as Map<String, dynamic>)['servers'] as List;
      expect(servers[0]['address'], 'tls://dns.google');
    });

    test('remoteResolve 控制 strategy 字段', () {
      final dns = DnsConfig(
        mode: DnsMode.custom,
        servers: ['1.1.1.1'],
        fallbackServers: [],
        remoteResolve: true,
      );
      final result = DnsConfigBuilder.buildSingbox(dns);
      final dnsCfg = result['dns'] as Map<String, dynamic>;
      expect(dnsCfg['strategy'], 'prefer_ipv4');

      final dns2 = DnsConfig(
        mode: DnsMode.custom,
        servers: ['1.1.1.1'],
        fallbackServers: [],
        remoteResolve: false,
      );
      final result2 = DnsConfigBuilder.buildSingbox(dns2);
      final dnsCfg2 = result2['dns'] as Map<String, dynamic>;
      expect(dnsCfg2['strategy'], 'ipv4_only');
    });

    test('包含出口 DNS 规则', () {
      final dns = DnsConfig(
        mode: DnsMode.custom,
        servers: ['1.1.1.1'],
        fallbackServers: ['114.114.114.114'],
      );
      final result = DnsConfigBuilder.buildSingbox(dns);
      final rules = (result['dns'] as Map<String, dynamic>)['rules'] as List;
      expect(rules.length, 1);
      expect(rules[0]['outbound'], 'any');
    });
  });

  group('DnsConfigBuilder.buildMihomo', () {
    test('system 模式返回空 Map', () {
      final dns = DnsConfig(mode: DnsMode.system);
      expect(DnsConfigBuilder.buildMihomo(dns), isEmpty);
    });

    test('非 system 模式生成 fake-ip DNS 配置', () {
      final dns = DnsConfig(
        mode: DnsMode.custom,
        servers: ['1.1.1.1', '8.8.8.8'],
        fallbackServers: ['114.114.114.114'],
      );
      final result = DnsConfigBuilder.buildMihomo(dns);
      final dnsCfg = result['dns'] as Map<String, dynamic>;

      expect(dnsCfg['enable'], true);
      expect(dnsCfg['enhanced-mode'], 'fake-ip');
      expect(dnsCfg['nameserver'], ['1.1.1.1', '8.8.8.8']);
      expect(dnsCfg['fallback'], ['114.114.114.114']);
    });

    test('使用 0.0.0.0:1053 监听', () {
      final dns = DnsConfig(mode: DnsMode.doh, dohUrl: 'https://dns.google');
      final result = DnsConfigBuilder.buildMihomo(dns);
      final dnsCfg = result['dns'] as Map<String, dynamic>;
      expect(dnsCfg['listen'], '0.0.0.0:1053');
    });
  });

  group('DnsConfigBuilder.buildV2ray', () {
    test('system 模式返回空 Map', () {
      final dns = DnsConfig(mode: DnsMode.system);
      expect(DnsConfigBuilder.buildV2ray(dns), isEmpty);
    });

    test('servers 列表用 skipFallback 区分主/备用', () {
      final dns = DnsConfig(
        mode: DnsMode.custom,
        servers: ['1.1.1.1'],
        fallbackServers: ['114.114.114.114'],
      );
      final result = DnsConfigBuilder.buildV2ray(dns);
      final servers =
          (result['dns'] as Map<String, dynamic>)['servers'] as List;

      expect(servers.length, 2);
      expect(servers[0]['address'], '1.1.1.1');
      expect(servers[0]['skipFallback'], false);
      expect(servers[1]['address'], '114.114.114.114');
      expect(servers[1]['skipFallback'], true);
    });

    test('queryStrategy 为 UseIP', () {
      final dns = DnsConfig(
        mode: DnsMode.custom,
        servers: ['1.1.1.1'],
        fallbackServers: [],
      );
      final result = DnsConfigBuilder.buildV2ray(dns);
      final dnsCfg = result['dns'] as Map<String, dynamic>;
      expect(dnsCfg['queryStrategy'], 'UseIP');
    });
  });
}
