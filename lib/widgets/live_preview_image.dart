import 'package:flutter/material.dart';
import '../models/live_channel.dart';
import '../services/live_preview_service.dart';

class LivePreviewImage extends StatefulWidget {
  final LiveChannel channel;
  final Widget Function(BuildContext context) defaultBuilder;

  const LivePreviewImage({
    super.key,
    required this.channel,
    required this.defaultBuilder,
  });

  @override
  State<LivePreviewImage> createState() => _LivePreviewImageState();
}

class _LivePreviewImageState extends State<LivePreviewImage> {
  @override
  void initState() {
    super.initState();
    // 添加监听器
    LivePreviewService.addListener(widget.channel.id, _onPreviewUpdate);
    // 尝试生成预览
    LivePreviewService.generatePreview(widget.channel);
  }

  @override
  void dispose() {
    // 移除监听器
    LivePreviewService.removeListener(widget.channel.id, _onPreviewUpdate);
    super.dispose();
  }

  void _onPreviewUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = LivePreviewService.getPreview(widget.channel.id);
    final isLoading = LivePreviewService.isLoading(widget.channel.id);

    // 如果有预览图，显示预览
    if (preview != null) {
      return Image.memory(
        preview,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return widget.defaultBuilder(context);
        },
      );
    }

    // 如果有 logo，显示 logo
    if (widget.channel.logo.isNotEmpty) {
      return Image.network(
        widget.channel.logo,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return widget.defaultBuilder(context);
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return widget.defaultBuilder(context);
        },
      );
    }

    // 显示默认图标
    return widget.defaultBuilder(context);
  }
}
