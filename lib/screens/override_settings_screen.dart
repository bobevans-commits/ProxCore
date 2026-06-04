import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/proxy_service.dart';
import '../widgets/glass_theme.dart';

/// OverrideSettingsScreen - 配置覆写界面
///
/// 允许用户为不同的内核（sing-box、mihomo、v2ray）配置 JSON 格式的覆写内容。
/// 在内核启动生成配置时，将使用深度合并算法递归覆写。
class OverrideSettingsScreen extends StatefulWidget {
  const OverrideSettingsScreen({super.key});

  @override
  State<OverrideSettingsScreen> createState() => _OverrideSettingsScreenState();
}

class _OverrideSettingsScreenState extends State<OverrideSettingsScreen> {
  late final TextEditingController _singboxController;
  late final TextEditingController _mihomoController;
  late final TextEditingController _v2rayController;

  String? _singboxError;
  String? _mihomoError;
  String? _v2rayError;

  @override
  void initState() {
    super.initState();
    final proxyService = context.read<ProxyService>();
    final overrides = proxyService.config.configOverrides;

    _singboxController = TextEditingController(
      text: overrides['singbox'] ?? '',
    );
    _mihomoController = TextEditingController(text: overrides['mihomo'] ?? '');
    _v2rayController = TextEditingController(text: overrides['v2ray'] ?? '');

    // 初始验证
    _validateJson(_singboxController.text, 'singbox');
    _validateJson(_mihomoController.text, 'mihomo');
    _validateJson(_v2rayController.text, 'v2ray');

    // 监听输入
    _singboxController.addListener(
      () => _validateJson(_singboxController.text, 'singbox'),
    );
    _mihomoController.addListener(
      () => _validateJson(_mihomoController.text, 'mihomo'),
    );
    _v2rayController.addListener(
      () => _validateJson(_v2rayController.text, 'v2ray'),
    );
  }

  void _validateJson(String text, String kernel) {
    if (text.trim().isEmpty) {
      if (mounted) {
        setState(() {
          if (kernel == 'singbox') _singboxError = null;
          if (kernel == 'mihomo') _mihomoError = null;
          if (kernel == 'v2ray') _v2rayError = null;
        });
      }
      return;
    }
    try {
      final parsed = jsonDecode(text);
      if (parsed is! Map) {
        throw const FormatException('根节点必须是一个 JSON 对象 (Map)');
      }
      if (mounted) {
        setState(() {
          if (kernel == 'singbox') _singboxError = null;
          if (kernel == 'mihomo') _mihomoError = null;
          if (kernel == 'v2ray') _v2rayError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (kernel == 'singbox') _singboxError = e.toString();
          if (kernel == 'mihomo') _mihomoError = e.toString();
          if (kernel == 'v2ray') _v2rayError = e.toString();
        });
      }
    }
  }

