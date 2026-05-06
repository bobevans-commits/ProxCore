import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/config.dart';
import '../models/kernel_info.dart';
import '../services/kernel_manager.dart';
import '../services/proxy_service.dart';

/// KernelSettingsScreen - 内核管理页面
///
/// 展示所有可用内核（sing-box、mihomo、v2ray）的安装状态，
/// 支持下载、安装、删除、更新和切换内核
class KernelSettingsScreen extends StatefulWidget {
  const KernelSettingsScreen({super.key});

  @override
  State<KernelSettingsScreen> createState() => _KernelSettingsScreenState();
}

/// _KernelSettingsScreenState - KernelSettingsScreen 的状态类
class _KernelSettingsScreenState extends State<KernelSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final kernelManager = context.watch<KernelManager>();
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(title: const Text('内核管理')),
          if (kernelManager.error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Card(
                  color: theme.colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 18,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            kernelManager.error!,
                            style: TextStyle(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: theme.colorScheme.onErrorContainer,
                            size: 18,
                          ),
                          onPressed: () {
                            kernelManager.clearError();
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '下载并管理代理内核。点击「安装」下载最新版本，或点击「选择版本」安装指定版本。',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final type = KernelType.values[index];
              final status = kernelManager.getStatus(type);
              final version = kernelManager.getVersion(type);
              final isInstalled = kernelManager.isInstalled(type);
              final progress = kernelManager.downloadProgress;
              final proxyService = context.watch<ProxyService>();
              final isActive = proxyService.config.kernelType == type;

              return _KernelCard(
                type: type,
                status: status,
                version: version,
                isInstalled: isInstalled,
                isActive: isActive,
                downloadProgress: status == KernelStatus.downloading
                    ? progress
                    : null,
                onDownload: () => _downloadKernel(kernelManager, type),
                onDownloadVersion: () =>
                    _showVersionPicker(kernelManager, type),
                onDelete: () => _deleteKernel(kernelManager, type),
                onCheckUpdate: () => _checkUpdate(kernelManager, type),
                onSetActive: isInstalled && !isActive
                    ? () {
                        proxyService.updateConfig(
                          proxyService.config.copyWith(kernelType: type),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('已切换到 ${type.label} 内核'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    : null,
              );
            }, childCount: KernelType.values.length),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
        ],
      ),
    );
  }

  /// 下载指定类型的内核
  ///
  /// [manager] 内核管理器，[type] 内核类型，[version] 可选的指定版本号
  Future<void> _downloadKernel(
    KernelManager manager,
    KernelType type, {
    String? version,
  }) async {
    try {
      await manager.downloadKernel(type, version: version);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${type.label} v${version ?? "最新版"} 安装成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('下载失败: $e')));
      }
    }
  }

  /// 显示版本选择对话框
  ///
  /// [manager] 内核管理器，[type] 内核类型
  /// 先从 GitHub 获取版本列表，再弹出选择对话框
  Future<void> _showVersionPicker(
    KernelManager manager,
    KernelType type,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 16),
            Text('正在获取版本列表...'),
          ],
        ),
      ),
    );

    final releases = await manager.getReleaseList(type);

    if (!mounted) return;
    Navigator.pop(context);

    if (releases.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法获取版本列表，请检查网络连接')));
      return;
    }

    final selectedVersion = await showDialog<String>(
      context: context,
      builder: (ctx) => _VersionPickerDialog(
        type: type,
        releases: releases,
        currentVersion: manager.getVersion(type),
      ),
    );

    if (selectedVersion != null && mounted) {
      _downloadKernel(manager, type, version: selectedVersion);
    }
  }

  /// 删除指定类型的内核
  ///
  /// [manager] 内核管理器，[type] 内核类型
  /// 删除前弹出确认对话框
  Future<void> _deleteKernel(KernelManager manager, KernelType type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除内核'),
        content: Text('确定要删除 ${type.label} 吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await manager.deleteKernel(type);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${type.label} 已删除')));
      }
    }
  }

  /// 检查指定类型内核的更新
  ///
  /// [manager] 内核管理器，[type] 内核类型
  /// 对比当前版本和最新版本，提示用户是否更新
  Future<void> _checkUpdate(KernelManager manager, KernelType type) async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('正在检查更新...')));

    final latestVersion = await manager.getLatestVersion(type);
    final currentVersion = manager.getVersion(type);

    if (!mounted) return;

    if (latestVersion.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法获取最新版本信息')));
      return;
    }

    if (latestVersion == currentVersion) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${type.label} 已是最新版本 v$currentVersion')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '发现新版本: v$latestVersion (当前: v${currentVersion ?? "未安装"})',
          ),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: '更新',
            onPressed: () => _downloadKernel(manager, type),
          ),
        ),
      );
    }
  }
}

/// _VersionPickerDialog - 版本选择对话框
///
/// 展示指定内核的所有 GitHub Release 版本列表，
/// 支持选择并返回选中的版本号
class _VersionPickerDialog extends StatelessWidget {
  /// 内核类型
  final KernelType type;

  /// 版本发布信息列表
  final List<KernelReleaseInfo> releases;

