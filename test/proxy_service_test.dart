// ProxyService 服务层单元测试
//
// 覆盖范围（不涉及 Process.start 内核进程）：
// - 初始化加载默认值
// - 节点增删改查与去重（addNode 单节点去重 / addNodes 批量去重）
// - 路由规则增删改
// - 配置更新与持久化往返
// - exportConfig / importConfig 导入导出
// - 空闲（停止）状态下不每秒触发 notifyListeners（回归测试）
//
// 依赖处理：
// - ConfigStorageService → SharedPreferences.setMockInitialValues mock
// - KernelManager → 传入未 init 的真实实例（测试路径不触及其 IO 方法）

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:proxcore/models/config.dart';
import 'package:proxcore/services/config_storage_service.dart';
import 'package:proxcore/services/kernel_manager.dart';
import 'package:proxcore/services/proxy_service.dart';

/// 构造测试用节点的辅助函数
NodeConfig _node(
  String id,
  String address,
  int port,
  ProxyProtocol protocol, {
  String name = 'node',
}) {
  return NodeConfig(
    id: id,
    name: name,
    protocol: protocol,
    address: address,
    port: port,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ConfigStorageService storage;
  late KernelManager kernelManager;
  late ProxyService service;

  setUp(() async {
    // 每个测试使用干净的内存 SharedPreferences
    SharedPreferences.setMockInitialValues({});
    storage = ConfigStorageService();
    await storage.init();
    kernelManager = KernelManager();
    service = ProxyService(kernelManager, storage);
    await service.init();
  });

  tearDown(() {
    // 取消内部 _speedTimer，避免泄漏到其他测试
    service.dispose();
  });

  group('ProxyService 初始化', () {
    test('init 加载空默认值', () {
      expect(service.state, ProxyState.stopped);
      expect(service.nodes, isEmpty);
      expect(service.routingRules, isEmpty);
      expect(service.isRunning, isFalse);
      expect(service.activeNode, isNull);
      expect(service.uptime, isNull);
    });

    test('init 从持久化存储恢复节点和规则', () async {
      // 预写入数据后用新 service 实例加载
      await storage.saveNodes([_node('n1', '1.1.1.1', 443, ProxyProtocol.trojan)]);
      await storage.saveRoutingRules([
        RoutingRule(id: 'r1', name: '广告屏蔽', type: 'geosite', match: 'category-ads-all', target: 'block'),
      ]);

      final restored = ProxyService(kernelManager, storage);
      await restored.init();

      expect(restored.nodes.length, 1);
      expect(restored.nodes.first.address, '1.1.1.1');
      expect(restored.routingRules.length, 1);
      expect(restored.routingRules.first.target, 'block');
      restored.dispose();
    });
  });

  group('ProxyService 节点管理', () {
    test('addNode 添加新节点', () {
      service.addNode(_node('n1', '1.1.1.1', 443, ProxyProtocol.trojan));
      expect(service.nodes.length, 1);
      expect(service.nodes.first.id, 'n1');
    });

    test('addNode 相同 address:port:protocol 的节点被去重忽略', () {
      service.addNode(_node('n1', '1.1.1.1', 443, ProxyProtocol.trojan, name: '第一个'));
      // id 和 name 不同，但地址/端口/协议相同 → 应被忽略
      service.addNode(_node('n2', '1.1.1.1', 443, ProxyProtocol.trojan, name: '重复节点'));

      expect(service.nodes.length, 1);
      expect(service.nodes.first.id, 'n1');
      expect(service.nodes.first.name, '第一个');
    });

    test('addNode 地址/端口/协议任一不同则不去重', () {
      service.addNode(_node('n1', '1.1.1.1', 443, ProxyProtocol.trojan));
      service.addNode(_node('n2', '1.1.1.1', 8443, ProxyProtocol.trojan)); // 端口不同
      service.addNode(_node('n3', '2.2.2.2', 443, ProxyProtocol.trojan)); // 地址不同
      service.addNode(_node('n4', '1.1.1.1', 443, ProxyProtocol.vmess)); // 协议不同

      expect(service.nodes.length, 4);
    });

    test('addNodes 批量添加自动去重', () {
      service.addNode(_node('n1', '1.1.1.1', 443, ProxyProtocol.trojan));
      service.addNodes([
        _node('n2', '1.1.1.1', 443, ProxyProtocol.trojan), // 与 n1 重复
        _node('n3', '3.3.3.3', 443, ProxyProtocol.trojan),
        _node('n4', '3.3.3.3', 443, ProxyProtocol.trojan), // 批内重复
      ]);

      expect(service.nodes.length, 2);
      expect(service.nodes.map((n) => n.address), containsAll(['1.1.1.1', '3.3.3.3']));
    });

    test('updateNode 按 id 更新节点', () {
      service.addNode(_node('n1', '1.1.1.1', 443, ProxyProtocol.trojan));
      service.updateNode(_node('n1', '9.9.9.9', 8443, ProxyProtocol.trojan, name: '已更新'));

      expect(service.nodes.length, 1);
      expect(service.nodes.first.address, '9.9.9.9');
      expect(service.nodes.first.port, 8443);
      expect(service.nodes.first.name, '已更新');
    });

    test('updateNode 不存在的 id 不产生变化', () {
      service.addNode(_node('n1', '1.1.1.1', 443, ProxyProtocol.trojan));
      service.updateNode(_node('ghost', '9.9.9.9', 8443, ProxyProtocol.vmess));

      expect(service.nodes.length, 1);
      expect(service.nodes.first.address, '1.1.1.1');
    });

    test('deleteNode 按 id 删除节点', () {
      service.addNode(_node('n1', '1.1.1.1', 443, ProxyProtocol.trojan));
      service.addNode(_node('n2', '2.2.2.2', 443, ProxyProtocol.vmess));
      service.deleteNode('n1');

      expect(service.nodes.length, 1);
      expect(service.nodes.first.id, 'n2');
    });

    test('clearNodes 清空所有节点', () {
      service.addNode(_node('n1', '1.1.1.1', 443, ProxyProtocol.trojan));
      service.addNode(_node('n2', '2.2.2.2', 443, ProxyProtocol.vmess));
      service.clearNodes();

      expect(service.nodes, isEmpty);
    });

    test('节点变更自动持久化（新实例可读回）', () async {
      service.addNode(_node('n1', '1.1.1.1', 443, ProxyProtocol.trojan));

      final restored = ProxyService(kernelManager, storage);
      await restored.init();
      expect(restored.nodes.length, 1);
      restored.dispose();
    });
  });

  group('ProxyService 路由规则管理', () {
    test('addRoutingRule 添加规则', () {
      service.addRoutingRule(RoutingRule(id: 'r1', name: '直连国内', type: 'geosite', match: 'cn', target: 'direct'));
      expect(service.routingRules.length, 1);
    });

    test('updateRoutingRules 批量替换规则', () {
      service.addRoutingRule(RoutingRule(id: 'r1', name: '旧规则'));
      service.updateRoutingRules([
        RoutingRule(id: 'r2', name: '新规则A'),
        RoutingRule(id: 'r3', name: '新规则B'),
      ]);

      expect(service.routingRules.length, 2);
      expect(service.routingRules.map((r) => r.id), containsAll(['r2', 'r3']));
    });

    test('deleteRoutingRule 按 id 删除规则', () {
      service.updateRoutingRules([
        RoutingRule(id: 'r1', name: '规则A'),
        RoutingRule(id: 'r2', name: '规则B'),
      ]);
      service.deleteRoutingRule('r1');

      expect(service.routingRules.length, 1);
      expect(service.routingRules.first.id, 'r2');
    });
  });

  group('ProxyService 配置管理', () {
    test('updateConfig 更新并持久化', () async {
      final newConfig = service.config.copyWith(
        kernelType: KernelType.mihomo,
        httpPort: 8888,
      );
      service.updateConfig(newConfig);

      expect(service.config.kernelType, KernelType.mihomo);
      expect(service.config.httpPort, 8888);

      // 新 storage 实例读回验证持久化
      final storage2 = ConfigStorageService();
      await storage2.init();
      final loaded = storage2.loadProxyConfig();
      expect(loaded.kernelType, KernelType.mihomo);
      expect(loaded.httpPort, 8888);
    });
  });

  group('ProxyService 导入导出', () {
    test('exportConfig / importConfig 往返保持数据一致', () async {
      service.updateConfig(service.config.copyWith(smartNode: true));
      service.addNode(_node('n1', '1.1.1.1', 443, ProxyProtocol.trojan));
      service.updateRoutingRules([
        RoutingRule(id: 'r1', name: '屏蔽广告', type: 'geosite', match: 'category-ads-all', target: 'block'),
      ]);

      final exported = await service.exportConfig();
      expect(exported, isNotEmpty);
      expect(exported, contains('1.1.1.1'));

      // 导入到干净的 SharedPreferences
      SharedPreferences.setMockInitialValues({});
      final storage2 = ConfigStorageService();
      await storage2.init();
      final restored = ProxyService(kernelManager, storage2);
      await restored.init();
      expect(restored.nodes, isEmpty); // 导入前为空

      final ok = await restored.importConfig(exported);
      expect(ok, isTrue);
      expect(restored.nodes.length, 1);
      expect(restored.nodes.first.address, '1.1.1.1');
      expect(restored.routingRules.length, 1);
      expect(restored.config.smartNode, isTrue);
      restored.dispose();
    });

    test('importConfig 非法 JSON 返回 false', () async {
      final ok = await service.importConfig('not-a-json');
      expect(ok, isFalse);
    });
  });

  group('ProxyService 空闲通知策略（回归测试）', () {
    test('停止状态下速度无变化时不每秒触发 notifyListeners', () async {
      // 先做一些会产生通知的操作，然后开始监听
      service.addNode(_node('n1', '1.1.1.1', 443, ProxyProtocol.trojan));

      var notifyCount = 0;
      service.addListener(() => notifyCount++);

      // 等待 2.2 秒（跨越 2 个 _speedTimer tick）
      // 修复前：每秒至少通知 2 次；修复后：停止且速度恒为 0 → 0 次
      await Future<void>.delayed(const Duration(milliseconds: 2200));

      expect(notifyCount, 0);
    });
  });
}
