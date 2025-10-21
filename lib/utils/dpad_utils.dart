import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// D-pad 方向枚举
enum DpadDirection {
  up,
  down,
  left,
  right,
}

/// D-pad 按键类型枚举
enum DpadKey {
  up,
  down,
  left,
  right,
  center, // 确定键
  back, // 返回键
  menu, // 菜单键
}

/// D-pad 按键工具类
///
/// 用于处理 Android TV 遥控器的 D-pad 按键和键盘方向键
/// Android TV 键码：
/// - KEYCODE_DPAD_UP: 19
/// - KEYCODE_DPAD_DOWN: 20
/// - KEYCODE_DPAD_LEFT: 21
/// - KEYCODE_DPAD_RIGHT: 22
/// - KEYCODE_DPAD_CENTER: 23
/// - KEYCODE_BACK: 4
/// - KEYCODE_MENU: 82
class DpadUtils {
  // Android TV 键码常量
  static const int _keycodeUp = 19;
  static const int _keycodeDown = 20;
  static const int _keycodeLeft = 21;
  static const int _keycodeRight = 22;
  static const int _keycodeCenter = 23;
  static const int _keycodeBack = 4;
  static const int _keycodeMenu = 82;

  /// 判断是否是 D-pad 上键或键盘上方向键
  static bool isUpKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.arrowUp || key.keyId == _keycodeUp;
  }

  /// 判断是否是 D-pad 下键或键盘下方向键
  static bool isDownKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.arrowDown || key.keyId == _keycodeDown;
  }

  /// 判断是否是 D-pad 左键或键盘左方向键
  static bool isLeftKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.arrowLeft || key.keyId == _keycodeLeft;
  }

  /// 判断是否是 D-pad 右键或键盘右方向键
  static bool isRightKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.arrowRight || key.keyId == _keycodeRight;
  }

  /// 判断是否是确定键（D-pad 中心键或回车键）
  static bool isCenterKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key.keyId == _keycodeCenter;
  }

  /// 判断是否是返回键
  static bool isBackKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.escape || key.keyId == _keycodeBack;
  }

  /// 判断是否是菜单键（键码 82）
  static bool isMenuKey(KeyEvent event) {
    return event.logicalKey.keyId == _keycodeMenu;
  }

  /// 判断是否是方向键（上下左右）
  static bool isDirectionKey(LogicalKeyboardKey key) {
    return isUpKey(key) || isDownKey(key) || isLeftKey(key) || isRightKey(key);
  }

  /// 获取按键对应的方向
  ///
  /// 如果不是方向键，返回 null
  static DpadDirection? getDirection(LogicalKeyboardKey key) {
    if (isUpKey(key)) return DpadDirection.up;
    if (isDownKey(key)) return DpadDirection.down;
    if (isLeftKey(key)) return DpadDirection.left;
    if (isRightKey(key)) return DpadDirection.right;
    return null;
  }

  /// 获取按键类型
  ///
  /// 如果不是支持的按键，返回 null
  static DpadKey? getKeyType(LogicalKeyboardKey key, KeyEvent? event) {
    if (isUpKey(key)) return DpadKey.up;
    if (isDownKey(key)) return DpadKey.down;
    if (isLeftKey(key)) return DpadKey.left;
    if (isRightKey(key)) return DpadKey.right;
    if (isCenterKey(key)) return DpadKey.center;
    if (isBackKey(key)) return DpadKey.back;
    if (event != null && isMenuKey(event)) return DpadKey.menu;
    return null;
  }

  /// 创建一个 KeyEventHandler，用于处理 D-pad 按键事件
  ///
  /// 参数：
  /// - onUp: 上键回调
  /// - onDown: 下键回调
  /// - onLeft: 左键回调
  /// - onRight: 右键回调
  /// - onCenter: 确定键回调
  /// - onBack: 返回键回调
  /// - onMenu: 菜单键回调
  ///
  /// 返回值：
  /// - KeyEventResult.handled: 事件已处理
  /// - KeyEventResult.ignored: 事件未处理
  static KeyEventResult handleKeyEvent(
    KeyEvent event, {
    VoidCallback? onUp,
    VoidCallback? onDown,
    VoidCallback? onLeft,
    VoidCallback? onRight,
    VoidCallback? onCenter,
    VoidCallback? onBack,
    VoidCallback? onMenu,
  }) {
    // 只处理按键按下事件
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    if (isUpKey(key) && onUp != null) {
      onUp();
      return KeyEventResult.handled;
    }

    if (isDownKey(key) && onDown != null) {
      onDown();
      return KeyEventResult.handled;
    }

    if (isLeftKey(key) && onLeft != null) {
      onLeft();
      return KeyEventResult.handled;
    }

    if (isRightKey(key) && onRight != null) {
      onRight();
      return KeyEventResult.handled;
    }

    if (isCenterKey(key) && onCenter != null) {
      onCenter();
      return KeyEventResult.handled;
    }

    if (isBackKey(key) && onBack != null) {
      onBack();
      return KeyEventResult.handled;
    }

    if (isMenuKey(event) && onMenu != null) {
      onMenu();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }
}
