import 'package:flutter/material.dart';

import '../models/config.dart';
import '../utils/app_utils.dart';

/// ProxyLinkImporter - 代理链接导入器
///
/// 用于从剪贴板粘贴代理链接并自动识别协议格式，
/// 解析后通过回调返回 NodeConfig 对象
class ProxyLinkImporter extends StatefulWidget {
  /// 导入成功回调，传入解析后的节点配置
  final void Function(NodeConfig) onImport;

  const ProxyLinkImporter({super.key, required this.onImport});

  @override
  State<ProxyLinkImporter> createState() => _ProxyLinkImporterState();
}

/// _ProxyLinkImporterState - ProxyLinkImporter 的状态类
///
/// 管理输入文本、协议检测和解析错误状态
class _ProxyLinkImporterState extends State<ProxyLinkImporter> {
  /// 文本输入控制器
  final _controller = TextEditingController();

  /// 自动检测到的协议类型，null 表示未识别
  ProxyProtocol? _detectedProtocol;

  /// 解析错误信息，null 表示无错误
  String? _parseError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 检测输入文本中的代理协议
  ///
  /// [text] 用户输入的文本
  void _detectProtocol(String text) {
    final trimmed = text.trim();
    setState(() {
      _parseError = null;
      _detectedProtocol = AppUtils.detectProtocol(trimmed);
      if (_detectedProtocol == null && trimmed.isNotEmpty) {
        _parseError = '无法识别的协议格式';
      }
    });
  }

  /// 执行导入操作
  ///
  /// 解析输入的代理链接，成功后调用 [onImport] 回调并关闭页面
  void _import() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (_detectedProtocol == null) {
      setState(() => _parseError = '无法识别的协议格式');
      return;
    }

    try {
      final node = AppUtils.parseProxyLink(text);
      widget.onImport(node);
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _parseError = '解析失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '导入代理链接',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 4,
            decoration: InputDecoration(
              hintText:
                  '粘贴代理链接 (vmess://, vless://, trojan://, ss://, hy2://, ...)',
              border: const OutlineInputBorder(),
              suffixIcon: _detectedProtocol != null
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        '${AppUtils.protocolIcon(_detectedProtocol!)} ${_detectedProtocol!.label}',
                        style: theme.textTheme.bodySmall,
                      ),
                    )
                  : null,
              errorText: _parseError,
            ),
            onChanged: _detectProtocol,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _detectedProtocol != null ? _import : null,
                child: const Text('导入'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
