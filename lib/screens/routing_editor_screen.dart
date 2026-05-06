import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/config.dart';

/// RoutingEditorScreen - 路由规则编辑器页面
///
/// 用于管理代理路由规则，支持添加、编辑、删除、拖拽排序规则，
/// 以及导入预设规则
class RoutingEditorScreen extends StatefulWidget {
  /// 当前路由规则列表
  final List<RoutingRule> rules;

  /// 保存回调，传入编辑后的规则列表
  final void Function(List<RoutingRule>) onSave;

  const RoutingEditorScreen({
    super.key,
    required this.rules,
    required this.onSave,
  });

  @override
  State<RoutingEditorScreen> createState() => _RoutingEditorScreenState();
}

/// _RoutingEditorScreenState - RoutingEditorScreen 的状态类
///
/// 管理规则列表的增删改查和拖拽排序
class _RoutingEditorScreenState extends State<RoutingEditorScreen> {
  /// 当前编辑中的规则列表
  late List<RoutingRule> _rules;

  /// 是否显示预设规则面板
  bool _showPresets = false;

  @override
  void initState() {
    super.initState();
    _rules = List.from(widget.rules);
  }

  /// 添加一条新的空规则
  void _addRule() {
    final rule = RoutingRule(
      id: const Uuid().v4(),
      name: '规则 ${_rules.length + 1}',
    );
    setState(() => _rules.add(rule));
  }

  /// 移除指定索引的规则
  void _removeRule(int index) {
    setState(() => _rules.removeAt(index));
  }

  /// 切换指定索引规则的启用/禁用状态
  void _toggleRule(int index) {
    setState(() {
      _rules[index] = _rules[index].copyWith(enabled: !_rules[index].enabled);
    });
  }

