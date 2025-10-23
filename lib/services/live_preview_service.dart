import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/live_channel.dart';

class LivePreviewService {
  // 预览图缓存（包含时间戳）
  static final Map<int, _PreviewCache> _previewCache = {};
  
  // 正在加载的频道ID
  static final Set<int> _loadingChannels = {};
  
  // 预览图更新通知
  static final Map<int, List<VoidCallback>> _listeners = {};
  
  // 预览图有效期（5分钟）
  static const _cacheValidDuration = Duration(minutes: 5);

  // 获取频道预览图
  static Uint8List? getPreview(int channelId) {
    final cache = _previewCache[channelId];
    if (cache == null) return null;
    
    // 检查缓存是否过期
    if (DateTime.now().difference(cache.timestamp) > _cacheValidDuration) {
      _previewCache.remove(channelId);
      return null;
    }
    
    return cache.data;
  }

  // 检查是否正在加载
  static bool isLoading(int channelId) {
    return _loadingChannels.contains(channelId);
  }

  // 添加监听器
  static void addListener(int channelId, VoidCallback listener) {
    if (!_listeners.containsKey(channelId)) {
      _listeners[channelId] = [];
    }
    _listeners[channelId]!.add(listener);
  }

  // 移除监听器
  static void removeListener(int channelId, VoidCallback listener) {
    _listeners[channelId]?.remove(listener);
    if (_listeners[channelId]?.isEmpty ?? false) {
      _listeners.remove(channelId);
    }
  }

  // 通知监听器
  static void _notifyListeners(int channelId) {
    final listeners = _listeners[channelId];
    if (listeners != null) {
      for (var listener in List.from(listeners)) {
        listener();
      }
    }
  }

  // 生成频道预览图
  static Future<void> generatePreview(LiveChannel channel) async {
    // 如果已经在加载，跳过
    if (_loadingChannels.contains(channel.id)) {
      return;
    }

    // 检查缓存是否有效
    final cachedPreview = getPreview(channel.id);
    if (cachedPreview != null) {
      return;
    }

    _loadingChannels.add(channel.id);

    try {
      Uint8List? previewData;
      
      // 直接使用频道 logo
      if (channel.logo.isNotEmpty) {
        previewData = await _downloadImage(channel.logo);
      }
      
      // 保存到缓存
      if (previewData != null) {
        _previewCache[channel.id] = _PreviewCache(
          data: previewData,
          timestamp: DateTime.now(),
        );
      } else {
        // 标记为已尝试但失败
        _previewCache[channel.id] = _PreviewCache(
          data: null,
          timestamp: DateTime.now(),
        );
      }
      
      _notifyListeners(channel.id);
    } catch (e) {
      print('生成预览失败 [${channel.title}]: $e');
      _previewCache[channel.id] = _PreviewCache(
        data: null,
        timestamp: DateTime.now(),
      );
    } finally {
      _loadingChannels.remove(channel.id);
      _notifyListeners(channel.id);
    }
  }
  
  // 下载图片
  static Future<Uint8List?> _downloadImage(String url) async {
    try {
      final response = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      print('下载图片失败: $e');
    }
    return null;
  }

  // 批量生成预览图
  static Future<void> generatePreviews(List<LiveChannel> channels) async {
    // 限制并发数量
    const maxConcurrent = 3;
    final futures = <Future>[];

    for (var i = 0; i < channels.length; i += maxConcurrent) {
      final batch = channels.skip(i).take(maxConcurrent);
      futures.addAll(batch.map((channel) => generatePreview(channel)));
      
      // 等待当前批次完成
      await Future.wait(futures);
      futures.clear();
      
      // 短暂延迟，避免请求过快
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  // 清除缓存
  static void clearCache() {
    _previewCache.clear();
    _loadingChannels.clear();
  }

  // 清除特定频道的缓存
  static void clearChannelCache(int channelId) {
    _previewCache.remove(channelId);
  }

  // 刷新预览图
  static Future<void> refreshPreview(LiveChannel channel) async {
    clearChannelCache(channel.id);
    await generatePreview(channel);
  }

  // 刷新所有预览图
  static Future<void> refreshAllPreviews(List<LiveChannel> channels) async {
    clearCache();
    await generatePreviews(channels);
  }
}

// 预览缓存数据结构
class _PreviewCache {
  final Uint8List? data;
  final DateTime timestamp;

  _PreviewCache({
    required this.data,
    required this.timestamp,
  });
}
