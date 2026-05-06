# ProxCore 知识库索引

> 生成时间: 2026-05-06 | 版本: 1.1.0

## 项目元信息

- **类型**: Flutter 多平台代理客户端
- **内核**: sing-box / mihomo / v2ray
- **平台**: Windows / macOS / Linux / Android
- **状态管理**: Provider + ChangeNotifier
- **Dart SDK**: >=3.0.0 <4.0.0
- **Flutter SDK**: >=3.24.0

## 文件索引

### 入口
| 文件 | 职责 |
|------|------|
| `lib/main.dart` | 应用入口, MultiProvider(7个服务), MaterialApp, 主导航(4页), 节点列表(排序/筛选/分组) |

### 模型层 (models/)
| 文件 | 核心类 | 说明 |
|------|--------|------|
| `config.dart` | KernelType, KernelStatus, ProxyProtocol, NodeConfig, ProxyConfig, RoutingRule, DnsConfig, DnsMode | 全局配置模型 |
| `kernel_info.dart` | KernelInfo, KernelReleaseInfo, KernelAssetInfo | 内核信息模型 |
| `singbox_config.dart` | SingboxConfig, SingboxInbound, SingboxOutbound, SingboxRoute, SingboxRouteRule | sing-box JSON 配置 |

### 服务层 (services/)
| 文件 | 核心类 | 模式 | 说明 |
|------|--------|------|------|
| `proxy_service.dart` | ProxyService, ProxyState | ChangeNotifier | 中央状态管理, 代理启停(Process.start), 崩溃自启, 节点/规则/流量 |
| `kernel_manager.dart` | KernelManager | ChangeNotifier | 内核下载/安装/版本检测/GitHub API |
| `clash_api_service.dart` | ClashApiService | ChangeNotifier | WebSocket 流量/日志/节点, RESTful API |
| `config_storage_service.dart` | ConfigStorageService, SubscriptionInfo | — | SharedPreferences 持久化, 导入导出 |
| `subscription_service.dart` | SubscriptionService | ChangeNotifier | 订阅 CRUD/刷新/解析 (调用 AppUtils) |
| `smart_router.dart` | SmartRouter, NodeScore | ChangeNotifier | 智能节点评分/自动选路 |
| `system_proxy_service.dart` | SystemProxyService | 静态工具类 | Windows 注册表/macOS networksetup |
| `admin_service.dart` | AdminService | 静态工具类 | 管理员权限检测/UAC提权 |
| `geo_data_service.dart` | GeoDataService | ChangeNotifier | GeoSite/GeoIP 下载管理 |
| `tray_service.dart` | TrayService | TrayListener | 系统托盘图标/菜单 |
| `webdav_sync_service.dart` | WebDavSyncService | ChangeNotifier | WebDAV 云端备份/恢复 |

### 工具层 (utils/)
| 文件 | 核心方法 | 说明 |
|------|----------|------|
| `app_utils.dart` | formatBytes, formatDuration, latencyLabel, detectProtocol, parseProxyLink, getArchName | 通用工具 + 统一链接解析 |
| `config_adapter.dart` | toSingboxConfig, toMihomoConfig, toV2rayConfig | 多内核配置适配 |

### UI 层 (screens/)
| 文件 | 页面 | 说明 |
|------|------|------|
| `home_screen.dart` | HomeScreen | 仪表板: 状态/网速/概要/快捷设置/内核安装 |
| `kernel_settings_screen.dart` | KernelSettingsScreen | 内核管理: 版本/下载/安装 |
| `log_screen.dart` | LogScreen | 日志查看: 级别过滤/实时流 |
| `node_editor_screen.dart` | NodeEditorScreen | 节点编辑: 9种协议表单 |
| `routing_editor_screen.dart` | RoutingEditorScreen | 路由编辑: 9种匹配/14预设/拖拽 |
| `settings_screen.dart` | SettingsScreen | 设置: 内核/网络/规则/DNS/端口/数据/外观 |
| `subscriptions_screen.dart` | SubscriptionsScreen | 订阅管理: CRUD/刷新/概要 |

### 组件层 (widgets/)
| 文件 | 组件 | 说明 |
|------|------|------|
| `glass_theme.dart` | GlassTheme, GlassCard, GlassButton, GlassSwitch | 毛玻璃主题 |
| `proxy_link_importer.dart` | ProxyLinkImporter | 链接导入弹窗 (调用 AppUtils) |

## 关键依赖关系

```
ProxyService (中央状态)
├── KernelManager (内核管理)
├── ConfigStorageService (持久化)
├── ClashApiService (WebSocket通信)
├── SmartRouter (智能选路)
├── SystemProxyService (系统代理)
├── ConfigAdapter (配置适配)
└── AppUtils (链接解析)

UI层 → context.watch/read<ProxyService>()
UI层 → context.watch/read<KernelManager>()
UI层 → context.watch/read<SubscriptionService>()
```

## 协议支持矩阵

