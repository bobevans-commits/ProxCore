import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/config.dart';
import '../screens/node_editor_screen.dart';
import '../services/proxy_service.dart';
import '../utils/app_utils.dart';

/// 节点列表底部弹窗
///
/// 支持功能：
/// - 排序（默认/延迟升序/延迟降序/名称）
/// - 按协议筛选
/// - 按协议分组显示
/// - 批量选择和删除
/// - 全部测速
/// - 单节点连接/测速/编辑/删除
class NodeListSheet extends StatefulWidget {
  /// 滚动控制器
  final ScrollController scrollController;

  /// 添加节点回调
  final VoidCallback onAdd;

  const NodeListSheet({
    super.key,
    required this.scrollController,
    required this.onAdd,
  });

  /// 创建状态管理实例
  @override
  State<NodeListSheet> createState() => _NodeListSheetState();
}

/// 节点排序模式
enum NodeSortMode {
  /// 默认顺序
  defaultOrder,

  /// 延迟升序
  latencyAsc,

  /// 延迟降序
  latencyDesc,

  /// 名称升序
  nameAsc,
}

/// NodeListSheet 状态管理
class _NodeListSheetState extends State<NodeListSheet> {
  /// 当前排序模式
  NodeSortMode _sortMode = NodeSortMode.defaultOrder;

  /// 协议筛选，null 表示不筛选
  ProxyProtocol? _filterProtocol;

  /// 是否按协议分组显示
  bool _groupByProtocol = false;

  /// 是否处于批量选择模式
  bool _selectMode = false;

  /// 批量选中的节点 ID 集合
  final Set<String> _selectedIds = {};

  /// 应用排序和筛选
  ///
  /// [nodes] 待处理的节点列表
  List<NodeConfig> _applySortAndFilter(List<NodeConfig> nodes) {
    var filtered = _filterProtocol != null
        ? nodes.where((n) => n.protocol == _filterProtocol).toList()
        : nodes.toList();

    switch (_sortMode) {
      case NodeSortMode.defaultOrder:
        break;
      case NodeSortMode.latencyAsc:
        filtered.sort((a, b) {
          final la = a.latencyMs ?? 99999;
          final lb = b.latencyMs ?? 99999;
          return la.compareTo(lb);
        });
      case NodeSortMode.latencyDesc:
        filtered.sort((a, b) {
          final la = a.latencyMs ?? -1;
          final lb = b.latencyMs ?? -1;
          return lb.compareTo(la);
        });
      case NodeSortMode.nameAsc:
        filtered.sort((a, b) => a.name.compareTo(b.name));
    }

    return filtered;
  }

  /// 按协议分组
  ///
  /// [nodes] 待分组的节点列表
  Map<ProxyProtocol, List<NodeConfig>> _groupByProtocolFn(
    List<NodeConfig> nodes,
  ) {
    final map = <ProxyProtocol, List<NodeConfig>>{};
    for (final node in nodes) {
      (map[node.protocol] ??= []).add(node);
    }
    return map;
  }