  void _formatJson(TextEditingController controller) {
    final text = controller.text;
    if (text.trim().isEmpty) return;
    try {
      final parsed = jsonDecode(text);
      final formatted = const JsonEncoder.withIndent('  ').convert(parsed);
      setState(() {
        controller.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('格式化失败：JSON 语法错误 ($e)'),
          backgroundColor: GlassTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _saveOverrides() {
    if (_singboxError != null || _mihomoError != null || _v2rayError != null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            size: 36,
            color: GlassTheme.warningColor,
          ),
          title: const Text('配置存在语法错误'),
          content: const Text(
            '部分内核覆写配置的 JSON 格式不正确。保存错误的配置可能会导致对应内核启动失败，是否仍要保存？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _doSave();
              },
              child: const Text('仍然保存'),
            ),
          ],
        ),
      );
    } else {
      _doSave();
    }
  }

  void _doSave() {
    final proxyService = context.read<ProxyService>();
    final newOverrides = {
      'singbox': _singboxController.text,
      'mihomo': _mihomoController.text,
      'v2ray': _v2rayController.text,
    };

    proxyService.updateConfig(
      proxyService.config.copyWith(configOverrides: newOverrides),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('配置覆写已保存'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _singboxController.dispose();
    _mihomoController.dispose();
    _v2rayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('配置覆写'),
          actions: [
            TextButton.icon(
              onPressed: _saveOverrides,
              icon: const Icon(Icons.save_outlined),
              label: const Text('保存'),
            ),
            const SizedBox(width: 8),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'sing-box'),
              Tab(text: 'mihomo (Clash)'),
              Tab(text: 'v2ray (Xray)'),
            ],
          ),
        ),
        body: Container(
          color: theme.scaffoldBackgroundColor,
          child: TabBarView(
            children: [
              _buildEditorTab('singbox', _singboxController, _singboxError),
              _buildEditorTab('mihomo', _mihomoController, _mihomoError),
              _buildEditorTab('v2ray', _v2rayController, _v2rayError),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditorTab(
    String kernel,
    TextEditingController controller,
    String? error,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    String tip = '';
    if (kernel == 'singbox') {
      tip =
          'sing-box 覆写格式：支持 JSON 递归深度合并。例如修改 DNS 服务器，覆写示例：\n{\n  "dns": {\n    "servers": [\n      { "address": "8.8.8.8", "tag": "google" }\n    ]\n  }\n}';
    } else if (kernel == 'mihomo') {
      tip =
          'mihomo (Clash Meta) 覆写格式：本客户端使用 JSON 输入以便合并。例如开启 DNS 监听与配置：\n{\n  "dns": {\n    "enable": true,\n    "listen": "0.0.0.0:1053"\n  }\n}';
    } else if (kernel == 'v2ray') {
      tip =
          'v2ray (Xray) 覆写格式：例如覆写系统日志级别：\n{\n  "log": {\n    "loglevel": "debug"\n  }\n}';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 提示卡片
          GlassCard(
            opacity: 0.05,
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tip,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      height: 1.4,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 操作工具栏
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'JSON 覆写内容 (根节点须为 Map)',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _formatJson(controller),
                    icon: const Icon(Icons.format_align_left_rounded, size: 16),
                    label: const Text('格式化', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('确认清空？'),
                          content: const Text('清空后此内核的覆写配置将恢复为空白。'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('取消'),
                            ),
                            FilledButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                controller.clear();
                              },
                              child: const Text('清空'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.cleaning_services_rounded, size: 16),
                    label: const Text('清空', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      foregroundColor: theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Monospace 输入框
          GlassCard(
            opacity: isDark ? 0.03 : 0.05,
            padding: EdgeInsets.zero,
            child: TextField(
              controller: controller,
              maxLines: null,
              minLines: 15,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                hintText: '{\n  // 在此编写您的自定义配置\n}',
                contentPadding: EdgeInsets.all(16),
                border: InputBorder.none,
              ),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 实时状态栏
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: error != null
                  ? GlassTheme.errorColor.withValues(alpha: 0.1)
                  : (controller.text.trim().isEmpty
                        ? Colors.transparent
                        : GlassTheme.successColor.withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: error != null
                    ? GlassTheme.errorColor.withValues(alpha: 0.3)
                    : (controller.text.trim().isEmpty
                          ? Colors.transparent
                          : GlassTheme.successColor.withValues(alpha: 0.3)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  error != null
                      ? Icons.error_outline_rounded
                      : (controller.text.trim().isEmpty
                            ? Icons.code_rounded
                            : Icons.check_circle_outline_rounded),
                  size: 16,
                  color: error != null
                      ? GlassTheme.errorColor
                      : (controller.text.trim().isEmpty
                            ? theme.colorScheme.outline
                            : GlassTheme.successColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error ??
                        (controller.text.trim().isEmpty
                            ? '配置为空，将使用默认配置'
                            : 'JSON 格式正确'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: error != null
                          ? GlassTheme.errorColor
                          : (controller.text.trim().isEmpty
                                ? theme.colorScheme.outline
                                : GlassTheme.successColor),
                      fontFamily: error != null ? 'monospace' : null,
                      fontSize: error != null ? 11 : 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
