import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/config.dart';
import '../utils/app_utils.dart';

/// NodeEditorScreen - 节点编辑器页面
///
/// 用于添加或编辑代理节点配置，支持多种协议（VMess、VLESS、Trojan 等），
/// 根据所选协议动态显示对应的配置字段
class NodeEditorScreen extends StatefulWidget {
  /// 待编辑的节点，为 null 时表示新增节点
  final NodeConfig? node;

  /// 保存回调，传入编辑后的节点配置
  final void Function(NodeConfig) onSave;

  const NodeEditorScreen({
    super.key,
    this.node,
    required this.onSave,
  });

  @override
  State<NodeEditorScreen> createState() => _NodeEditorScreenState();
}

/// _NodeEditorScreenState - NodeEditorScreen 的状态类
///
/// 管理表单控制器和协议相关的动态字段
class _NodeEditorScreenState extends State<NodeEditorScreen> {
  /// 表单全局键，用于表单验证
  final _formKey = GlobalKey<FormState>();

  /// 节点名称控制器
  late TextEditingController _nameController;

  /// 节点地址控制器
  late TextEditingController _addressController;

  /// 节点端口控制器
  late TextEditingController _portController;

  /// 当前选中的代理协议
  ProxyProtocol _selectedProtocol = ProxyProtocol.vmess;

  /// 协议扩展字段的控制器映射（如 uuid、password、sni 等）
  final Map<String, TextEditingController> _extraControllers = {};

  @override
  void initState() {
    super.initState();
    final node = widget.node;
    _nameController = TextEditingController(text: node?.name ?? '');
    _addressController = TextEditingController(text: node?.address ?? '');
    _portController = TextEditingController(text: (node?.port ?? 443).toString());
    _selectedProtocol = node?.protocol ?? ProxyProtocol.vmess;

    if (node?.extra != null) {
      for (final entry in node!.extra.entries) {
        _extraControllers[entry.key] = TextEditingController(
          text: entry.value.toString(),
        );
      }
    }

    _ensureExtraControllers();
  }

  /// 确保当前协议所需的扩展字段控制器都已创建
  void _ensureExtraControllers() {
    final requiredFields = _getRequiredFields(_selectedProtocol);
    for (final field in requiredFields) {
      _extraControllers.putIfAbsent(
        field,
        () => TextEditingController(),
      );
    }
  }

  /// 获取指定协议所需的扩展字段列表
  ///
  /// [protocol] 代理协议类型
  List<String> _getRequiredFields(ProxyProtocol protocol) {
    switch (protocol) {
      case ProxyProtocol.vmess:
        return ['uuid', 'alterId', 'security', 'network'];
      case ProxyProtocol.vless:
        return ['uuid', 'flow', 'security', 'type'];
      case ProxyProtocol.trojan:
        return ['password', 'sni'];
      case ProxyProtocol.shadowsocks:
        return ['method', 'password'];
      case ProxyProtocol.hysteria:
        return ['auth', 'sni'];
      case ProxyProtocol.hysteria2:
        return ['password', 'sni'];
      case ProxyProtocol.tuic:
        return ['uuid', 'password', 'sni'];
      case ProxyProtocol.naive:
        return ['username', 'password'];
      case ProxyProtocol.wireguard:
        return ['privateKey', 'peerPublicKey', 'localAddress'];
    }
  }

  /// 获取扩展字段的中文标签
  ///
  /// [key] 字段键名
  String _getFieldLabel(String key) {
    const labels = {
      'uuid': 'UUID',
      'alterId': 'Alter ID',
      'security': '加密方式',
      'network': '传输协议',
      'flow': 'Flow',
      'type': '传输类型',
      'password': '密码',
      'sni': 'SNI',
      'method': '加密方法',
      'insecure': '跳过证书验证',
      'username': '用户名',
      'privateKey': '私钥',
      'peerPublicKey': '对端公钥',
      'localAddress': '本地地址',
      'wsPath': 'WS 路径',
      'wsHost': 'WS Host',
      'publicKey': '公钥',
      'shortId': 'Short ID',
      'auth': '认证',
    };
    return labels[key] ?? key;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _portController.dispose();
    for (final c in _extraControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// 保存节点配置
  ///
  /// 验证表单后构建 NodeConfig 对象，调用 [onSave] 回调并返回上一页
  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final extra = <String, dynamic>{};
    for (final entry in _extraControllers.entries) {
      final value = entry.value.text.trim();
      if (value.isNotEmpty) {
        if (entry.key == 'alterId' || entry.key == 'insecure') {
          extra[entry.key] = int.tryParse(value) ?? 0;
        } else {
          extra[entry.key] = value;
        }
      }
    }

    final node = NodeConfig(
      id: widget.node?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      protocol: _selectedProtocol,
      address: _addressController.text.trim(),
      port: int.tryParse(_portController.text.trim()) ?? 443,
      extra: extra,
    );

    widget.onSave(node);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.node == null ? '添加节点' : '编辑节点'),
        actions: [
          FilledButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('基本配置', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<ProxyProtocol>(
                      initialValue: _selectedProtocol,
                      decoration: const InputDecoration(
                        labelText: '协议',
                        border: OutlineInputBorder(),
                      ),
                      items: ProxyProtocol.values
                          .map((p) => DropdownMenuItem(
                                value: p,
                                child: Text(
                                    '${AppUtils.protocolIcon(p)} ${p.label}'),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedProtocol = value;
                            _ensureExtraControllers();
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '名称',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? '请输入名称' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: '地址',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? '请输入地址' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _portController,
                      decoration: const InputDecoration(
                        labelText: '端口',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final port = int.tryParse(v ?? '');
                        if (port == null || !AppUtils.isValidPort(port)) {
                          return '请输入有效端口 (1-65535)';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_selectedProtocol.label} 配置',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 16),
                    ..._getRequiredFields(_selectedProtocol).map(
                      (field) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextFormField(
                          controller: _extraControllers[field],
                          decoration: InputDecoration(
                            labelText: _getFieldLabel(field),
                            border: const OutlineInputBorder(),
                          ),
                          obscureText:
                              field.contains('password') ||
                                  field.contains('privateKey') ||
                                  field.contains('Key'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