  /// 构建节点列表弹窗，包含工具栏、筛选标签和节点列表
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final proxyService = context.watch<ProxyService>();
    final allNodes = proxyService.nodes;
    final nodes = _applySortAndFilter(allNodes);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text('节点列表', style: theme.textTheme.titleLarge),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${allNodes.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              if (_selectMode) ...[
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_selectedIds.length == allNodes.length) {
                        _selectedIds.clear();
                      } else {
                        _selectedIds.clear();
                        _selectedIds.addAll(allNodes.map((n) => n.id));
                      }
                    });
                  },
                  child: Text(
                    _selectedIds.length == allNodes.length ? '取消全选' : '全选',
                  ),
                ),
                IconButton(
                  onPressed: _selectedIds.isEmpty
                      ? null
                      : () {
                          final count = _selectedIds.length;
                          for (final id in _selectedIds) {
                            proxyService.deleteNode(id);
                          }
                          setState(() {
                            _selectedIds.clear();
                            _selectMode = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('已删除 $count 个节点'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                  icon: const Icon(Icons.delete, size: 20),
                  tooltip: '删除选中',
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _selectMode = false;
                      _selectedIds.clear();
                    });
                  },
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: '退出管理',
                ),
              ] else ...[
                IconButton(
                  onPressed: () {
                    setState(() => _selectMode = true);
                  },
                  icon: const Icon(Icons.checklist, size: 20),
                  tooltip: '批量管理',
                ),
                IconButton(
                  onPressed: () {
                    proxyService.testAllLatency(allNodes.toList());
                  },
                  icon: const Icon(Icons.speed, size: 20),
                  tooltip: '全部测速',
                ),
                PopupMenuButton(
                  icon: const Icon(Icons.sort, size: 20),
                  tooltip: '排序',
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'default', child: Text('默认排序')),
                    const PopupMenuItem(
                      value: 'latency_asc',
                      child: Text('延迟升序'),
                    ),
                    const PopupMenuItem(
                      value: 'latency_desc',
                      child: Text('延迟降序'),
                    ),
                    const PopupMenuItem(value: 'name_asc', child: Text('名称排序')),
                  ],
                  onSelected: (value) {
                    setState(() {
                      switch (value) {
                        case 'default':
                          _sortMode = NodeSortMode.defaultOrder;
                        case 'latency_asc':
                          _sortMode = NodeSortMode.latencyAsc;
                        case 'latency_desc':
                          _sortMode = NodeSortMode.latencyDesc;
                        case 'name_asc':
                          _sortMode = NodeSortMode.nameAsc;
                      }
                    });
                  },
                ),
                IconButton(
                  onPressed: () {
                    setState(() => _groupByProtocol = !_groupByProtocol);
                  },
                  icon: Icon(
                    _groupByProtocol
                        ? Icons.folder_open
                        : Icons.folder_outlined,
                    size: 20,
                  ),
                  tooltip: '按协议分组',
                ),
                FilledButton.icon(
                  onPressed: widget.onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加'),
                ),
              ],
            ],
          ),
        ),
        if (_filterProtocol != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Chip(
                  label: Text(_filterProtocol!.label),
                  onDeleted: () => setState(() => _filterProtocol = null),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                Text(
                  '${nodes.length} 个节点',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: nodes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_off,
                        size: 64,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '暂无节点',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '添加订阅或手动导入节点',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                )
              : _groupByProtocol
              ? _buildGroupedList(context, nodes, proxyService, theme)
              : _buildFlatList(context, nodes, proxyService, theme),
        ),
      ],
    );
  }

  /// 构建扁平列表
  ///
  /// [context] 构建上下文
  /// [nodes] 节点列表
  /// [proxyService] 代理服务实例
  /// [theme] 当前主题数据
  Widget _buildFlatList(
    BuildContext context,
    List<NodeConfig> nodes,
    ProxyService proxyService,
    ThemeData theme,
  ) {
    return ListView.builder(
      controller: widget.scrollController,
      itemCount: nodes.length,
      itemBuilder: (context, index) =>
          _buildNodeTile(context, nodes[index], proxyService, theme),
    );
  }

  /// 构建按协议分组列表
  ///
  /// [context] 构建上下文
  /// [nodes] 节点列表
  /// [proxyService] 代理服务实例
  /// [theme] 当前主题数据
  Widget _buildGroupedList(
    BuildContext context,
    List<NodeConfig> nodes,
    ProxyService proxyService,
    ThemeData theme,
  ) {
    final groups = _groupByProtocolFn(nodes);
    final protocols = groups.keys.toList();

    return ListView.builder(
      controller: widget.scrollController,
      itemCount: protocols.length,
      itemBuilder: (context, index) {
        final protocol = protocols[index];
        final groupNodes = groups[protocol]!;
        return ExpansionTile(
          initiallyExpanded: true,
          leading: Text(
            AppUtils.protocolIcon(protocol),
            style: const TextStyle(fontSize: 18),
          ),
          title: Text(protocol.label),
          trailing: Text(
            '${groupNodes.length}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          children: groupNodes
              .map((node) => _buildNodeTile(context, node, proxyService, theme))
              .toList(),
        );
      },
    );
  }

  /// 构建单个节点列表项
  ///
  /// 显示：协议图标、活跃指示器、节点名称、延迟标签、协议/地址信息
  /// 右键菜单：连接、测速、编辑、删除、筛选同协议
  ///
  /// [context] 构建上下文
  /// [node] 节点配置
  /// [proxyService] 代理服务实例
  /// [theme] 当前主题数据
  Widget _buildNodeTile(
    BuildContext context,
    NodeConfig node,
    ProxyService proxyService,
    ThemeData theme,
  ) {
    final isActive = proxyService.activeNode?.id == node.id;
    final latency = node.latencyMs;

    Color latencyColor;
    String latencyText;
    if (latency == null) {
      latencyColor = theme.colorScheme.outline;
      latencyText = '--';
    } else if (latency == -1) {
      latencyColor = Colors.red;
      latencyText = '超时';
    } else {
      latencyColor = Color(AppUtils.latencyColor(latency));
      latencyText = '${latency}ms';
    }

    return ListTile(
      selected: _selectMode && _selectedIds.contains(node.id),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectMode)
            Checkbox(
              value: _selectedIds.contains(node.id),
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selectedIds.add(node.id);
                  } else {
                    _selectedIds.remove(node.id);
                  }
                });
              },
            ),
          Text(
            AppUtils.protocolIcon(node.protocol),
            style: const TextStyle(fontSize: 20),
          ),
          if (isActive) ...[
            const SizedBox(width: 4),
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
      title: Row(
        children: [
          Expanded(child: Text(node.name)),
          InkWell(
            onTap: () => proxyService.testLatency(node),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: latencyColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                latencyText,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: latencyColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(
        '${node.protocol.label} | ${node.address}:${node.port}',
        style: theme.textTheme.bodySmall,
      ),
      trailing: _selectMode
          ? null
          : PopupMenuButton(
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'connect', child: Text('连接')),
                const PopupMenuItem(value: 'latency', child: Text('测速')),
                const PopupMenuItem(value: 'edit', child: Text('编辑')),
                const PopupMenuItem(value: 'delete', child: Text('删除')),
                const PopupMenuItem(value: 'filter', child: Text('筛选同协议')),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'connect':
                    proxyService.start(node);
                  case 'latency':
                    proxyService.testLatency(node);
                  case 'edit':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NodeEditorScreen(
                          node: node,
                          onSave: (n) => proxyService.updateNode(n),
                        ),
                      ),
                    );
                  case 'delete':
                    proxyService.deleteNode(node.id);
                  case 'filter':
                    setState(() => _filterProtocol = node.protocol);
                }
              },
            ),
      onTap: _selectMode
          ? () {
              setState(() {
                if (_selectedIds.contains(node.id)) {
                  _selectedIds.remove(node.id);
                } else {
                  _selectedIds.add(node.id);
                }
              });
            }
          : () => proxyService.start(node),
    );
  }
}
