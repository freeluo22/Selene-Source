import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/favorite_item.dart';
import '../models/play_record.dart';
import '../models/video_info.dart';
import '../services/page_cache_service.dart';
import '../services/theme_service.dart';
import '../utils/device_utils.dart';
import 'video_card.dart';
import '../utils/image_url.dart';
import '../utils/font_utils.dart';
import 'video_menu_bottom_sheet.dart';
import 'shimmer_effect.dart';

/// 收藏组件
class FavoriteSection extends StatefulWidget {
  final Function(FavoriteItem)? onVideoTap;
  final Function(FavoriteItem, VideoMenuAction)? onGlobalMenuAction;
  final VoidCallback? onViewAll;

  const FavoriteSection({
    super.key,
    this.onVideoTap,
    this.onGlobalMenuAction,
    this.onViewAll,
  });

  @override
  State<FavoriteSection> createState() => _FavoriteSectionState();

  /// 静态方法：从外部移除收藏项
  static void removeFavoriteFromUI(String source, String id) {
    _FavoriteSectionState._currentInstance?.removeFavoriteFromUI(source, id);
  }

  /// 静态方法：刷新收藏列表
  static Future<void> refreshFavorites() async {
    await _FavoriteSectionState._currentInstance?.refreshFavorites();
  }
}

