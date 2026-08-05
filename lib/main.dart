// ProxCore 应用入口
// 多内核代理客户端，支持 sing-box / mihomo / v2ray
// 初始化所有服务并通过 Provider 注入到 Widget 树

import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'screens/subscriptions_screen.dart';
import 'screens/node_editor_screen.dart';
import 'screens/routing_editor_screen.dart';
import 'screens/log_screen.dart';
import 'screens/settings_screen.dart';
import 'services/clash_api_service.dart';
import 'services/config_storage_service.dart';
import 'services/geo_data_service.dart';
import 'services/kernel_manager.dart';
import 'services/proxy_service.dart';
import 'services/smart_router.dart';
import 'services/subscription_service.dart';
import 'services/tray_service.dart';
import 'services/webdav_sync_service.dart';
import 'widgets/glass_theme.dart';
import 'widgets/node_list_sheet.dart';
import 'widgets/proxy_link_importer.dart';

/// 应用入口函数
///
/// 初始化流程：
/// 1. 初始化 Flutter 绑定
/// 2. 初始化配置存储服务
/// 3. 初始化内核管理器（检测已安装内核）
/// 4. 初始化代理服务（加载配置和节点）
/// 5. 初始化订阅服务（加载订阅列表，配置自动刷新）
/// 6. 初始化 Clash API、智能路由、GeoIP/GeoSite、WebDAV 同步
/// 7. 注入依赖到 ProxyService
/// 8. 初始化系统托盘（桌面平台）
/// 9. 启动应用（MultiProvider + MyApp）
/// 10. 配置窗口（bitsdojo_window：大小、最小尺寸、居中、标题）
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final configStorage = ConfigStorageService();
  await configStorage.init();

  final kernelManager = KernelManager();
  await kernelManager.init();

  final proxyService = ProxyService(kernelManager, configStorage);
  await proxyService.init();

  final subscriptionService = SubscriptionService(configStorage);
  await subscriptionService.init();
  subscriptionService.onNodesRefreshed = (nodes) async {
    proxyService.addNodes(nodes);
  };
  if (proxyService.config.subRefreshMinutes > 0) {
    subscriptionService.setupAutoRefresh(proxyService.config.subRefreshMinutes);
  }

  final clashApi = ClashApiService();
  final smartRouter = SmartRouter();
  final geoDataService = GeoDataService();
  await geoDataService.init();
  final webdavService = WebDavSyncService();

  proxyService.setClashApi(clashApi);
  proxyService.setSmartRouter(smartRouter);

  TrayService? trayService;
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    trayService = TrayService(proxyService);
    await trayService.init();
    proxyService.addListener(() => trayService?.update());
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: kernelManager),
        ChangeNotifierProvider.value(value: proxyService),
        ChangeNotifierProvider.value(value: subscriptionService),
        ChangeNotifierProvider.value(value: clashApi),
        ChangeNotifierProvider.value(value: smartRouter),
        ChangeNotifierProvider.value(value: geoDataService),
        ChangeNotifierProvider.value(value: webdavService),
      ],
      child: const MyApp(),
    ),
  );

  doWhenWindowReady(() {
    const initialSize = Size(960, 680);
    const minSize = Size(480, 400);
    appWindow.minSize = minSize;
    appWindow.size = initialSize;
    appWindow.alignment = Alignment.center;
    appWindow.title = 'ProxCore';
    // 托盘"显示主窗口"菜单项依赖窗口已就绪，故在此注入
    trayService?.onShowWindow = () => appWindow.show();
    appWindow.show();
  });
}

/// 应用根组件
///
/// 管理主题模式（亮色/暗色），提供全局主题切换方法
class MyApp extends StatefulWidget {
  /// 构造函数
  const MyApp({super.key});

  /// 切换主题模式的静态方法
  ///
  /// 通过 findAncestorStateOfType 查找 _MyAppState 并调用 toggleTheme
  static void toggleThemeOf(BuildContext context) {
    final state = context.findAncestorStateOfType<_MyAppState>();
    state?.toggleTheme();
  }

  /// 创建状态管理实例
  @override
  State<MyApp> createState() => _MyAppState();
}

/// MyApp 状态管理
///
/// 管理当前主题模式，默认跟随系统
class _MyAppState extends State<MyApp> {
  /// 当前主题模式
  ThemeMode _themeMode = ThemeMode.system;

  /// 获取当前主题模式
  ThemeMode get themeMode => _themeMode;

  /// 设置主题模式
  void setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
  }

  /// 切换亮色/暗色主题
  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
    });
  }

  /// 构建应用根 Widget，配置 MaterialApp 主题和主页
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ProxCore',
      debugShowCheckedModeBanner: false,
      theme: GlassTheme.lightTheme,
      darkTheme: GlassTheme.darkTheme,
      themeMode: _themeMode,
      home: const MainNavigation(),
    );
  }
}

/// 自定义标题栏组件
///
/// 使用 bitsdojo_window 实现无边框窗口的自定义标题栏
/// 包含：可拖动区域、窗口标题、最小化/最大化/关闭按钮
class _CustomTitleBar extends StatelessWidget {
  const _CustomTitleBar();

