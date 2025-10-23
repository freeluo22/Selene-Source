import 'package:flutter/material.dart';
import 'package:awesome_video_player/awesome_video_player.dart';
import '../models/live_channel.dart';

/// 直播预览播放器组件
/// 在卡片上显示低分辨率的直播画面
class LivePreviewPlayer extends StatefulWidget {
  final LiveChannel channel;
  final Widget Function(BuildContext context) defaultBuilder;

  const LivePreviewPlayer({
    super.key,
    required this.channel,
    required this.defaultBuilder,
  });

  @override
  State<LivePreviewPlayer> createState() => _LivePreviewPlayerState();
}

class _LivePreviewPlayerState extends State<LivePreviewPlayer> {
  AwesomeVideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    if (widget.channel.uris.isEmpty) {
      setState(() {
        _hasError = true;
      });
      return;
    }

    try {
      final videoUrl = widget.channel.uris[0];
      
      // 创建数据源
      final dataSource = BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        videoUrl,
        bufferingConfiguration: const BetterPlayerBufferingConfiguration(
          minBufferMs: 1000,
          maxBufferMs: 3000,
          bufferForPlaybackMs: 500,
          bufferForPlaybackAfterRebufferMs: 1000,
        ),
        headers: widget.channel.headers,
      );

      // 创建配置
      final configuration = BetterPlayerConfiguration(
        autoPlay: true,
        looping: true,
        controlsConfiguration: const BetterPlayerControlsConfiguration(
          showControls: false, // 隐藏控制栏
          enableMute: true,
          enableFullscreen: false,
          enablePip: false,
          enablePlayPause: false,
          enableProgressBar: false,
          enableSkips: false,
          enableSubtitles: false,
        ),
        aspectRatio: 16 / 9,
        fit: BoxFit.cover,
        autoDetectFullscreenAspectRatio: false,
        autoDetectFullscreenDeviceOrientation: false,
        allowedScreenSleep: true,
        placeholder: widget.defaultBuilder(context),
        showPlaceholderUntilPlay: true,
        errorBuilder: (context, errorMessage) {
          return widget.defaultBuilder(context);
        },
      );

      _controller = AwesomeVideoPlayerController(
        dataSource: dataSource,
        configuration: configuration,
      );

      // 监听初始化状态
      _controller!.addListener(() {
        if (_controller!.isVideoInitialized() && !_isInitialized) {
          if (mounted) {
            setState(() {
              _isInitialized = true;
            });
          }
        }
      });

      // 静音播放
      await _controller!.setVolume(0);
    } catch (e) {
      print('初始化预览播放器失败: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 如果有错误或没有控制器，显示默认内容
    if (_hasError || _controller == null) {
      return widget.defaultBuilder(context);
    }

    return Stack(
      children: [
        // 播放器
        Positioned.fill(
          child: AwesomeVideoPlayer(
            controller: _controller!,
            aspectRatio: 16 / 9,
            placeholder: widget.defaultBuilder(context),
          ),
        ),
        // 如果还没初始化，显示加载指示器
        if (!_isInitialized)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
