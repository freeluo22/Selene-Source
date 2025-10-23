import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/live_channel.dart';
import '../services/live_channel_service.dart';
import '../widgets/mobile_video_player_widget.dart';
import '../widgets/pc_video_player_widget.dart';
import '../utils/device_utils.dart';
import '../utils/font_utils.dart';
import '../services/theme_service.dart';
import 'package:provider/provider.dart';
import '../widgets/windows_title_bar.dart';

class LivePlayerScreen extends StatefulWidget {
  final LiveChannel channel;

  const LivePlayerScreen({
    super.key,
    required this.channel,
  });

  @override
  State<LivePlayerScreen> createState() => _LivePlayerScreenState();
}

class _LivePlayerScreenState extends State<LivePlayerScreen> {
  late SystemUiOverlayStyle _originalStyle;
  late LiveChannel _currentChannel;
  int _currentSourceIndex = 0;
  bool _showChannelList = false;
  bool _showSourceList = false;
  List<LiveChannel> _allChannels = [];
  
  // 播放器控制器
  MobileVideoPlayerWidgetController? _mobileVideoPlayerController;
  PcVideoPlayerWidgetController? _pcVideoPlayerController;

  @override
  void initState() {
    super.initState();
    _currentChannel = widget.channel;
    _currentSourceIndex = widget.channel.videoIndex;
    _loadAllChannels();
    
    // 保存原始状态栏样式
    _originalStyle = SystemChrome.latestStyle ?? SystemUiOverlayStyle.light;
    
    // 设置全屏模式
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    // 恢复状态栏
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setSystemUIOverlayStyle(_originalStyle);
    
    super.dispose();
  }

  Future<void> _loadAllChannels() async {
    final channels = await LiveChannelService.getChannels();
    if (mounted) {
      setState(() {
        _allChannels = channels;
      });
    }
  }

  void _switchChannel(LiveChannel channel) {
    setState(() {
      _currentChannel = channel;
      _currentSourceIndex = 0;
      _showChannelList = false;
    });
    
    // 重新加载播放器
    _reloadPlayer();
  }

  void _switchSource(int index) {
    setState(() {
      _currentSourceIndex = index;
      _showSourceList = false;
    });
    
    // 重新加载播放器
    _reloadPlayer();
  }

  void _reloadPlayer() {
    // 通过改变 key 来重新创建播放器
    setState(() {});
  }

  void _toggleFavorite() async {
    await LiveChannelService.toggleFavorite(_currentChannel.id);
    
    // 重新加载频道列表以更新收藏状态
    await _loadAllChannels();
    
    // 更新当前频道的收藏状态
    final updatedChannel = _allChannels.firstWhere(
      (c) => c.id == _currentChannel.id,
      orElse: () => _currentChannel,
    );
    
    if (mounted) {
      setState(() {
        _currentChannel = updatedChannel;
      });
    }
  }

  void _previousChannel() {
    final currentIndex = _allChannels.indexWhere((c) => c.id == _currentChannel.id);
    if (currentIndex > 0) {
      _switchChannel(_allChannels[currentIndex - 1]);
    }
  }

