import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/video_player_widget.dart';
import '../services/api_service.dart';
import '../services/m3u8_service.dart';
import '../models/search_result.dart';
import '../services/page_cache_service.dart';

class PlayerScreen extends StatefulWidget {
  final String? source;
  final String? id;
  final String title;
  final String? year;
  final String? stitle;
  final String? stype;
  final String? prefer;

  const PlayerScreen({
    super.key,
    this.source,
    this.id,
    required this.title,
    this.year,
    this.stitle,
    this.stype,
    this.prefer,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class SourceSpeed {
  String quality = '';
  String loadSpeed = '';
  String pingTime = '';

  SourceSpeed({
    required this.quality,
    required this.loadSpeed,
    required this.pingTime,
  });
}

class _PlayerScreenState extends State<PlayerScreen> {
  late SystemUiOverlayStyle _originalStyle;
  bool _isInitialized = false;
  bool _isFullscreen = false;
  String? _errorMessage;
  bool _showError = false;

  // 播放信息
  SearchResult? currentDetail;
  String videoTitle = '';
  String videoYear = '';
  String videoCover = '';
  int videoDoubanID = 0;
  String currentSource = '';
  String currentID = '';
  bool needPrefer = false;
  int totalEpisodes = 0;
  int currentEpisodeIndex = 0;

  // 待恢复的进度
  double resumeTime = 0;
  
  // 所有源信息
  List<SearchResult> allSources = [];
  // 所有源测速结果
  Map<String, SourceSpeed> allSourcesSpeed = {};

  // 当前视频 URL
  String _currentVideoUrl = '';
  
  // VideoPlayerWidget 的控制器
  VideoPlayerWidgetController? _videoPlayerController;

  @override
  void initState() {
    super.initState();
    initVideoData();
  }

  void initParam() {
    currentSource = widget.source ?? '';
    currentID = widget.id ?? '';
    videoTitle = widget.title;
    videoYear = widget.year ?? '';
    needPrefer = widget.prefer != null && widget.prefer == 'true';

    print('=== PlayerScreen 初始化参数 ===');
    print('currentSource: $currentSource');
    print('currentID: $currentID');
    print('videoTitle: $videoTitle');
    print('videoYear: $videoYear');
    print('needPrefer: $needPrefer');
    print('stitle: ${widget.stitle}');
    print('stype: ${widget.stype}');
    print('prefer: ${widget.prefer}');
  }

  void initVideoData() async {
    if (widget.source == null && widget.id == null && widget.title.isEmpty && widget.stitle == null) {
      showError('缺少必要参数');
      return;
    }

    // 初始化参数
    initParam();
    
    // 执行查询
    allSources = await fetchSourcesData((widget.stitle != null && widget.stitle!.isNotEmpty) 
        ? widget.stitle! 
        : videoTitle);
    if (currentSource.isNotEmpty && currentID.isNotEmpty && !allSources.any((source) => source.source == currentSource && source.id == currentID)) {
      allSources = await fetchSourceDetail(currentSource, currentID);
    }
    if (allSources.isEmpty) {
      showError('未找到匹配的结果');
      return;
    }
    
    // 指定源和id且无需优选
    currentDetail = allSources.first;
    if (currentSource.isNotEmpty && currentID.isNotEmpty && !needPrefer) {
     final target = allSources.where((source) => source.source == currentSource && source.id == currentID);
     currentDetail = target.isNotEmpty ? target.first : null;
    }
    if (currentDetail == null) {
      showError('未找到匹配结果');
      return;
    }

    // 未指定源和 id/需要优选，执行优选
    if (currentSource.isEmpty || currentID.isEmpty || needPrefer) {
      currentDetail = await preferBestSource();
    }
    setInfosByDetail(currentDetail!);

    // 获取播放记录
    int playEpisodeIndex = 0;
    int playTime = 0;
    final allPlayRecords = await PageCacheService().getPlayRecords(context);
    // 查找是否有当前视频的播放记录
    if (allPlayRecords.success && allPlayRecords.data != null) {
      final matchingRecords = allPlayRecords.data!.where((record) => record.id == currentID && record.source == currentSource);
      if (matchingRecords.isNotEmpty) {
        playEpisodeIndex = matchingRecords.first.index - 1;
        playTime = matchingRecords.first.playTime;
      }
    }

    // 设置播放
    startPlay(playEpisodeIndex, playTime);
  }

  void startPlay(int targetIndex, int playTime) {
    if (targetIndex >= currentDetail!.episodes.length) {
      targetIndex = 0;
      resumeTime = 0;
      return;
    }
    currentEpisodeIndex = targetIndex;
    resumeTime = playTime.toDouble();
    updateVideoUrl(currentDetail!.episodes[targetIndex]);
  }

  void setInfosByDetail(SearchResult detail) {
    videoTitle = detail.title;
    videoYear = detail.year;
    videoCover = detail.poster;
    currentSource = detail.source;
    currentID = detail.id;
    totalEpisodes = detail.episodes.length;

    // 设置当前豆瓣 ID
    if (detail.doubanId != null && detail.doubanId! > 0) {
      // 如果当前 searchResult 有有效的 doubanID，直接使用
      videoDoubanID = detail.doubanId!;
    } else {
      // 否则统计出现次数最多的 doubanID
      Map<int, int> doubanIDCount = {};
      for (var result in allSources) {
        int? tmpDoubanID = result.doubanId;
        if (tmpDoubanID == null || tmpDoubanID == 0) {
          continue;
        }
        doubanIDCount[tmpDoubanID] = (doubanIDCount[tmpDoubanID] ?? 0) + 1;
      }
      videoDoubanID = doubanIDCount.entries.isEmpty 
          ? 0 
          : doubanIDCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    }
  }

  Future<SearchResult> preferBestSource() async {
    final m3u8Service = M3U8Service();
    final result = await m3u8Service.preferBestSource(allSources);
    
    // 更新测速结果
    final speedResults = result['allSourcesSpeed'] as Map<String, dynamic>;
    for (final entry in speedResults.entries) {
      final speedData = entry.value as Map<String, dynamic>;
      allSourcesSpeed[entry.key] = SourceSpeed(
        quality: speedData['quality'] as String,
        loadSpeed: speedData['loadSpeed'] as String,
        pingTime: speedData['pingTime'] as String,
      );
    }
    
    return result['bestSource'] as SearchResult;
  }

  // 处理全屏状态变化（简化版本，只用于UI状态更新）
  void _handleFullscreenChange(bool isFullscreen) {
    if (_isFullscreen != isFullscreen) {
      setState(() {
        _isFullscreen = isFullscreen;
      });
    }
  }

  // 处理返回按钮点击
  void _onBackPressed() {
    Navigator.of(context).pop();
  }

  /// 显示错误信息
  void showError(String message) {
    setState(() {
      _errorMessage = message;
      _showError = true;
    });
  }

  /// 隐藏错误信息
  void hideError() {
    setState(() {
      _showError = false;
      _errorMessage = null;
    });
  }

  /// 动态更新视频 URL
  Future<void> updateVideoUrl(String newUrl) async {
    try {
      await _videoPlayerController?.updateVideoUrl(newUrl);
      setState(() {
        _currentVideoUrl = newUrl;
      });
    } catch (e) {
      showError('更新视频失败: $e');
    }
  }

  /// 跳转到指定进度
  Future<void> seekToProgress(Duration position) async {
    try {
      await _videoPlayerController?.seekTo(position);
    } catch (e) {
      showError('跳转进度失败: $e');
    }
  }

  /// 跳转到指定秒数
  Future<void> seekToSeconds(double seconds) async {
    await seekToProgress(Duration(seconds: seconds.round()));
  }

  /// 获取当前播放位置
  Duration? get currentPosition {
    return _videoPlayerController?.currentPosition;
  }

  /// 获取视频总时长
  Duration? get duration {
    return _videoPlayerController?.duration;
  }

  /// 获取播放状态
  bool get isPlaying {
    return _videoPlayerController?.isPlaying ?? false;
  }

  /// 处理视频播放器 ready 事件
  void _onVideoPlayerReady() {
    // 视频播放器准备就绪时的处理逻辑
    debugPrint('Video player is ready!');
    
    // 如果有需要恢复的播放进度，则跳转到指定位置
    if (resumeTime > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        seekToSeconds(resumeTime);
        resumeTime = 0;
      });
    }
  }

  /// 构建错误覆盖层
  Widget _buildErrorOverlay(ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: isDarkMode 
          ? const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black, Colors.grey],
            )
          : const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFe6f3fb), // 与首页保持一致
                Color(0xFFeaf3f7),
                Color(0xFFf7f7f3),
                Color(0xFFe9ecef),
                Color(0xFFdbe3ea),
                Color(0xFFd3dde6),
              ],
              stops: [0.0, 0.18, 0.38, 0.60, 0.80, 1.0],
            ),
      ),
      child: Stack(
        children: [
          // 装饰性圆点
          Positioned(
            top: 100,
            left: 40,
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 140,
            left: 60,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 120,
            right: 50,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.amber,
                shape: BoxShape.circle,
              ),
            ),
          ),
          
          // 主要内容
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 错误图标
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFF8C42), Color(0xFFE74C3C)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      '😵',
                      style: TextStyle(fontSize: 60),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // 错误标题
                Text(
                  '哎呀, 出现了一些问题',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                
                // 错误信息框
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B4513).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF8B4513).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFFE74C3C),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                
                // 提示文字
                Text(
                  '请检查网络连接或尝试刷新页面',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                
                // 按钮组
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      // 返回按钮
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            hideError();
                            _onBackPressed();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                          ),
                          child: const Text(
                            '返回上页',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // 重试按钮
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: hideError,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDarkMode ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0),
                            foregroundColor: isDarkMode ? Colors.white : const Color(0xFF3182CE),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                          ),
                          child: Text(
                            '重新尝试',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isDarkMode ? Colors.white : const Color(0xFF3182CE),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  /// 获取视频详情
  Future<List<SearchResult>> fetchSourceDetail(String source, String id) async {
    return await ApiService.fetchSourceDetail(source, id);
  }

  /// 搜索视频源数据（带过滤）
  Future<List<SearchResult>> fetchSourcesData(String query) async {
    final results = await ApiService.fetchSourcesData(query);
    
    // 直接在这里展开过滤逻辑
    return results.where((result) {
      // 标题匹配检查
      final titleMatch = result.title.replaceAll(' ', '').toLowerCase() == 
          (widget.title.replaceAll(' ', '').toLowerCase());
      
      // 年份匹配检查
      final yearMatch = widget.year == null || 
          result.year.toLowerCase() == widget.year!.toLowerCase();
      
      // 类型匹配检查
      bool typeMatch = true;
      if (widget.stype != null) {
        if (widget.stype == 'tv') {
          typeMatch = result.episodes.length > 1;
        } else if (widget.stype == 'movie') {
          typeMatch = result.episodes.length == 1;
        }
      }
      
      return titleMatch && yearMatch && typeMatch;
    }).toList();
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      // 保存当前的系统UI样式
      final theme = Theme.of(context);
      final isDarkMode = theme.brightness == Brightness.dark;
      _originalStyle = SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: theme.scaffoldBackgroundColor,
        systemNavigationBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
      );
      _isInitialized = true;
    }
  }


  @override
  void dispose() {
    // 恢复原始的系统UI样式
    SystemChrome.setSystemUIOverlayStyle(_originalStyle);
    // 销毁播放器
    _videoPlayerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: isDarkMode ? Colors.black : theme.scaffoldBackgroundColor,
        systemNavigationBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        // 其余代码保持不变
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Stack(
          children: [
            // 主要内容
            Column(
              children: [
                Container(
                  height: MediaQuery.maybeOf(context)?.padding.top ?? 0,
                  color: Colors.black,
                ),
                VideoPlayerWidget(
                  videoUrl: _currentVideoUrl,
                  aspectRatio: 16 / 9,
                  onBackPressed: _onBackPressed,
                  onFullscreenChange: _handleFullscreenChange,
                  onControllerCreated: (controller) {
                    _videoPlayerController = controller;
                  },
                  onReady: _onVideoPlayerReady,
                ),
                Expanded(
                  child: Container(
                    color: theme.scaffoldBackgroundColor,
                    child: Center(
                      child: Text(
                        '${widget.title} (${widget.year})',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // 错误覆盖层
            if (_showError && _errorMessage != null)
              _buildErrorOverlay(theme),
          ],
        ),
      ),
    );
  }
}

