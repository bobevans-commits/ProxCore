import 'package:flutter/material.dart';

import '../models/config.dart';
import '../services/kernel_manager.dart';

/// KernelInstallScreen - 内核安装页面
///
/// 通用内核下载安装界面，供 HomeScreen 和 SettingsScreen 复用
/// 下载成功后自动返回上一页并传递 true，失败则显示重试按钮
class KernelInstallScreen extends StatefulWidget {
  final KernelType kernelType;
  final KernelManager kernelManager;

  const KernelInstallScreen({
    super.key,
    required this.kernelType,
    required this.kernelManager,
  });

  @override
  State<KernelInstallScreen> createState() => _KernelInstallScreenState();
}

class _KernelInstallScreenState extends State<KernelInstallScreen> {
  bool _downloading = false;
  double? _progress;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _progress = null;
    });

    widget.kernelManager.addListener(_onManagerUpdate);

    try {
      await widget.kernelManager.downloadKernel(widget.kernelType);
      if (mounted) {
        widget.kernelManager.removeListener(_onManagerUpdate);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        widget.kernelManager.removeListener(_onManagerUpdate);
        setState(() => _downloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('下载失败: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _onManagerUpdate() {
    if (mounted) {
      setState(() {
        _progress = widget.kernelManager.downloadProgress;
      });
    }
  }

  @override
  void dispose() {
    widget.kernelManager.removeListener(_onManagerUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('安装 ${widget.kernelType.label}')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.download,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                _downloading
                    ? '正在下载 ${widget.kernelType.label} 内核...'
                    : '准备下载...',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              if (_downloading) ...[
                SizedBox(
                  width: 280,
                  child: LinearProgressIndicator(value: _progress),
                ),
                const SizedBox(height: 8),
                if (_progress != null)
                  Text(
                    '${(_progress! * 100).toStringAsFixed(1)}%',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ],
              const SizedBox(height: 24),
              Text(
                '下载完成后将自动返回并开启 TUN 模式',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 16),
              if (!_downloading)
                FilledButton.icon(
                  onPressed: _startDownload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