| 协议 | sing-box | mihomo | v2ray | 链接解析 |
|------|----------|--------|-------|----------|
| VMess | ✅ | ✅ | ✅ | vmess:// |
| VLESS | ✅ | ✅ | ❌ | vless:// |
| Trojan | ✅ | ✅ | ✅ | trojan:// |
| Shadowsocks | ✅ | ✅ | ✅ | ss:// |
| Hysteria | ✅ | ✅ | ❌ | hysteria:// |
| Hysteria2 | ✅ | ✅ | ❌ | hysteria2:// / hy2:// |
| TUIC | ✅ | ✅ | ❌ | tuic:// |
| Naive | ✅ | ❌ | ❌ | — |
| WireGuard | ✅ | ❌ | ❌ | — |

## 优化记录

### 第一轮 (2026-05-06)
| 优化项 | 文件 | 说明 |
|--------|------|------|
| 修复冗余条件 | `app_utils.dart` | latencyLabel() 5个相同分支→2个 |
| 修复硬编码 | `app_utils.dart` | getArchName() 硬编码amd64→多级检测 |
| 修复资源泄漏 | `kernel_manager.dart` | HttpClient 3处未关闭→finally关闭 |
| 修复异步清理 | `proxy_service.dart` | dispose()异步方法→fire-and-forget+临时目录清理 |
| 修复订阅泄漏 | `clash_api_service.dart` | 日志WebSocket订阅未跟踪→跟踪+disconnect清理 |
| 消除重复代码 | `app_utils.dart` + `subscription_service.dart` + `proxy_link_importer.dart` | 链接解析3处重复→统一到AppUtils |
| 补充注释 | 全部核心文件 | 中文文档注释覆盖所有类/方法/字段 |
| 更新文档 | `README.md` | 项目结构/服务列表/开发指南同步更新 |
| 新增测试 | `widget_test.dart` | latencyLabel/detectProtocol/parseProxyLink 测试 |

### 第二轮 (2026-05-06)
| 优化项 | 文件 | 说明 |
|--------|------|------|
| 更新 AGENTS.md | `AGENTS.md` | 删除11个不存在文件引用, 新增9个实际文件, 修正架构描述 |
| 更新 CODE_WIKI.md | `CODE_WIKI.md` | 完全重写, 反映实际项目结构 |
| 修复绕过列表 | `system_proxy_service.dart` | ProxyOverride 添加 `<local>` 简化 |
| 修复密码安全 | `webdav_sync_service.dart` | toJson()密码Base64编码, loadFromJson()兼容旧版明文 |
| 修复竞态条件 | `config_storage_service.dart` | initSync()添加错误处理和使用说明 |

### 第三轮 (2026-05-06)
| 优化项 | 文件 | 说明 |
|--------|------|------|
| 消除重复代码 | `kernel_manager.dart` | _getCurrentArch/_getCurrentPlatform 委托给 AppUtils |
| 新增方法 | `app_utils.dart` | 添加 getPlatformName() 统一平台检测 |
| 修复资源泄漏 | `proxy_service.dart` | testDownloadSpeed HttpClient 未在 finally 关闭 |
| 修复竞态条件 | `proxy_service.dart` | start() exitCode.timeout onTimeout:()=>-1 不正确→try/catch TimeoutException |
| 补充协议支持 | `config_adapter.dart` | mihomo 添加 Hysteria/TUIC 协议映射，不再降级为 socks5 |
| 修复临时文件 | `kernel_manager.dart` | downloadKernel 下载失败后清理 _download 临时文件 |

### 第四轮 (2026-05-06) — 链路功能完善
| 优化项 | 文件 | 说明 |
|--------|------|------|
| 订阅解析增强 | `subscription_service.dart` | 支持 Base64 整体编码 + Clash YAML 格式订阅 |
| VLESS 链接解析 | `app_utils.dart` | 补充 Reality(pbk/sid)/TLS/WS/gRPC 字段 |
| VMess 链接解析 | `app_utils.dart` | 补充 TLS/sni/alpn/fingerprint 字段 |
| Trojan 链接解析 | `app_utils.dart` | 补充 TLS/alpn/fingerprint/WS/gRPC 字段 |
| SS 链接解析 | `app_utils.dart` | 支持 SIP002 格式 + SS2022 兼容 |
| sing-box VMess | `config_adapter.dart` | 补充 TLS/WS/gRPC/HTTP 传输层配置 |
| sing-box VLESS | `config_adapter.dart` | 修复 Reality 字段名 + 补充 WS/gRPC 传输层 |
| sing-box Trojan | `config_adapter.dart` | 补充 TLS alpn/fingerprint + WS/gRPC 传输层 |
| mihomo VMess | `config_adapter.dart` | 补充 TLS + ws-opts/grpc-opts 传输层 |
| mihomo VLESS | `config_adapter.dart` | 补充 Reality-opts + TLS + ws-opts/grpc-opts |
| mihomo Trojan | `config_adapter.dart` | 补充 ws-opts/grpc-opts 传输层 |
| v2ray VMess | `config_adapter.dart` | 补充 streamSettings TLS/WS/gRPC |
| v2ray VLESS | `config_adapter.dart` | 补充 Reality/TLS/WS/gRPC streamSettings |
| v2ray Trojan | `config_adapter.dart` | 补充 streamSettings TLS/WS/gRPC |