  void _nextChannel() {
    final currentIndex = _allChannels.indexWhere((c) => c.id == _currentChannel.id);
    if (currentIndex < _allChannels.length - 1) {
      _switchChannel(_allChannels[currentIndex + 1]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // Windows 自定义标题栏
              if (Platform.isWindows)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: WindowsTitleBar(
                    customBackgroundColor: Colors.black,
                  ),
                ),
              // 播放器
              _buildPlayer(),
              // 频道列表侧边栏
              if (_showChannelList) _buildChannelListDrawer(themeService),
              // 源列表侧边栏
              if (_showSourceList) _buildSourceListDrawer(themeService),
              // 控制栏
              _buildControlBar(themeService),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlayer() {
    final videoUrl = _currentChannel.uris[_currentSourceIndex];
    
    if (DeviceUtils.isPC()) {
      return PcVideoPlayerWidget(
        key: ValueKey('${_currentChannel.id}_$_currentSourceIndex'),
        url: videoUrl,
        videoTitle: _currentChannel.title,
        onBackPressed: () => Navigator.pop(context),
        onControllerCreated: (controller) {
          _pcVideoPlayerController = controller;
        },
      );
    } else {
      return MobileVideoPlayerWidget(
        key: ValueKey('${_currentChannel.id}_$_currentSourceIndex'),
        url: videoUrl,
        videoTitle: _currentChannel.title,
        onBackPressed: () => Navigator.pop(context),
        onControllerCreated: (controller) {
          _mobileVideoPlayerController = controller;
        },
      );
    }
  }

  Widget _buildControlBar(ThemeService themeService) {
    return Positioned(
      top: Platform.isWindows ? 40 : 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          bottom: 8,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            // 频道信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentChannel.title,
                    style: FontUtils.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${_currentChannel.group} · 源 ${_currentSourceIndex + 1}/${_currentChannel.uris.length}',
                    style: FontUtils.poppins(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            // 收藏按钮
            IconButton(
              icon: Icon(
                _currentChannel.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _currentChannel.isFavorite
                    ? const Color(0xFFe74c3c)
                    : Colors.white,
              ),
              onPressed: _toggleFavorite,
            ),
            // 切换源按钮
            if (_currentChannel.uris.length > 1)
              IconButton(
                icon: const Icon(Icons.swap_horiz, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _showSourceList = !_showSourceList;
                    _showChannelList = false;
                  });
                },
              ),
            // 频道列表按钮
            IconButton(
              icon: const Icon(Icons.list, color: Colors.white),
              onPressed: () {
                setState(() {
                  _showChannelList = !_showChannelList;
                  _showSourceList = false;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelListDrawer(ThemeService themeService) {
    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _showChannelList = false;
          });
        },
        child: Container(
          color: Colors.black54,
          child: GestureDetector(
            onTap: () {}, // 阻止点击事件传播
            child: Container(
              width: 300,
              color: themeService.isDarkMode
                  ? const Color(0xFF1e1e1e)
                  : Colors.white,
              child: Column(
                children: [
                  // 标题栏
                  Container(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 16,
                      left: 16,
                      right: 16,
                      bottom: 16,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: themeService.isDarkMode
                              ? const Color(0xFF333333)
                              : const Color(0xFFe0e0e0),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '频道列表',
                          style: FontUtils.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: themeService.isDarkMode
                                ? Colors.white
                                : const Color(0xFF2c3e50),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: themeService.isDarkMode
                                ? Colors.white
                                : const Color(0xFF2c3e50),
                          ),
                          onPressed: () {
                            setState(() {
                              _showChannelList = false;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  // 频道列表
                  Expanded(
                    child: ListView.builder(
                      itemCount: _allChannels.length,
                      itemBuilder: (context, index) {
                        final channel = _allChannels[index];
                        final isSelected = channel.id == _currentChannel.id;
                        
                        return ListTile(
                          selected: isSelected,
                          selectedTileColor: const Color(0xFF27ae60).withOpacity(0.1),
                          leading: channel.logo.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(
                                    channel.logo,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(Icons.tv);
                                    },
                                  ),
                                )
                              : const Icon(Icons.tv),
                          title: Text(
                            channel.title,
                            style: FontUtils.poppins(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected
                                  ? const Color(0xFF27ae60)
                                  : themeService.isDarkMode
                                      ? Colors.white
                                      : const Color(0xFF2c3e50),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            channel.group,
                            style: FontUtils.poppins(
                              fontSize: 12,
                              color: themeService.isDarkMode
                                  ? const Color(0xFF999999)
                                  : const Color(0xFF7f8c8d),
                            ),
                          ),
                          onTap: () => _switchChannel(channel),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSourceListDrawer(ThemeService themeService) {
    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _showSourceList = false;
          });
        },
        child: Container(
          color: Colors.black54,
          child: GestureDetector(
            onTap: () {}, // 阻止点击事件传播
            child: Container(
              width: 300,
              color: themeService.isDarkMode
                  ? const Color(0xFF1e1e1e)
                  : Colors.white,
              child: Column(
                children: [
                  // 标题栏
                  Container(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 16,
                      left: 16,
                      right: 16,
                      bottom: 16,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: themeService.isDarkMode
                              ? const Color(0xFF333333)
                              : const Color(0xFFe0e0e0),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '切换源',
                          style: FontUtils.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: themeService.isDarkMode
                                ? Colors.white
                                : const Color(0xFF2c3e50),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: themeService.isDarkMode
                                ? Colors.white
                                : const Color(0xFF2c3e50),
                          ),
                          onPressed: () {
                            setState(() {
                              _showSourceList = false;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  // 源列表
                  Expanded(
                    child: ListView.builder(
                      itemCount: _currentChannel.uris.length,
                      itemBuilder: (context, index) {
                        final isSelected = index == _currentSourceIndex;
                        
                        return ListTile(
                          selected: isSelected,
                          selectedTileColor: const Color(0xFF27ae60).withOpacity(0.1),
                          leading: Icon(
                            Icons.play_circle_outline,
                            color: isSelected
                                ? const Color(0xFF27ae60)
                                : themeService.isDarkMode
                                    ? const Color(0xFF666666)
                                    : const Color(0xFF95a5a6),
                          ),
                          title: Text(
                            '源 ${index + 1}',
                            style: FontUtils.poppins(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected
                                  ? const Color(0xFF27ae60)
                                  : themeService.isDarkMode
                                      ? Colors.white
                                      : const Color(0xFF2c3e50),
                            ),
                          ),
                          subtitle: Text(
                            _currentChannel.uris[index],
                            style: FontUtils.poppins(
                              fontSize: 10,
                              color: themeService.isDarkMode
                                  ? const Color(0xFF999999)
                                  : const Color(0xFF7f8c8d),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _switchSource(index),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
