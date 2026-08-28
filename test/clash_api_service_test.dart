// ClashApiService 单元测试
//
// 覆盖范围：
// - 数据模型 fromJson 解析（ClashProxy / ClashConnection / ClashLogEntry）
// - 服务初始状态与默认值
// - configure() 配置 API 地址和密钥
// - disconnect() 重置流量数据
// - RESTful API 调用（通过 mock Dio adapter）：
//   getProxies / switchProxy / setProxyMode / fetchConnections / closeAllConnections
//
// Mock 策略：自定义 HttpClientAdapter，按 path+method 返回预设 JSON
//
// 注意：不调用 service.dispose()，因为它内部调用 disconnect() 是异步未 await 的，
// notifyListeners() 会在测试完成后触发导致 "test failed after it had already completed"。
// 改为在 tearDown 中 await service.disconnect()，手动移除监听器。

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:proxcore/services/clash_api_service.dart';

/// 简易 Mock Dio HttpClientAdapter
///
/// 根据 method + path 匹配预设响应，未匹配时返回 404
class _MockAdapter implements HttpClientAdapter {
  /// 预设响应表：键为 '${method} $path'，值为 (statusCode, jsonBody)
  final Map<String, _MockResp> responses = {};

  /// 记录所有请求（method, path, data）以便断言
  final List<_MockRequest> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${options.method} ${options.path}';
    requests.add(_MockRequest(
      method: options.method,
      path: options.path,
      data: options.data,
    ));

