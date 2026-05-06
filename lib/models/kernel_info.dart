import 'dart:io';

import 'config.dart';

/// KernelInfo - 内核信息数据模型
///
/// 表示一个代理内核的完整信息，包括类型、版本、下载地址、平台架构等
class KernelInfo {
  /// 内核类型（sing-box / mihomo / v2ray）
  final KernelType type;

  /// 内核版本号
  final String version;

  /// 内核二进制文件在本地的存储路径
  final String binaryPath;

  /// 内核下载 URL
  final String downloadUrl;

  /// 运行平台（windows / darwin / linux / android）
  final String platform;

  /// CPU 架构（amd64 / arm64）
  final String arch;

  /// 文件大小（字节）
  final int fileSize;

  /// SHA256 校验值
  final String sha256;

  /// 内核信息构造函数
  const KernelInfo({
    required this.type,
    this.version = '',
    this.binaryPath = '',
    this.downloadUrl = '',
    this.platform = '',
    this.arch = '',
    this.fileSize = 0,
    this.sha256 = '',
  });

  /// 创建内核信息副本，可选择性覆盖部分字段
  KernelInfo copyWith({
    KernelType? type,
    String? version,
    String? binaryPath,
    String? downloadUrl,
    String? platform,
    String? arch,
    int? fileSize,
    String? sha256,
  }) {
    return KernelInfo(
      type: type ?? this.type,
      version: version ?? this.version,
      binaryPath: binaryPath ?? this.binaryPath,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      platform: platform ?? this.platform,
      arch: arch ?? this.arch,
      fileSize: fileSize ?? this.fileSize,
      sha256: sha256 ?? this.sha256,
    );
  }

  /// 根据内核类型和平台获取二进制文件名
  ///
  /// Windows 平台自动追加 `.exe` 后缀
  String get fileName {
    final ext = platform == 'windows' ? '.exe' : '';
    switch (type) {
      case KernelType.singbox:
        return 'sing-box$ext';
      case KernelType.mihomo:
        return 'mihomo$ext';
      case KernelType.v2ray:
        return 'xray$ext';
    }
  }

  /// 获取内核的显示名称
  String get displayName {
    switch (type) {
      case KernelType.singbox:
        return 'sing-box';
      case KernelType.mihomo:
        return 'Mihomo (Clash Meta)';
      case KernelType.v2ray:
        return 'Xray (v2ray)';
    }
  }

  /// 检测当前运行平台
  ///
  /// 返回平台标识字符串：windows / darwin / linux / android / unknown
  static String getPlatform() {
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'darwin';
    if (Platform.isLinux) return 'linux';
    if (Platform.isAndroid) return 'android';
    return 'unknown';
  }

  /// 检测当前 CPU 架构
  ///
  /// 返回架构标识字符串：arm64 / amd64
  /// 优先检测 ARM64，Windows 额外检查 PROCESSOR_ARCHITECTURE 环境变量
  static String getArch() {
    final version = Platform.version.toLowerCase();
    if (version.contains('arm64') || version.contains('aarch64')) return 'arm64';
    if (Platform.isWindows) {
      final procArch =
          Platform.environment['PROCESSOR_ARCHITECTURE']?.toUpperCase() ?? '';
      if (procArch.contains('ARM64')) return 'arm64';
    }
    return 'amd64';
  }

  /// 根据内核类型、版本、平台和架构构建 GitHub 下载 URL
  ///
  /// [type] 内核类型
  /// [version] 版本号
  /// [platform] 平台标识
  /// [arch] 架构标识
  /// 返回对应内核的 GitHub Release 下载链接
  static String buildDownloadUrl(KernelType type, String version, String platform, String arch) {
    switch (type) {
      case KernelType.singbox:
        final archName = platform == 'windows' && arch == 'amd64' ? 'amd64' : arch;
        return 'https://github.com/SagerNet/sing-box/releases/download/v$version/'
            'sing-box-$version-$platform-$archName.zip';
      case KernelType.mihomo:
        final archName = arch == 'amd64' ? 'amd64' : (arch == 'arm64' ? 'arm64' : 'amd64');
        return 'https://github.com/MetaCubeX/mihomo/releases/download/v$version/'
            'mihomo-$platform-$archName-v$version.gz';
      case KernelType.v2ray:
        final archName = platform == 'windows' && arch == 'amd64' ? '64' : arch;
        return 'https://github.com/XTLS/Xray-core/releases/download/v$version/'
            'Xray-$platform-$archName.zip';
    }
  }
}

/// KernelReleaseInfo - 内核发布版本信息
///
/// 表示 GitHub Release 上的一个内核版本发布信息
class KernelReleaseInfo {
  /// Git 标签名（如 v1.8.0）
  final String tagName;

  /// 发布名称
  final String name;

  /// 发布时间（ISO 8601 格式）
  final String publishedAt;

  /// GitHub Release 页面 URL
  final String htmlUrl;

  /// 该版本包含的资源文件列表
  final List<KernelAssetInfo> assets;

  /// 内核发布版本信息构造函数
  const KernelReleaseInfo({
    required this.tagName,
    required this.name,
    required this.publishedAt,
    required this.htmlUrl,
    this.assets = const [],
  });

  /// 从标签名提取版本号（去除前缀 'v'）
  String get version => tagName.replaceFirst('v', '');
}

/// KernelAssetInfo - 内核资源文件信息
///
/// 表示 GitHub Release 中的一个可下载资源文件
class KernelAssetInfo {
  /// 资源文件名
  final String name;

  /// 资源下载 URL
  final String url;

  /// 文件大小（字节）
  final int size;

  /// 内核资源文件信息构造函数
  const KernelAssetInfo({
    required this.name,
    required this.url,
    required this.size,
  });
}