  /// 构建自定义标题栏，包含拖动区域和窗口控制按钮
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return WindowTitleBarBox(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0A0E27) : const Color(0xFFF0F2F5),
        ),
        child: Row(
          children: [
            Expanded(
              child: MoveWindow(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    'ProxCore',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ),
              ),
            ),
            MinimizeWindowButton(
              colors: WindowButtonColors(
                iconNormal: isDark ? Colors.white54 : Colors.black45,
                mouseOver: isDark ? Colors.white10 : Colors.black12,
              ),
            ),
            MaximizeWindowButton(
              colors: WindowButtonColors(
                iconNormal: isDark ? Colors.white54 : Colors.black45,
                mouseOver: isDark ? Colors.white10 : Colors.black12,
              ),
            ),
            CloseWindowButton(
              colors: WindowButtonColors(
                iconNormal: isDark ? Colors.white54 : Colors.black45,
                mouseOver: Colors.red.shade400,
                mouseDown: Colors.red.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 主导航组件
///
/// 底部导航栏 + 侧边抽屉 + 浮动添加按钮
/// 四个页面：仪表板、订阅、日志、设置
class MainNavigation extends StatefulWidget {
  /// 构造函数
  const MainNavigation({super.key});

  /// 创建状态管理实例
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

/// MainNavigation 状态管理
class _MainNavigationState extends State<MainNavigation> {
  /// 当前选中的导航索引
  int _currentIndex = 0;

  /// 四个主页面
  final _screens = const [
    HomeScreen(),
    SubscriptionsScreen(),
    LogScreen(),
    SettingsScreen(),
  ];

  /// 显示节点列表底部弹窗
  ///
  /// 使用 DraggableScrollableSheet 实现可拖拽高度的节点列表
  void _showNodeList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, controller) => NodeListSheet(
          scrollController: controller,
          onAdd: () {
            Navigator.pop(ctx);
            _showAddNodeOptions();
          },
        ),
      ),
    );
  }

  /// 显示添加节点选项底部弹窗
  ///
  /// 三种添加方式：手动添加、导入链接、从订阅导入
  void _showAddNodeOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('手动添加'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NodeEditorScreen(
                      onSave: (node) {
                        context.read<ProxyService>().addNode(node);
                      },
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('导入链接'),
              onTap: () {
                Navigator.pop(ctx);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => ProxyLinkImporter(
                    onImport: (node) {
                      context.read<ProxyService>().addNode(node);
                    },
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.rss_feed),
              title: const Text('从订阅导入'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _currentIndex = 1);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 构建主导航页面，包含页面内容、底部导航栏、侧边抽屉和浮动按钮
  @override
  Widget build(BuildContext context) {
    final proxyService = context.watch<ProxyService>();

    return Scaffold(
      body: Column(
        children: [
          if (Platform.isWindows) const _CustomTitleBar(),
          Expanded(child: _screens[_currentIndex]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: '仪表板',
          ),
          NavigationDestination(
            icon: Icon(Icons.rss_feed_outlined),
            selectedIcon: Icon(Icons.rss_feed),
            label: '订阅',
          ),
          NavigationDestination(
            icon: Icon(Icons.article_outlined),
            selectedIcon: Icon(Icons.article),
            label: '日志',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
      drawer: _AppDrawer(
        onToggleTheme: () => MyApp.toggleThemeOf(context),
        onOpenRouting: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RoutingEditorScreen(
                rules: proxyService.routingRules,
                onSave: (rules) {
                  proxyService.updateRoutingRules(rules);
                },
              ),
            ),
          );
        },
        onOpenNodeList: _showNodeList,
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: _showAddNodeOptions,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

/// 应用侧边抽屉
///
/// 包含：节点列表入口、路由规则入口、主题切换、关于
class _AppDrawer extends StatelessWidget {
  /// 主题切换回调
  final VoidCallback onToggleTheme;

  /// 打开路由规则编辑器回调
  final VoidCallback onOpenRouting;

  /// 打开节点列表回调
  final VoidCallback onOpenNodeList;

  /// 构造函数
  const _AppDrawer({
    required this.onToggleTheme,
    required this.onOpenRouting,
    required this.onOpenNodeList,
  });

  /// 构建侧边抽屉菜单，包含节点列表、路由规则、主题切换和关于
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final proxyService = context.watch<ProxyService>();

    return NavigationDrawer(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 16, 8),
          child: Text('ProxCore', style: theme.textTheme.titleMedium),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.list),
          title: Text('节点列表 (${proxyService.nodes.length})'),
          subtitle: proxyService.activeNode != null
              ? Text(
                  '当前: ${proxyService.activeNode!.name}',
                  style: const TextStyle(fontSize: 12),
                )
              : null,
          onTap: () {
            Navigator.pop(context);
            onOpenNodeList();
          },
        ),
        ListTile(
          leading: const Icon(Icons.route),
          title: Text('路由规则 (${proxyService.routingRules.length})'),
          onTap: () {
            Navigator.pop(context);
            onOpenRouting();
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.dark_mode),
          title: const Text('切换主题'),
          onTap: () {
            Navigator.pop(context);
            onToggleTheme();
          },
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('关于'),
          onTap: () {
            Navigator.pop(context);
            showAboutDialog(
              context: context,
              applicationName: 'ProxCore',
              applicationVersion: '1.0.0',
              applicationIcon: const Icon(Icons.vpn_lock, size: 48),
              children: [
                const Text('多内核代理客户端'),
                const SizedBox(height: 8),
                const Text('支持 sing-box / mihomo / v2ray'),
              ],
            );
          },
        ),
      ],
    );
  }
}