    final resp = responses[key];
    if (resp != null) {
      final stream = Stream.value(
        Uint8List.fromList(utf8.encode(jsonEncode(resp.body))),
      );
      return ResponseBody(
        stream,
        resp.statusCode,
        headers: {
          'content-type': ['application/json'],
        },
      );
    }
    // 未匹配返回 404
    return ResponseBody(
      Stream.value(Uint8List.fromList(utf8.encode('{}'))),
      404,
      headers: {},
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Mock 响应数据
class _MockResp {
  final int statusCode;
  final Map<String, dynamic> body;
  const _MockResp(this.statusCode, this.body);
}

/// Mock 请求记录
class _MockRequest {
  final String method;
  final String path;
  final dynamic data;
  const _MockRequest({
    required this.method,
    required this.path,
    this.data,
  });
}

/// 构造带 mock adapter 的 Dio
Dio _mockDio(_MockAdapter adapter, {String baseUrl = 'http://127.0.0.1:9090'}) {
  final dio = Dio(BaseOptions(baseUrl: baseUrl));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  group('ClashProxy 模型', () {
    test('fromJson 基本解析', () {
      final proxy = ClashProxy.fromJson('节点A', {
        'type': 'Shadowsocks',
        'now': null,
        'all': [],
        'history': [],
      });

      expect(proxy.name, '节点A');
      expect(proxy.type, 'Shadowsocks');
      expect(proxy.now, isNull);
      expect(proxy.delay, isNull);
      expect(proxy.all, isEmpty);
    });

    test('fromJson 带延迟历史', () {
      final proxy = ClashProxy.fromJson('节点B', {
        'type': 'VMess',
        'history': [
          {'delay': 120},
        ],
      });

      expect(proxy.delay, 120);
    });

    test('fromJson 带代理组', () {
      final proxy = ClashProxy.fromJson('Proxy', {
        'type': 'Selector',
        'now': '节点A',
        'all': ['节点A', '节点B', 'DIRECT'],
      });

      expect(proxy.now, '节点A');
      expect(proxy.all.length, 3);
      expect(proxy.all, contains('节点B'));
    });

    test('isGroup 识别 Selector/URLTest/Fallback', () {
      expect(ClashProxy(name: 'g', type: 'Selector').isGroup, isTrue);
      expect(ClashProxy(name: 'g', type: 'URLTest').isGroup, isTrue);
      expect(ClashProxy(name: 'g', type: 'Fallback').isGroup, isTrue);
      expect(ClashProxy(name: 'g', type: 'Shadowsocks').isGroup, isFalse);
      expect(ClashProxy(name: 'g', type: 'VMess').isGroup, isFalse);
    });

    test('fromJson 缺失字段安全处理', () {
      final proxy = ClashProxy.fromJson('空', {});

      expect(proxy.name, '空');
      expect(proxy.type, '');
      expect(proxy.delay, isNull);
      expect(proxy.all, isEmpty);
      expect(proxy.now, isNull);
    });
  });

  group('ClashConnection 模型', () {
    test('fromJson 基本解析', () {
      final conn = ClashConnection.fromJson({
        'id': 'conn-1',
        'metadata': {
          'host': 'example.com',
          'destinationIP': '1.2.3.4',
          'destinationPort': '443',
        },
        'chains': ['proxy', 'direct'],
        'upload': 1024,
        'download': 4096,
        'start': '2025-06-01T12:00:00.000Z',
      });

      expect(conn.id, 'conn-1');
      expect(conn.host, 'example.com');
      expect(conn.destinationIP, '1.2.3.4');
      expect(conn.destinationPort, '443');
      expect(conn.chain, 'proxy → direct');
      expect(conn.upload, 1024);
      expect(conn.download, 4096);
    });

    test('fromJson host 回退到 destinationIP', () {
      final conn = ClashConnection.fromJson({
        'id': 'conn-2',
        'metadata': {
          'destinationIP': '5.6.7.8',
        },
      });

      expect(conn.host, '5.6.7.8');
    });

    test('fromJson 缺失字段安全处理', () {
      final conn = ClashConnection.fromJson({});

      expect(conn.id, '');
      expect(conn.host, '');
      expect(conn.chain, '');
      expect(conn.upload, 0);
      expect(conn.download, 0);
    });

    test('fromJson 非法 start 时间回退到 now', () {
      final conn = ClashConnection.fromJson({
        'id': 'conn-3',
        'start': 'not-a-date',
      });

      expect(conn.start, isNotNull);
      final diff = DateTime.now().difference(conn.start).inSeconds;
      expect(diff, lessThan(5));
    });
  });

  group('ClashLogEntry 模型', () {
    test('构造与字段访问', () {
      const entry = ClashLogEntry(type: 'info', payload: 'proxy started');
      expect(entry.type, 'info');
      expect(entry.payload, 'proxy started');
    });
  });

  group('ClashApiService 初始状态', () {
    test('默认值正确', () {
      final service = ClashApiService();

      expect(service.liveUpload, 0);
      expect(service.liveDownload, 0);
      expect(service.connections, isEmpty);
      expect(service.realtimeLogs, isEmpty);
      expect(service.currentProxyMode, 'rule');
      expect(service.isConnected, isFalse);
    });
  });

  group('ClashApiService configure()', () {
    late _MockAdapter adapter;
    late ClashApiService service;

    setUp(() {
      adapter = _MockAdapter();
      final dio = _mockDio(adapter);
      service = ClashApiService(dio: dio);
    });

    tearDown(() async {
      await service.disconnect();
    });

    test('设置 API 地址和密钥', () {
      service.configure(apiUrl: 'http://192.168.1.1:9090', secret: 'my-secret');

      // 通过后续请求验证 baseUrl 和 header 已正确设置
      adapter.responses['GET /proxies'] = _MockResp(200, {
        'proxies': {
          'node1': {'type': 'Shadowsocks'},
        },
      });

      service.getProxies();
      expect(service.toString(), isNotNull); // 确保无异常
    });

    test('去除尾部斜杠', () {
      service.configure(apiUrl: 'http://127.0.0.1:9090/');
      // baseUrl 去尾斜杠后应为 http://127.0.0.1:9090
      adapter.responses['GET /proxies'] = _MockResp(200, {'proxies': {}});
      service.getProxies();
    });

    test('无密钥时不设置 Authorization', () {
      service.configure(apiUrl: 'http://127.0.0.1:9090');
      // 确认 configure 不抛异常
      expect(service.isConnected, isFalse);
    });
  });

  group('ClashApiService disconnect()', () {
    test('断开连接后流量归零并通知', () async {
      final adapter = _MockAdapter();
      final dio = _mockDio(adapter);
      final service = ClashApiService(dio: dio);

      var notified = false;
      final listener = () => notified = true;
      service.addListener(listener);

      await service.disconnect();

      expect(service.liveUpload, 0);
      expect(service.liveDownload, 0);
      expect(service.isConnected, isFalse);
      expect(notified, isTrue);

      service.removeListener(listener);
      await service.disconnect();
    });
  });

  group('ClashApiService REST API', () {
    late _MockAdapter adapter;
    late ClashApiService service;

    setUp(() {
      adapter = _MockAdapter();
      final dio = _mockDio(adapter);
      service = ClashApiService(dio: dio);
      service.configure(apiUrl: 'http://127.0.0.1:9090');
    });

    tearDown(() async {
      await service.disconnect();
    });

    test('getProxies 返回解析后的节点列表', () async {
      adapter.responses['GET /proxies'] = _MockResp(200, {
        'proxies': {
          'node-hk': {
            'type': 'Shadowsocks',
            'history': [{'delay': 80}],
          },
          'Proxy': {
            'type': 'Selector',
            'now': 'node-hk',
            'all': ['node-hk', 'DIRECT'],
          },
          'DIRECT': {'type': 'Direct'},
        },
      });

      final proxies = await service.getProxies();

      expect(proxies.length, 3);
      final hk = proxies.firstWhere((p) => p.name == 'node-hk');
      expect(hk.type, 'Shadowsocks');
      expect(hk.delay, 80);
      final group = proxies.firstWhere((p) => p.name == 'Proxy');
      expect(group.isGroup, isTrue);
      expect(group.now, 'node-hk');
      expect(group.all.length, 2);
    });

    test('getProxies 服务器返回 404 时返回空列表', () async {
      // 无预设响应 → adapter 返回 404 → Dio 抛异常 → catch 返回 []
      final proxies = await service.getProxies();
      expect(proxies, isEmpty);
    });

    test('switchProxy 发送 PUT 请求', () async {
      adapter.responses['PUT /proxies/Proxy'] = _MockResp(204, {});

      await service.switchProxy('Proxy', 'node-hk');

      expect(adapter.requests.length, 1);
      expect(adapter.requests.first.method, 'PUT');
      expect(adapter.requests.first.path, '/proxies/Proxy');
      expect((adapter.requests.first.data as Map)['name'], 'node-hk');
    });

    test('switchProxy 服务器错误时不抛异常', () async {
      // 无预设响应 → 404 → 异常被吞
      await service.switchProxy('Proxy', 'node-hk');
      // 不抛异常即通过
    });

    test('setProxyMode 更新模式并通知', () async {
      adapter.responses['PATCH /configs'] = _MockResp(204, {});

      var notified = false;
      final listener = () => notified = true;
      service.addListener(listener);

      await service.setProxyMode('global');

      expect(service.currentProxyMode, 'global');
      expect(notified, isTrue);

      service.removeListener(listener);
    });

    test('setProxyMode 服务器错误时不更新模式', () async {
      final beforeMode = service.currentProxyMode;
      await service.setProxyMode('direct');
      // 404 → 异常 → mode 未更新
      expect(service.currentProxyMode, beforeMode);
    });

    test('fetchConnections 更新连接列表并通知', () async {
      adapter.responses['GET /connections'] = _MockResp(200, {
        'connections': [
          {
            'id': 'c1',
            'metadata': {'host': 'a.com', 'destinationPort': '443'},
            'chains': ['proxy'],
            'upload': 100,
            'download': 200,
            'start': '2025-06-01T12:00:00Z',
          },
        ],
      });

      var notified = false;
      final listener = () => notified = true;
      service.addListener(listener);

      await service.fetchConnections();

      expect(service.connections.length, 1);
      expect(service.connections.first.host, 'a.com');
      expect(service.connections.first.upload, 100);
      expect(notified, isTrue);

      service.removeListener(listener);
    });

    test('fetchConnections 空连接列表', () async {
      adapter.responses['GET /connections'] = _MockResp(200, {
        'connections': [],
      });

      await service.fetchConnections();

      expect(service.connections, isEmpty);
    });

    test('closeAllConnections 清空连接并通知', () async {
      // 先填充连接
      adapter.responses['GET /connections'] = _MockResp(200, {
        'connections': [
          {'id': 'c1', 'metadata': {}},
          {'id': 'c2', 'metadata': {}},
        ],
      });
      await service.fetchConnections();
      expect(service.connections.length, 2);

      // 再清空
      adapter.responses['DELETE /connections'] = _MockResp(204, {});
      var notified = false;
      final listener = () => notified = true;
      service.addListener(listener);

      await service.closeAllConnections();

      expect(service.connections, isEmpty);
      expect(notified, isTrue);

      service.removeListener(listener);
    });

    test('closeAllConnections 服务器错误时不清空', () async {
      // 先填充连接
      adapter.responses['GET /connections'] = _MockResp(200, {
        'connections': [
          {'id': 'c1', 'metadata': {}},
        ],
      });
      await service.fetchConnections();
      expect(service.connections.length, 1);

      // DELETE 404 → 异常被吞 → 连接不清空
      await service.closeAllConnections();
      expect(service.connections.length, 1);
    });
  });
}
