import 'package:flutter_test/flutter_test.dart';
import 'package:proxcore/models/config.dart';
import 'package:proxcore/services/smart_router.dart';

/// SmartRouter 单元测试
///
/// 覆盖：
/// - NodeScore 数据模型（stability / copyWith / toJson / fromJson）
/// - 评分算法：稳定性分、延迟分、速度分计算
/// - recordConnect / recordLatency / recordSpeed 指数移动平均
/// - pickBest 智能选路（历史 60% + 实时延迟 40%）
/// - getRankedNodes 排名
void main() {
  group('NodeScore', () {
    test('stability: 无连接时为 0', () {
      final score = NodeScore(nodeId: '1', lastUsed: DateTime.now(), score: 0);
      expect(score.stability, 0.0);
    });

    test('stability: 10 成功 0 失败时为 1.0', () {
      final score = NodeScore(
        nodeId: '1',
        successfulConnects: 10,
        failedConnects: 0,
        lastUsed: DateTime.now(),
        score: 0,
      );
      expect(score.stability, 1.0);
    });

    test('stability: 5 成功 5 失败时为 0.5', () {
      final score = NodeScore(
        nodeId: '1',
        successfulConnects: 5,
        failedConnects: 5,
        lastUsed: DateTime.now(),
        score: 0,
      );
      expect(score.stability, 0.5);
    });

    test('copyWith 只更新指定字段', () {
      final score = NodeScore(
        nodeId: '1',
        successfulConnects: 5,
        failedConnects: 1,
        avgLatencyMs: 100,
        lastUsed: DateTime(2024, 1, 1),
        score: 60,
      );
      final updated = score.copyWith(score: 80, avgLatencyMs: 50);
      expect(updated.nodeId, '1');
      expect(updated.successfulConnects, 5);
      expect(updated.avgLatencyMs, 50);
      expect(updated.score, 80);
      expect(updated.lastUsed, DateTime(2024, 1, 1));
    });

    test('toJson/fromJson 往返', () {
      final score = NodeScore(
        nodeId: 'node-1',
        successfulConnects: 7,
        failedConnects: 3,
        avgLatencyMs: 120.5,
        avgDownloadSpeed: 1048576,
        lastUsed: DateTime(2024, 6, 1, 10, 0),
        score: 75.5,
      );
      final json = score.toJson();
      final restored = NodeScore.fromJson(json);
      expect(restored.nodeId, 'node-1');
      expect(restored.successfulConnects, 7);
      expect(restored.failedConnects, 3);
      expect(restored.avgLatencyMs, 120.5);
      expect(restored.avgDownloadSpeed, 1048576);
      expect(restored.score, 75.5);
    });
  });

  group('SmartRouter 评分算法', () {
    SmartRouter createRouter() => SmartRouter();
    NodeConfig mkNode(String id) => NodeConfig(
      id: id,
      name: 'node-$id',
      protocol: ProxyProtocol.shadowsocks,
      address: '1.2.3.4',
      port: 8388,
      extra: {'method': 'aes-256-gcm', 'password': 'pw'},
    );

    test('首次成功连接：新节点初始分 50.0', () {
      final r = createRouter();
      r.recordConnect(mkNode('1'), success: true);
      expect(r.scores['1']!.score, 50.0);
      expect(r.scores['1']!.successfulConnects, 1);
    });

    test('首次失败连接：新节点初始分 0.0', () {
      final r = createRouter();
      r.recordConnect(mkNode('1'), success: false);
      expect(r.scores['1']!.score, 0.0);
      expect(r.scores['1']!.failedConnects, 1);
    });

    test('recordLatency 使用指数移动平均 (α=0.3)', () {
      final r = createRouter();
      r.recordLatency(mkNode('1'), 100);
      r.recordLatency(mkNode('1'), 200);
      // 第二次更新：100*0.7 + 200*0.3 = 70 + 60 = 130
      expect(r.scores['1']!.avgLatencyMs, closeTo(130, 0.01));
    });

    test('recordSpeed 使用指数移动平均 (α=0.3)', () {
      final r = createRouter();
      final oneMB = 1024.0 * 1024.0;
      r.recordSpeed(mkNode('1'), oneMB);
      r.recordSpeed(mkNode('1'), 2 * oneMB);
      // 1MB*0.7 + 2MB*0.3 = 1.3MB
      expect(r.scores['1']!.avgDownloadSpeed, closeTo(1.3 * oneMB, 0.01));
    });

    test('连击稳定性：连续成功累积分数', () {
      final r = createRouter();
      final node = mkNode('1');
      // 首次成功：50
      r.recordConnect(node, success: true);
      final s1 = r.scores['1']!.score;
      // 再成功一次：1/1 稳定 + 默认 50 latency 假设 (score=1/1*40 + 20 + 10 = 70)
      r.recordConnect(node, success: true);
      final s2 = r.scores['1']!.score;
      expect(s2, greaterThan(s1));
    });
  });

  group('SmartRouter.pickBest', () {
    SmartRouter createRouter() => SmartRouter();
    NodeConfig mkNode(String id, {int? latencyMs}) => NodeConfig(
      id: id,
      name: 'n-$id',
      protocol: ProxyProtocol.shadowsocks,
      address: '1.2.3.4',
      port: 8388,
      extra: {'method': 'aes-256-gcm', 'password': 'pw'},
      latencyMs: latencyMs,
    );

    test('空列表返回 null', () {
      expect(createRouter().pickBest([]), isNull);
    });

    test('单节点返回该节点', () {
      final node = mkNode('1');
      expect(createRouter().pickBest([node]), node);
    });

    test('优先选择实时延迟低的节点', () {
      final r = createRouter();
      final fast = mkNode('fast', latencyMs: 20);
      final slow = mkNode('slow', latencyMs: 200);
      // 实时评分 fast: 50-20/2=40; slow: 50-200/2=-50→0
      // 无历史时默认 25，综合分: fast=25*0.6+40*0.4=31; slow=25*0.6+0*0.4=15
      expect(r.pickBest([slow, fast]), fast);
    });

    test('历史评分影响选路：历史好但延迟差的节点可能胜出', () {
      final r = createRouter();
      // 节点A 有 10 次成功 0 次失败，延迟 500ms
      for (var i = 0; i < 10; i++) {
        r.recordConnect(mkNode('a'), success: true);
      }
      r.recordLatency(mkNode('a'), 500);

      // 节点B 0 次连接，延迟 30ms
      final a = mkNode('a', latencyMs: 500);
      final b = mkNode('b', latencyMs: 30);

      // A: 历史分 40 + 延迟分 20-500/50=10 + 速度分 10 = 60; 实时评分 50-500/2=0
      //    综合: 60*0.6 + 0*0.4 = 36
      // B: 历史分 25 (默认), 实时: 50-30/2=35
      //    综合: 25*0.6 + 35*0.4 = 15+14 = 29
      expect(r.pickBest([b, a]), a);
    });
  });

  group('SmartRouter.getRankedNodes', () {
    test('按评分降序排序', () {
      final r = SmartRouter();
      final n1 = NodeConfig(
        id: '1',
        name: 'low',
        protocol: ProxyProtocol.shadowsocks,
        address: '1.1.1.1',
        port: 8388,
        extra: {'method': 'aes-256-gcm', 'password': 'pw'},
      );
      final n2 = NodeConfig(
        id: '2',
        name: 'high',
        protocol: ProxyProtocol.shadowsocks,
        address: '1.1.1.1',
        port: 8388,
        extra: {'method': 'aes-256-gcm', 'password': 'pw'},
      );
      final n3 = NodeConfig(
        id: '3',
        name: 'none',
        protocol: ProxyProtocol.shadowsocks,
        address: '1.1.1.1',
        port: 8388,
        extra: {'method': 'aes-256-gcm', 'password': 'pw'},
      );

      // n1: 1 success 1 fail → 稳定性 20, 默认 50 latency/0 speed → 50
      r.recordConnect(n1, success: true);
      r.recordConnect(n1, success: false);
      // n2: 5 success 0 fail + 良好延迟 → 高分
      for (var i = 0; i < 5; i++) {
        r.recordConnect(n2, success: true);
      }
      r.recordLatency(n2, 30);

      final ranked = r.getRankedNodes([n1, n2, n3]);
      expect(ranked.first.key.id, '2');
      expect(ranked[1].key.id, '1');
      // n3 无评分应排最后
      expect(ranked.last.value, isNull);
    });
  });

  group('SmartRouter 持久化', () {
    test('toJson + loadFromJson 往返', () {
      final r = SmartRouter();
      final n = NodeConfig(
        id: '1',
        name: 'n',
        protocol: ProxyProtocol.shadowsocks,
        address: '1.1.1.1',
        port: 8388,
        extra: {'method': 'aes-256-gcm', 'password': 'pw'},
      );
      // 首次 recordConnect 不记录延迟（默认 avgLatencyMs=0）
      r.recordConnect(n, success: true);
      // 之后 recordLatency 使用 EMA: 0*0.7 + 50*0.3 = 15.0
      r.recordLatency(n, 50);

      final json = r.toJson();
      final r2 = SmartRouter();
      r2.loadFromJson(json);
      expect(r2.scores['1']!.successfulConnects, 1);
      expect(r2.scores['1']!.avgLatencyMs, closeTo(15.0, 0.01));
    });

    test('loadFromJson 空数据安全处理', () {
      final r = SmartRouter();
      r.loadFromJson({});
      expect(r.scores, isEmpty);
    });

    test('loadFromJson 缺少 scores 字段安全处理', () {
      final r = SmartRouter();
      r.loadFromJson({'other': 'value'});
      expect(r.scores, isEmpty);
    });
  });
}