class _FavoriteSectionState extends State<FavoriteSection>
    with TickerProviderStateMixin {
  List<FavoriteItem> _favorites = [];
  List<PlayRecord> _playRecords = []; // 添加播放记录列表
  bool _isLoading = true;
  bool _hasError = false;
  final PageCacheService _cacheService = PageCacheService();

  // 静态变量存储当前实例
  static _FavoriteSectionState? _currentInstance;

  // 滚动控制相关
  final ScrollController _scrollController = ScrollController();
  bool _showLeftScroll = false;
  bool _showRightScroll = false;
  bool _isHovered = false;

  // hover 状态
  bool _isMoreButtonHovered = false;

  @override
  void initState() {
    super.initState();

    // 设置当前实例
    _currentInstance = this;

    // 添加滚动监听
    _scrollController.addListener(_checkScroll);

    // 延迟执行异步操作，确保 initState 完成后再访问 context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadFavorites();
        _checkScroll();
      }
    });
  }

  @override
  void dispose() {
    // 清除当前实例引用
    if (_currentInstance == this) {
      _currentInstance = null;
    }
    _scrollController.removeListener(_checkScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _checkScroll() {
    if (!mounted) return;

    if (!_scrollController.hasClients) {
      // 如果还没有客户端，但有收藏数据，显示右侧按钮
      if (_favorites.isNotEmpty && _favorites.length > 3) {
        setState(() {
          _showLeftScroll = false;
          _showRightScroll = true;
        });
      }
      return;
    }

    final position = _scrollController.position;
    const threshold = 1.0; // 容差值，避免浮点误差

    setState(() {
      _showLeftScroll = position.pixels > threshold;
      _showRightScroll = position.pixels < position.maxScrollExtent - threshold;
    });
  }

  void _scrollLeft() {
    if (!_scrollController.hasClients) return;

    // 根据可见卡片数动态计算滚动距离
    final double visibleCards =
        DeviceUtils.getHorizontalVisibleCards(context, 2.75);
    final double screenWidth = MediaQuery.of(context).size.width;
    const double padding = 32.0;
    const double spacing = 12.0;
    final double availableWidth = screenWidth - padding;
    final double cardWidth =
        (availableWidth - (spacing * (visibleCards - 1))) / visibleCards;
    // 每次滚动约 5 个卡片的距离
    final double scrollDistance = (cardWidth + spacing) * 5;

    _scrollController.animateTo(
      math.max(0, _scrollController.offset - scrollDistance),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _scrollRight() {
    if (!_scrollController.hasClients) return;

    // 根据可见卡片数动态计算滚动距离
    final double visibleCards =
        DeviceUtils.getHorizontalVisibleCards(context, 2.75);
    final double screenWidth = MediaQuery.of(context).size.width;
    const double padding = 32.0;
    const double spacing = 12.0;
    final double availableWidth = screenWidth - padding;
    final double cardWidth =
        (availableWidth - (spacing * (visibleCards - 1))) / visibleCards;
    // 每次滚动约 5 个卡片的距离
    final double scrollDistance = (cardWidth + spacing) * 5;

    _scrollController.animateTo(
      math.min(
        _scrollController.position.maxScrollExtent,
        _scrollController.offset + scrollDistance,
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// 加载收藏列表
  Future<void> _loadFavorites() async {
    if (!mounted) return;

    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _hasError = false;
        });
      }

      // 同时加载收藏列表和播放记录
      final cachedFavoritesRes = await _cacheService.getFavorites(context);
      final cachedRecordsRes = await _cacheService.getPlayRecords(context);

      if (cachedFavoritesRes.success && cachedFavoritesRes.data != null) {
        final cachedFavorites = cachedFavoritesRes.data as List<FavoriteItem>;
        final cachedRecords = (cachedRecordsRes.success && cachedRecordsRes.data != null)
            ? cachedRecordsRes.data as List<PlayRecord>
            : <PlayRecord>[];

        // 有缓存数据，立即显示
        if (mounted) {
          setState(() {
            _favorites = cachedFavorites;
            _playRecords = cachedRecords;
            _isLoading = false;
          });
        }

        // 预加载图片
        if (mounted) {
          _preloadImages(cachedFavorites);
        }
      } else {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  /// 预加载图片
  Future<void> _preloadImages(List<FavoriteItem> favorites) async {
    if (!mounted) return;

    // 只预加载前几个图片，避免过度预加载
    final int preloadCount = math.min(favorites.length, 5);
    for (int i = 0; i < preloadCount; i++) {
      if (!mounted) break;

      final favorite = favorites[i];
      final imageUrl = await getImageUrl(favorite.cover, favorite.source);
      if (imageUrl.isNotEmpty) {
        final headers = getImageRequestHeaders(imageUrl, favorite.source);
        final provider = NetworkImage(imageUrl, headers: headers);
        precacheImage(provider, context);
      }
    }
  }

  /// 将收藏项转换为播放记录（如果有匹配的播放记录则使用播放记录数据）
  PlayRecord _favoriteToPlayRecord(FavoriteItem favorite) {
    // 查找匹配的播放记录
    try {
      final matchingPlayRecord = _playRecords.firstWhere(
        (record) =>
            record.source == favorite.source && record.id == favorite.id,
      );
      // 如果有匹配的播放记录，使用播放记录的数据
      return matchingPlayRecord;
    } catch (e) {
      // 如果没有匹配的播放记录，使用收藏夹的默认数据
      return PlayRecord(
        id: favorite.id,
        source: favorite.source,
        title: favorite.title,
        cover: favorite.cover,
        year: favorite.year,
        sourceName: favorite.sourceName,
        totalEpisodes: favorite.totalEpisodes,
        index: 0, // 0表示没有播放记录
        playTime: 0, // 未播放
        totalTime: 0, // 未知总时长
        saveTime: favorite.saveTime,
        searchTitle: favorite.title, // 使用标题作为搜索标题
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 如果没有数据且不在加载中，隐藏组件
    if (!_isLoading && _favorites.isEmpty) {
      return const SizedBox.shrink();
    }

    final isPC = DeviceUtils.isPC();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题和查看更多按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 左侧：标题
                Consumer<ThemeService>(
                  builder: (context, themeService, child) {
                    return Text(
                      '我的收藏',
                      style: FontUtils.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: themeService.isDarkMode
                            ? const Color(0xFFffffff)
                            : const Color(0xFF2c3e50),
                      ),
                    );
                  },
                ),
                // 右侧：查看更多按钮
                if (_favorites.isNotEmpty)
                  MouseRegion(
                    cursor: DeviceUtils.isPC()
                        ? SystemMouseCursors.click
                        : MouseCursor.defer,
                    onEnter: DeviceUtils.isPC()
                        ? (_) {
                            setState(() {
                              _isMoreButtonHovered = true;
                            });
                          }
                        : null,
                    onExit: DeviceUtils.isPC()
                        ? (_) {
                            setState(() {
                              _isMoreButtonHovered = false;
                            });
                          }
                        : null,
                    child: TextButton(
                      onPressed: widget.onViewAll,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        overlayColor: Colors.transparent,
                      ),
                      child: Text(
                        '查看全部 >',
                        style: FontUtils.poppins(
                          fontSize: 14,
                          color: DeviceUtils.isPC() && _isMoreButtonHovered
                              ? const Color(0xFF27ae60) // hover 时绿色
                              : const Color(0xFF7f8c8d),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 内容区域
          if (_isLoading)
            _buildLoadingState()
          else if (_hasError)
            _buildErrorState()
          else
            isPC ? _buildContentWithScrollButtons() : _buildContent(),
        ],
      ),
    );
  }

  /// 构建带滚动按钮的内容区域（PC端）
  Widget _buildContentWithScrollButtons() {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        // 延迟检查以确保滚动控制器已初始化
        Future.delayed(const Duration(milliseconds: 50), _checkScroll);
      },
      onExit: (_) => setState(() => _isHovered = false),
      child: Stack(
        children: [
          _buildContent(),
          // 左侧滚动按钮 - 定位在可视区域内
          if (_showLeftScroll)
            Positioned(
              left: 0,
              top: 0,
              bottom: 60,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  width: 80,
                  color: Colors.transparent,
                  child: IgnorePointer(
                    ignoring: !_isHovered,
                    child: AnimatedOpacity(
                      opacity: _isHovered ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Center(
                        child: _buildScrollButton(
                          icon: Icons.chevron_left,
                          onPressed: _scrollLeft,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // 右侧滚动按钮 - 定位在可视区域内
          if (_showRightScroll)
            Positioned(
              right: 0,
              top: 0,
              bottom: 60,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  width: 80,
                  color: Colors.transparent,
                  child: IgnorePointer(
                    ignoring: !_isHovered,
                    child: AnimatedOpacity(
                      opacity: _isHovered ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Center(
                        child: _buildScrollButton(
                          icon: Icons.chevron_right,
                          onPressed: _scrollRight,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 构建滚动按钮
  Widget _buildScrollButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: themeService.isDarkMode
                    ? const Color(0xE61F2937)
                    : const Color(0xF2FFFFFF),
                shape: BoxShape.circle,
                border: Border.all(
                  color: themeService.isDarkMode
                      ? const Color(0xFF4B5563)
                      : const Color(0xFFE5E7EB),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 32,
                color: themeService.isDarkMode
                    ? const Color(0xFFD1D5DB)
                    : const Color(0xFF4B5563),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 构建内容区域
  Widget _buildContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 根据宽度动态展示卡片数：平板模式 5.75/6.75/7.75，手机模式 2.75
        final double visibleCards = DeviceUtils.getHorizontalVisibleCards(context, 2.75);

        // 计算卡片宽度
        final double screenWidth = constraints.maxWidth;
        const double padding = 32.0; // 左右padding (16 * 2)
        const double spacing = 12.0; // 卡片间距
        final double availableWidth = screenWidth - padding;
        // 确保最小宽度，防止负宽度约束
        const double minCardWidth = 120.0; // 最小卡片宽度
        final double calculatedCardWidth =
            (availableWidth - (spacing * (visibleCards - 1))) / visibleCards;
        final double cardWidth = math.max(calculatedCardWidth, minCardWidth);
        final double cardHeight = (cardWidth * 1.5) + 50; // 缓存高度计算

        return SizedBox(
          height: cardHeight, // 使用缓存的高度
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            clipBehavior: Clip.none,
            itemCount: math.min(_favorites.length, 10), // 限制最多显示10个
            itemBuilder: (context, index) {
              final favorite = _favorites[index];
              final playRecord = _favoriteToPlayRecord(favorite);
              return Container(
                width: cardWidth,
                margin: EdgeInsets.only(
                  right: index < _favorites.length - 1 ? spacing : 0,
                ),
                child: VideoCard(
                  videoInfo: VideoInfo.fromPlayRecord(playRecord),
                  onTap: () => widget.onVideoTap?.call(favorite),
                  from: 'favorite',
                  cardWidth: cardWidth, // 使用动态计算的宽度
                  onGlobalMenuAction: (action) =>
                      widget.onGlobalMenuAction?.call(favorite, action),
                  isFavorited: true, // 收藏列表中的项目都是已收藏的
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// 构建加载状态
  Widget _buildLoadingState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 根据宽度动态展示卡片数：平板模式 5.75/6.75/7.75，手机模式 2.75
        final double visibleCards =
            DeviceUtils.getHorizontalVisibleCards(context, 2.75);
        final isTablet = DeviceUtils.isTablet(context);
        final int skeletonCount =
            isTablet ? visibleCards.ceil() : 3; // 骨架卡片数量

        // 计算卡片宽度
        final double screenWidth = constraints.maxWidth;
        const double padding = 32.0; // 左右padding (16 * 2)
        const double spacing = 12.0; // 卡片间距
        final double availableWidth = screenWidth - padding;
        // 确保最小宽度，防止负宽度约束
        const double minCardWidth = 120.0; // 最小卡片宽度
        final double calculatedCardWidth =
            (availableWidth - (spacing * (visibleCards - 1))) / visibleCards;
        final double cardWidth = math.max(calculatedCardWidth, minCardWidth);
        final double cardHeight = (cardWidth * 1.5) + 50; // 卡片基础高度计算
        final double containerHeight = cardHeight + 20; // 增加额外空间以防止 hover 放大时顶部截断

        return Container(
          height: containerHeight, // 使用增加后的高度
          padding: const EdgeInsets.only(left: 16, right: 16, top: 10),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: skeletonCount,
            itemBuilder: (context, index) {
              return Container(
                width: cardWidth,
                margin: EdgeInsets.only(
                  right: index < skeletonCount - 1 ? spacing : 0,
                ),
                child: _buildSkeletonCard(cardWidth),
              );
            },
          ),
        );
      },
    );
  }

  /// 构建骨架卡片
  Widget _buildSkeletonCard(double width) {
    final double height = width * 1.4; // 保持与VideoCard相同的比例

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 封面骨架
        ShimmerEffect(
          width: width,
          height: height,
          borderRadius: BorderRadius.circular(8),
        ),
        const SizedBox(height: 6),
        // 标题骨架
        Center(
          child: ShimmerEffect(
            width: width * 0.8,
            height: 14,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        // 源名称骨架
        Center(
          child: ShimmerEffect(
            width: width * 0.6,
            height: 10,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }

  /// 构建错误状态
  Widget _buildErrorState() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.grey[400],
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              '加载收藏列表失败',
              style: FontUtils.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadFavorites,
              child: Text(
                '重试',
                style: FontUtils.poppins(
                  fontSize: 12,
                  color: const Color(0xFF2c3e50),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 刷新收藏列表（供外部调用）
  Future<void> refreshFavorites() async {
    if (!mounted) return;

    try {
      if (mounted) {
        // 同时刷新收藏列表和播放记录
        final cachedFavoritesResult = await _cacheService.getFavoritesDirect(context);
        final cachedRecordsResult = await _cacheService.getPlayRecordsDirect(context);

        if (cachedFavoritesResult.success &&
            cachedFavoritesResult.data != null) {
          final cachedFavorites = cachedFavoritesResult.data as List<FavoriteItem>;
          final cachedRecords = (cachedRecordsResult.success &&
                  cachedRecordsResult.data != null)
              ? cachedRecordsResult.data as List<PlayRecord>
              : <PlayRecord>[];

          setState(() {
            _favorites = cachedFavorites;
            _playRecords = cachedRecords;
          });

          // 预加载新图片
          _preloadImages(cachedFavorites);
        }
      }
    } catch (e) {
      // 刷新失败，静默处理
    }
  }

  /// 从UI中移除指定的收藏项（供外部调用）
  void removeFavoriteFromUI(String source, String id) {
    if (!mounted) return;

    setState(() {
      _favorites
          .removeWhere((favorite) => favorite.source == source && favorite.id == id);
    });
  }
}
