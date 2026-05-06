// 订阅管理服务
// 负责代理订阅的增删改查、自动刷新、节点解析
// 支持 VMess / VLESS / Trojan / Shadowsocks / Hysteria2 协议解析

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/config.dart';
import '../utils/app_utils.dart';
import 'config_storage_service.dart';

/// 订阅管理服务 — 管理代理订阅源和节点解析
///
/// 职责：
/// - 订阅源的增删改查和持久化
/// - 定时自动刷新订阅（可配置间隔）
/// - 从订阅 URL 下载并解析节点列表
/// - 支持多种协议解析：VMess / VLESS / Trojan / Shadowsocks / Hysteria2
/// - 节点刷新回调通知 ProxyService 更新节点列表
class SubscriptionService extends ChangeNotifier {
  /// HTTP 客户端，用于下载订阅内容
  final Dio _dio = Dio();

  /// 配置持久化存储服务
  final ConfigStorageService _storage;

  /// 订阅列表
  List<SubscriptionInfo> _subscriptions = [];

  /// 是否正在加载中
  bool _isLoading = false;

  /// 最近一次错误信息
  String? _error;

  /// 自动刷新定时器
  Timer? _autoRefreshTimer;

  /// 自动刷新间隔（分钟），0 表示不自动刷新
  int _refreshMinutes = 0;

  /// 节点刷新回调，订阅刷新后通知 ProxyService 更新节点
  Future<void> Function(List<NodeConfig>)? onNodesRefreshed;

  // ---- 公开 Getter ----

  /// 订阅列表（不可变）
  List<SubscriptionInfo> get subscriptions => List.unmodifiable(_subscriptions);

  /// 是否正在加载中
  bool get isLoading => _isLoading;

  /// 最近一次错误信息
  String? get error => _error;

  /// 自动刷新间隔（分钟）
  int get refreshMinutes => _refreshMinutes;

  SubscriptionService(this._storage);

  /// 初始化，从持久化存储加载订阅列表
  Future<void> init() async {
    _subscriptions = _storage.loadSubscriptions();
    notifyListeners();
  }

  /// 设置自动刷新间隔
  ///
  /// [minutes] 刷新间隔（分钟），0 表示关闭自动刷新
  void setupAutoRefresh(int minutes) {
    _autoRefreshTimer?.cancel();
    _refreshMinutes = minutes;

    if (minutes > 0) {
      _autoRefreshTimer = Timer.periodic(
        Duration(minutes: minutes),
        (_) => _autoRefreshAll(),
      );
    }
  }

  /// 自动刷新所有订阅
  ///
  /// 刷新完成后通过 onNodesRefreshed 回调通知 ProxyService
  Future<void> _autoRefreshAll() async {
    if (_subscriptions.isEmpty) return;

    final allNodes = await refreshAll();
    if (allNodes.isNotEmpty && onNodesRefreshed != null) {
      await onNodesRefreshed!(allNodes);
    }
  }

  /// 添加新订阅
  Future<void> addSubscription(SubscriptionInfo subscription) async {
    _subscriptions.add(subscription);
    await _save();
    notifyListeners();
  }

  /// 删除指定 ID 的订阅
  Future<void> removeSubscription(String id) async {
    _subscriptions.removeWhere((s) => s.id == id);
    await _save();
    notifyListeners();
  }

  /// 更新订阅信息
  Future<void> updateSubscription(SubscriptionInfo subscription) async {
    final index = _subscriptions.indexWhere((s) => s.id == subscription.id);
    if (index >= 0) {
      _subscriptions[index] = subscription;
      await _save();
      notifyListeners();
    }
  }

