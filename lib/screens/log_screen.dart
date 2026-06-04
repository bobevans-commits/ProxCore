import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/proxy_service.dart';

/// LogScreen - 日志查看页面
///
/// 实时显示代理内核的运行日志，支持按级别过滤、关键词搜索、
/// 自动滚动、清空日志和分享导出
class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

/// _LogScreenState - LogScreen 的状态类
///
/// 监听日志流并自动滚动到底部，支持级别过滤和关键词搜索
class _LogScreenState extends State<LogScreen> {
  /// 滚动控制器，用于自动滚动到底部
  final ScrollController _scrollController = ScrollController();

  /// 当前日志过滤级别
  LogLevel _filterLevel = LogLevel.all;

  /// 日志流订阅
  StreamSubscription<String>? _logSubscription;

  /// 是否启用自动滚动
  bool _autoScroll = true;

  /// 是否显示搜索栏
  bool _showSearch = false;

  /// 搜索关键词
  String _searchQuery = '';

  /// 搜索输入控制器
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final proxyService = context.read<ProxyService>();
    _logSubscription = proxyService.logStream.listen((_) {
      if (_autoScroll && _scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _logSubscription?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// 根据当前过滤级别和搜索关键词过滤日志列表
  ///
  /// [logs] 原始日志列表
  List<String> _filterLogs(List<String> logs) {
    var filtered = logs;
    if (_filterLevel != LogLevel.all) {
      filtered = filtered.where((log) {
        switch (_filterLevel) {
          case LogLevel.error:
            return log.contains('[ERROR]');
          case LogLevel.warning:
            return log.contains('[WARN]');
          case LogLevel.info:
            return log.contains('[INFO]');
          default:
            return true;
        }
      }).toList();
    }
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (log) => log.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final proxyService = context.watch<ProxyService>();
    final theme = Theme.of(context);
    final filteredLogs = _filterLogs(proxyService.logs);

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            title: _showSearch
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: '搜索日志...',
                      border: InputBorder.none,
                    ),
                    style: theme.textTheme.bodyMedium,
                    onChanged: (v) => setState(() => _searchQuery = v),
                  )
                : const Text('日志'),
            actions: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) {
                      _searchQuery = '';
                      _searchController.clear();
                    }
                  });
                },
                icon: Icon(_showSearch ? Icons.close : Icons.search),
                tooltip: '搜索',
              ),
              PopupMenuButton<LogLevel>(
                icon: const Icon(Icons.filter_list),
                onSelected: (level) {
                  setState(() => _filterLevel = level);
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: LogLevel.all, child: Text('全部')),
                  const PopupMenuItem(
                    value: LogLevel.info,
                    child: Text('Info'),
                  ),
                  const PopupMenuItem(
                    value: LogLevel.warning,
                    child: Text('Warning'),
                  ),
                  const PopupMenuItem(
                    value: LogLevel.error,
                    child: Text('Error'),
                  ),
                ],
              ),
              IconButton(
                onPressed: () {
                  proxyService.clearLogs();
                },
                icon: const Icon(Icons.delete_sweep),
                tooltip: '清空日志',
              ),
              IconButton(
                onPressed: () {
                  final logs = proxyService.logs.join('\n');
                  Share.share(logs);
                },
                icon: const Icon(Icons.share),
                tooltip: '导出日志',
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('自动滚动', style: theme.textTheme.bodyMedium),
                  Switch(
                    value: _autoScroll,
                    onChanged: (v) => setState(() => _autoScroll = v),
                  ),
                  const Spacer(),
                  Text(
                    '${filteredLogs.length} 条日志',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index >= filteredLogs.length) return null;

              final log = filteredLogs[index];
              final isError = log.contains('[ERROR]');
              final isWarning = log.contains('[WARN]');

              return ListTile(
                dense: true,
                leading: Icon(
                  isError
                      ? Icons.error
                      : isWarning
                      ? Icons.warning
                      : Icons.info,
                  size: 16,
                  color: isError
                      ? Colors.red
                      : isWarning
                      ? Colors.orange
                      : theme.colorScheme.outline,
                ),
                title: Text(
                  log,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: isError
                        ? Colors.red
                        : isWarning
                        ? Colors.orange
                        : null,
                  ),
                ),
              );
            }, childCount: filteredLogs.length),
          ),
        ],
      ),
    );
  }
}

/// LogLevel - 日志过滤级别枚举
///
/// 用于日志页面的级别过滤功能
enum LogLevel {
  /// 显示全部日志
  all,

  /// 仅显示 Info 级别
  info,

  /// 仅显示 Warning 级别
  warning,

  /// 仅显示 Error 级别
  error,
}