  /// 弹出对话框编辑指定索引的规则
  void _editRule(int index) {
    final rule = _rules[index];
    final nameController = TextEditingController(text: rule.name);
    final matchController = TextEditingController(text: rule.match);
    String type = rule.type;
    String target = rule.target;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('编辑规则'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '名称',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(
                    labelText: '匹配类型',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: RoutingRule.typeOptions
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(_typeLabel(t)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => type = v ?? 'domain'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: matchController,
                  decoration: InputDecoration(
                    labelText: _matchHint(type),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: target,
                  decoration: const InputDecoration(
                    labelText: '目标',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: RoutingRule.targetOptions
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _targetIcon(t),
                                size: 16,
                                color: _targetColor(t),
                              ),
                              const SizedBox(width: 6),
                              Text(_targetLabel(t)),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => target = v ?? 'proxy'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  _rules[index] = _rules[index].copyWith(
                    name: nameController.text.trim().isEmpty
                        ? '规则 ${index + 1}'
                        : nameController.text.trim(),
                    type: type,
                    match: matchController.text.trim(),
                    target: target,
                  );
                });
                Navigator.pop(ctx);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示预设规则面板
  void _importPresets() {
    setState(() => _showPresets = true);
  }

  /// 从预设规则中添加一条到规则列表
  ///
  /// [preset] 预设规则模板
  void _addPresetRule(RoutingRule preset) {
    setState(() {
      _rules.add(
        RoutingRule(
          id: const Uuid().v4(),
          name: preset.name,
          type: preset.type,
          match: preset.match,
          target: preset.target,
          enabled: true,
        ),
      );
      _showPresets = false;
    });
  }

  /// 保存规则列表并返回上一页
  void _save() {
    widget.onSave(_rules);
    Navigator.of(context).pop();
  }

  /// 获取匹配类型的中文标签
  String _typeLabel(String type) {
    switch (type) {
      case 'domain':
        return '域名';
      case 'domain_keyword':
        return '域名关键词';
      case 'domain_suffix':
        return '域名后缀';
      case 'ip_cidr':
        return 'IP/CIDR';
      case 'geoip':
        return 'GeoIP';
      case 'geosite':
        return 'GeoSite';
      case 'process':
        return '进程名';
      case 'protocol':
        return '协议';
      case 'port':
        return '端口';
      default:
        return type;
    }
  }

  /// 获取匹配类型的输入提示文本
  String _matchHint(String type) {
    switch (type) {
      case 'domain':
        return '例: google.com';
      case 'domain_keyword':
        return '例: openai';
      case 'domain_suffix':
        return '例: .cn';
      case 'ip_cidr':
        return '例: 10.0.0.0/8';
      case 'geoip':
        return '例: cn, us, jp';
      case 'geosite':
        return '例: google, telegram, cn';
      case 'process':
        return '例: chrome.exe';
      case 'protocol':
        return '例: tls, http';
      case 'port':
        return '例: 443';
      default:
        return '匹配值';
    }
  }

  /// 获取规则目标的中文标签
  String _targetLabel(String target) {
    switch (target) {
      case 'proxy':
        return '代理';
      case 'direct':
        return '直连';
      case 'block':
        return '屏蔽';
      default:
        return target;
    }
  }

  /// 获取规则目标对应的图标
  IconData _targetIcon(String target) {
    switch (target) {
      case 'proxy':
        return Icons.flight;
      case 'direct':
        return Icons.lan;
      case 'block':
        return Icons.block;
      default:
        return Icons.help;
    }
  }

  /// 获取规则目标对应的颜色
  Color _targetColor(String target) {
    switch (target) {
      case 'proxy':
        return Colors.blue;
      case 'direct':
        return Colors.green;
      case 'block':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// 获取匹配类型对应的图标
  IconData _typeIcon(String type) {
    switch (type) {
      case 'domain':
        return Icons.language;
      case 'domain_keyword':
        return Icons.text_fields;
      case 'domain_suffix':
        return Icons.abc;
      case 'ip_cidr':
        return Icons.numbers;
      case 'geoip':
        return Icons.public;
      case 'geosite':
        return Icons.public;
      case 'process':
        return Icons.settings_applications;
      case 'protocol':
        return Icons.swap_horiz;
      case 'port':
        return Icons.settings_ethernet;
      default:
        return Icons.rule;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('路由规则'),
        actions: [
          TextButton.icon(
            onPressed: _importPresets,
            icon: const Icon(Icons.download, size: 18),
            label: const Text('预设'),
          ),
          FilledButton(onPressed: _save, child: const Text('保存')),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (_showPresets)
            Container(
              color: theme.colorScheme.surfaceContainerLow,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                    child: Row(
                      children: [
                        Text(
                          '预设规则',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => _showPresets = false),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 140,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: RoutingRule.presetRules.map((preset) {
                        final exists = _rules.any(
                          (r) =>
                              r.type == preset.type && r.match == preset.match,
                        );
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ActionChip(
                            avatar: Icon(
                              _targetIcon(preset.target),
                              size: 16,
                              color: _targetColor(preset.target),
                            ),
                            label: Text(preset.name),
                            onPressed: exists
                                ? null
                                : () => _addPresetRule(preset),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _rules.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.route,
                          size: 64,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '暂无路由规则',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '点击 + 添加规则，或导入预设规则',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.tonal(
                          onPressed: _importPresets,
                          child: const Text('导入预设规则'),
                        ),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _rules.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (oldIndex < newIndex) newIndex--;
                        final item = _rules.removeAt(oldIndex);
                        _rules.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final rule = _rules[index];
                      return Card(
                        key: ValueKey(rule.id),
                        margin: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
                          dense: true,
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: rule.enabled,
                                onChanged: (_) => _toggleRule(index),
                              ),
                              Icon(
                                _typeIcon(rule.type),
                                size: 18,
                                color: theme.colorScheme.outline,
                              ),
                            ],
                          ),
                          title: Row(
                            children: [
                              Expanded(child: Text(rule.name)),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _targetColor(
                                    rule.target,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _targetLabel(rule.target),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: _targetColor(rule.target),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            '${_typeLabel(rule.type)}: ${rule.match}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => _editRule(index),
                                icon: const Icon(Icons.edit, size: 18),
                                visualDensity: VisualDensity.compact,
                              ),
                              IconButton(
                                onPressed: () => _removeRule(index),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                ),
                                color: theme.colorScheme.error,
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          onTap: () => _editRule(index),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addRule,
        child: const Icon(Icons.add),
      ),
    );
  }
}