  /// 刷新指定订阅，返回解析后的节点列表
  ///
  /// 流程：
  /// 1. 根据 URL 下载订阅内容
  /// 2. 解析内容为节点列表
  /// 3. 更新订阅的最后刷新时间
  Future<List<NodeConfig>> refreshSubscription(String id) async {
    final sub = _subscriptions.firstWhere(
      (s) => s.id == id,
      orElse: () => throw Exception('Subscription not found'),
    );

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final nodes = await _fetchNodes(sub.url);

      final updated = sub.copyWith(lastUpdated: DateTime.now());
      final index = _subscriptions.indexWhere((s) => s.id == id);
      if (index >= 0) {
        _subscriptions[index] = updated;
      }
      await _save();

      _isLoading = false;
      notifyListeners();
      return nodes;
    } catch (e) {
      _isLoading = false;
      _error = 'Refresh failed: $e';
      notifyListeners();
      return [];
    }
  }

  /// 刷新所有订阅，返回合并后的节点列表
  Future<List<NodeConfig>> refreshAll() async {
    final allNodes = <NodeConfig>[];
    for (final sub in _subscriptions) {
      try {
        final nodes = await refreshSubscription(sub.id);
        allNodes.addAll(nodes);
      } catch (e) {
        debugPrint('SubscriptionService: refresh ${sub.name} failed: $e');
      }
    }
    return allNodes;
  }

  /// 从订阅 URL 下载内容
  ///
  /// 超时时间30秒，返回原始文本内容
  Future<List<NodeConfig>> _fetchNodes(String url) async {
    try {
      final response = await _dio.get<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      final content = response.data;
      if (content == null || content.isEmpty) return [];

      return _parseSubscriptionContent(content);
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    }
  }

  /// 解析订阅内容为节点列表
  ///
  /// 支持三种订阅格式：
  /// 1. 逐行协议 URI（vmess://, vless://, trojan://, ss://, hysteria2:// 等）
  /// 2. Base64 整体编码（先解码再逐行解析）
  /// 3. Clash YAML 格式（解析 proxies 字段）
  List<NodeConfig> _parseSubscriptionContent(String content) {
    final trimmed = content.trim();

    // 尝试 Base64 整体解码
    final decoded = _tryBase64Decode(trimmed);
    if (decoded != null) {
      return _parseLineByLine(decoded);
    }

    // 尝试 Clash YAML 格式
    if (trimmed.startsWith('proxies:') || trimmed.contains('\nproxies:')) {
      return _parseClashYaml(trimmed);
    }

    // 默认逐行解析
    return _parseLineByLine(trimmed);
  }

  /// 尝试 Base64 整体解码
  ///
  /// 如果内容是有效的 Base64 编码，解码后返回原始字符串
  /// 解码失败返回 null（表示不是 Base64 格式）
  String? _tryBase64Decode(String content) {
    try {
      final cleaned = content.replaceAll(RegExp(r'\s'), '');
      // 检查是否看起来像 Base64（只含 Base64 字符集）
      if (!RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(cleaned)) return null;
      final decoded = utf8.decode(base64Decode(cleaned));
      // 验证解码后内容包含协议标识
      if (decoded.contains('://')) return decoded;
    } catch (_) {}
    return null;
  }

  /// 逐行解析协议 URI
  List<NodeConfig> _parseLineByLine(String content) {
    final nodes = <NodeConfig>[];

    final lines = content.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      try {
        final node = AppUtils.parseProxyLink(trimmed);
        nodes.add(node);
      } catch (e) {
        debugPrint('SubscriptionService: parse line error: $e');
      }
    }

    return nodes;
  }

  /// 解析 Clash YAML 格式订阅
  ///
  /// 提取 proxies 列表中的节点信息
  /// 支持 VMess/VLESS/Trojan/Shadowsocks/Hysteria2 协议
  List<NodeConfig> _parseClashYaml(String content) {
    final nodes = <NodeConfig>[];

    // 简易 YAML proxies 解析（不依赖 yaml 包，减少依赖）
    final lines = content.split('\n');
    bool inProxies = false;
    Map<String, String>? currentProxy;

    for (final line in lines) {
      final trimmed = line.trim();

      if (trimmed.startsWith('proxies:')) {
        inProxies = true;
        continue;
      }

      if (inProxies) {
        // 新节点开始（- name: xxx）
        if (trimmed.startsWith('- name:') || trimmed.startsWith('- {')) {
          // 保存上一个节点
          if (currentProxy != null) {
            final node = _clashProxyToNode(currentProxy);
            if (node != null) nodes.add(node);
          }
          currentProxy = {};

          // 单行格式: - {name: xxx, type: vmess, ...}
          if (trimmed.startsWith('- {')) {
            final inner = trimmed.substring(3, trimmed.length - 1);
            _parseClashInlineProxy(inner, currentProxy);
            if (currentProxy.isNotEmpty) {
              final node = _clashProxyToNode(currentProxy);
              if (node != null) nodes.add(node);
              currentProxy = null;
            }
            continue;
          }

          // 提取 name
          final nameMatch = RegExp(r'name:\s*(.+)').firstMatch(trimmed);
          if (nameMatch != null) {
            currentProxy['name'] = nameMatch.group(1)!.trim().replaceAll('"', '').replaceAll("'", '');
          }
          continue;
        }

        // 缩进回退，proxies 段结束
        if (!trimmed.startsWith(' ') && !trimmed.startsWith('-') && trimmed.isNotEmpty) {
          if (currentProxy != null) {
            final node = _clashProxyToNode(currentProxy);
            if (node != null) nodes.add(node);
            currentProxy = null;
          }
          inProxies = false;
          continue;
        }

        // 解析属性行（key: value）
        if (currentProxy != null) {
          final match = RegExp(r'(\w+):\s*(.+)').firstMatch(trimmed);
          if (match != null) {
            currentProxy[match.group(1)!] = match.group(2)!.trim().replaceAll('"', '').replaceAll("'", '');
          }
        }
      }
    }

    // 保存最后一个节点
    if (currentProxy != null) {
      final node = _clashProxyToNode(currentProxy);
      if (node != null) nodes.add(node);
    }

    return nodes;
  }

  /// 解析 Clash 单行代理格式
  void _parseClashInlineProxy(String inner, Map<String, String> proxy) {
    for (final part in inner.split(',')) {
      final kv = part.split(':');
      if (kv.length >= 2) {
        proxy[kv[0].trim()] = kv.sublist(1).join(':').trim().replaceAll('"', '').replaceAll("'", '');
      }
    }
  }

  /// 将 Clash 代理字典转换为 NodeConfig
  NodeConfig? _clashProxyToNode(Map<String, String> proxy) {
    final type = proxy['type']?.toLowerCase();
    if (type == null) return null;

    final name = proxy['name'] ?? type;
    final server = proxy['server'] ?? '';
    final port = int.tryParse(proxy['port'] ?? '0') ?? 0;

    switch (type) {
      case 'vmess':
        return NodeConfig(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          protocol: ProxyProtocol.vmess,
          address: server,
          port: port,
          extra: {
            'uuid': proxy['uuid'] ?? proxy['alterId'] ?? '',
            'alterId': int.tryParse(proxy['alterId'] ?? '0') ?? 0,
            'security': proxy['cipher'] ?? proxy['security'] ?? 'auto',
            'network': proxy['network'] ?? 'tcp',
            'wsPath': proxy['ws-opts'] != null ? proxy['ws-path'] : null,
            'wsHost': proxy['ws-opts'] != null ? proxy['ws-headers']?.split('\n').firstWhere((_) => _.startsWith('Host:'), orElse: () => '').replaceFirst('Host:', '').trim() : null,
            'tls': proxy['tls'] == 'true' || proxy['tls'] == true.toString(),
            'sni': proxy['servername'] ?? proxy['sni'],
          },
        );
      case 'vless':
        return NodeConfig(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          protocol: ProxyProtocol.vless,
          address: server,
          port: port,
          extra: {
            'uuid': proxy['uuid'] ?? '',
            'flow': proxy['flow'],
            'security': proxy['security'] ?? 'none',
            'type': proxy['network'] ?? proxy['type'] ?? 'tcp',
            'sni': proxy['servername'] ?? proxy['sni'],
            'realityPublicKey': proxy['reality-opts'] != null ? proxy['public-key'] : null,
            'realityShortId': proxy['reality-opts'] != null ? proxy['short-id'] : null,
            'tls': proxy['tls'] == 'true',
          },
        );
      case 'trojan':
        return NodeConfig(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          protocol: ProxyProtocol.trojan,
          address: server,
          port: port,
          extra: {
            'password': proxy['password'] ?? '',
            'sni': proxy['sni'] ?? proxy['servername'],
            'type': proxy['network'] ?? 'tcp',
            'tls': true,
          },
        );
      case 'ss':
        return NodeConfig(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          protocol: ProxyProtocol.shadowsocks,
          address: server,
          port: port,
          extra: {
            'method': proxy['cipher'] ?? proxy['method'] ?? 'aes-256-gcm',
            'password': proxy['password'] ?? '',
          },
        );
      case 'hysteria2':
        return NodeConfig(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          protocol: ProxyProtocol.hysteria2,
          address: server,
          port: port,
          extra: {
            'password': proxy['password'] ?? '',
            'sni': proxy['sni'] ?? server,
            'insecure': proxy['skip-cert-verify'] == 'true',
          },
        );
      default:
        return null;
    }
  }

  /// 持久化保存订阅列表
  Future<void> _save() async {
    await _storage.saveSubscriptions(_subscriptions);
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }
}