  /// 当前已安装的版本号，可能为 null
  final String? currentVersion;

  const _VersionPickerDialog({
    required this.type,
    required this.releases,
    this.currentVersion,
  });

  /// 将 ISO 日期字符串格式化为 YYYY-MM-DD 格式
  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text('选择 ${type.label} 版本'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: ListView.builder(
          itemCount: releases.length,
          itemBuilder: (context, index) {
            final release = releases[index];
            final version = release.version;
            final isCurrent = version == currentVersion;

            return ListTile(
              leading: isCurrent
                  ? const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    )
                  : Icon(
                      Icons.new_releases_outlined,
                      color: index == 0 ? theme.colorScheme.primary : null,
                      size: 20,
                    ),
              title: Row(
                children: [
                  Text(
                    release.tagName,
                    style: TextStyle(
                      fontWeight: index == 0
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  if (index == 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '最新',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                  if (isCurrent)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '已安装',
                          style: TextStyle(fontSize: 10, color: Colors.green),
                        ),
                      ),
                    ),
                ],
              ),
              subtitle: release.publishedAt.isNotEmpty
                  ? Text(
                      _formatDate(release.publishedAt),
                      style: theme.textTheme.bodySmall,
                    )
                  : null,
              enabled: !isCurrent,
              onTap: isCurrent ? null : () => Navigator.pop(context, version),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    );
  }
}

/// _KernelCard - 内核信息卡片
///
/// 展示单个内核的类型、状态、版本信息，
/// 提供安装、更新、删除、切换等操作按钮
class _KernelCard extends StatelessWidget {
  /// 内核类型
  final KernelType type;

  /// 内核当前状态
  final KernelStatus status;

  /// 已安装的版本号，可能为 null
  final String? version;

  /// 是否已安装
  final bool isInstalled;

  /// 是否为当前激活的内核
  final bool isActive;

  /// 下载进度（0.0 ~ 1.0），null 表示不确定进度
  final double? downloadProgress;

  /// 安装最新版回调
  final VoidCallback onDownload;

  /// 选择版本安装回调
  final VoidCallback onDownloadVersion;

  /// 删除内核回调
  final VoidCallback onDelete;

  /// 检查更新回调
  final VoidCallback onCheckUpdate;

  /// 设为当前内核回调，null 表示不可操作
  final VoidCallback? onSetActive;

  const _KernelCard({
    required this.type,
    required this.status,
    this.version,
    required this.isInstalled,
    this.isActive = false,
    this.downloadProgress,
    required this.onDownload,
    required this.onDownloadVersion,
    required this.onDelete,
    required this.onCheckUpdate,
    this.onSetActive,
  });

  /// 根据内核状态返回对应的颜色
  Color _statusColor(BuildContext context) {
    final theme = Theme.of(context);
    switch (status) {
      case KernelStatus.installed:
      case KernelStatus.running:
        return Colors.green;
      case KernelStatus.downloading:
      case KernelStatus.installing:
        return theme.colorScheme.primary;
      case KernelStatus.error:
        return theme.colorScheme.error;
      case KernelStatus.notInstalled:
      case KernelStatus.stopping:
        return theme.colorScheme.outline;
    }
  }

  /// 根据内核类型返回对应的图标
  IconData _kernelIcon() {
    switch (type) {
      case KernelType.singbox:
        return Icons.dns;
      case KernelType.mihomo:
        return Icons.hub;
      case KernelType.v2ray:
        return Icons.language;
    }
  }

  /// 根据内核类型返回描述文本
  String _kernelDescription() {
    switch (type) {
      case KernelType.singbox:
        return '通用代理平台，支持多种协议';
      case KernelType.mihomo:
        return 'Clash Meta 内核，兼容 Clash 规则';
      case KernelType.v2ray:
        return 'Xray 内核，VLESS/XTLS 支持';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(context);
    final isWorking =
        status == KernelStatus.downloading || status == KernelStatus.installing;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_kernelIcon(), size: 22, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            type.label,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            status.description,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (version != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              'v$version',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                          if (isActive) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '当前使用',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        _kernelDescription(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isWorking) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: downloadProgress),
              if (downloadProgress != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '${(downloadProgress! * 100).toStringAsFixed(1)}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
              if (downloadProgress == null && status == KernelStatus.installing)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '正在安装...',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
            ],
            if (!isWorking) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (!isInstalled) ...[
                    FilledButton.icon(
                      onPressed: onDownload,
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('安装'),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: onDownloadVersion,
                      icon: const Icon(Icons.list, size: 16),
                      label: const Text('选择版本'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                  if (isInstalled) ...[
                    if (!isActive && onSetActive != null)
                      FilledButton.icon(
                        onPressed: onSetActive,
                        icon: const Icon(Icons.check_circle, size: 16),
                        label: const Text('设为当前'),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: onCheckUpdate,
                      icon: const Icon(Icons.update, size: 16),
                      label: const Text('更新'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: onDownloadVersion,
                      icon: const Icon(Icons.history, size: 16),
                      label: const Text('其他版本'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('删除'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
