import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/live_channel.dart';

class LiveChannelService {
  static const String _channelsKey = 'live_channels';
  static const String _sourceUrlKey = 'live_source_url';
  static const String _favoritesKey = 'live_favorites';

  // 获取频道列表
  static Future<List<LiveChannel>> getChannels() async {
    final prefs = await SharedPreferences.getInstance();
    final channelsJson = prefs.getString(_channelsKey);
    
    if (channelsJson == null || channelsJson.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decoded = json.decode(channelsJson);
      final channels = decoded.map((e) => LiveChannel.fromJson(e)).toList();
      
      // 加载收藏状态
      final favorites = await _getFavoriteIds();
      for (var channel in channels) {
        channel.isFavorite = favorites.contains(channel.id);
      }
      
      return channels;
    } catch (e) {
      print('解析频道列表失败: $e');
      return [];
    }
  }

  // 保存频道列表
  static Future<void> saveChannels(List<LiveChannel> channels) async {
    final prefs = await SharedPreferences.getInstance();
    final channelsJson = json.encode(channels.map((e) => e.toJson()).toList());
    await prefs.setString(_channelsKey, channelsJson);
  }

  // 获取频道源地址
  static Future<String?> getSourceUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sourceUrlKey);
  }

  // 保存频道源地址
  static Future<void> saveSourceUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sourceUrlKey, url);
  }

  // 从 MoonTV API 获取直播源
  static Future<List<LiveChannel>> fetchFromMoonTV(String baseUrl) async {
    try {
      final url = '$baseUrl/api/live/sources';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode != 200) {
        throw Exception('请求失败: ${response.statusCode}');
      }

      final data = json.decode(utf8.decode(response.bodyBytes));
      
      if (data['success'] != true || data['data'] == null) {
        throw Exception('API 返回数据格式错误');
      }

      final List<dynamic> sources = data['data'];
      final channels = <LiveChannel>[];
      
      for (var i = 0; i < sources.length; i++) {
        final source = sources[i];
        
        // 解析每个直播源
        final channel = LiveChannel(
          id: i,
          name: source['name'] ?? '',
          title: source['name'] ?? '',
          logo: source['logo'] ?? '',
          uris: [source['url'] ?? ''],
          group: source['group'] ?? '未分组',
          number: source['number'] ?? -1,
        );
        
        channels.add(channel);
      }
      
      if (channels.isEmpty) {
        throw Exception('未找到有效频道');
      }

      await saveChannels(channels);
      await saveSourceUrl(baseUrl);
      
      return channels;
    } catch (e) {
      throw Exception('从 MoonTV 获取失败: $e');
    }
  }



  // 按分组获取频道
  static Future<List<LiveChannelGroup>> getChannelsByGroup() async {
    final channels = await getChannels();
    final groupMap = <String, List<LiveChannel>>{};

    for (var channel in channels) {
      if (!groupMap.containsKey(channel.group)) {
        groupMap[channel.group] = [];
      }
      groupMap[channel.group]!.add(channel);
    }

    return groupMap.entries
        .map((e) => LiveChannelGroup(name: e.key, channels: e.value))
        .toList();
  }

  // 获取收藏的频道ID列表
  static Future<Set<int>> _getFavoriteIds() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = prefs.getString(_favoritesKey);
    
    if (favoritesJson == null || favoritesJson.isEmpty) {
      return {};
    }

    try {
      final List<dynamic> decoded = json.decode(favoritesJson);
      return decoded.map((e) => e as int).toSet();
    } catch (e) {
      return {};
    }
  }

  // 保存收藏的频道ID列表
  static Future<void> _saveFavoriteIds(Set<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_favoritesKey, json.encode(ids.toList()));
  }

  // 切换收藏状态
  static Future<void> toggleFavorite(int channelId) async {
    final favorites = await _getFavoriteIds();
    
    if (favorites.contains(channelId)) {
      favorites.remove(channelId);
    } else {
      favorites.add(channelId);
    }
    
    await _saveFavoriteIds(favorites);
  }

  // 获取收藏的频道
  static Future<List<LiveChannel>> getFavoriteChannels() async {
    final channels = await getChannels();
    return channels.where((c) => c.isFavorite).toList();
  }


}
