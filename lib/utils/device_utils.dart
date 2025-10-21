import 'package:flutter/material.dart';

/// 设备类型工具类
class DeviceUtils {
  // 平板的最小宽度阈值（dp）
  static const double tabletMinWidth = 600.0;

  /// 判断当前设备是否是平板
  ///
  /// 通过屏幕宽度判断，宽度 >= 600dp 视为平板
  /// TV 版：永远返回 true
  static bool isTablet(BuildContext context) {
    // TV 版强制返回 true
    return true;
  }

  /// 判断当前设备是否是平板竖屏
  ///
  /// 逻辑：isTablet 且宽高比小于等于 1.2
  /// TV 版：永远返回 false
  static bool isPortraitTablet(BuildContext context) {
    // TV 版强制返回 false
    return false;
  }

  /// 判断当前平台是否是 Windows
  /// TV 版：永远返回 false
  static bool isWindows() {
    return false;
  }

  /// 判断当前平台是否是 macOS
  /// TV 版：永远返回 false
  static bool isMacOS() {
    return false;
  }

  /// 判断当前平台是否是 PC（Windows 或 macOS）
  /// TV 版：永远返回 false
  static bool isPC() {
    return false;
  }

  /// 根据屏幕宽度动态计算平板模式下的列数（6～8列）
  ///
  /// 宽度范围：
  /// - < 1000: 6列
  /// - 1000-1200: 7列
  /// - >= 1200: 8列
  /// TV 版：永远返回 8
  static int getTabletColumnCount(BuildContext context) {
    // TV 版强制返回 8
    return 8;
  }

  /// 根据屏幕宽度动态计算横向滚动列表的可见卡片数（5.75、6.75、7.75）
  ///
  /// 用于 continue_watching_section 和 recommendation_section
  /// 宽度范围：
  /// - < 1000: 5.75列
  /// - 1000-1200: 6.75列
  /// - >= 1200: 7.75列
  /// TV 版：永远返回 7.75
  static double getHorizontalVisibleCards(
      BuildContext context, double mobileCardCount) {
    // TV 版强制返回 7.75
    return 7.75;
  }
}
