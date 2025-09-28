import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dlna_dart/dlna.dart';

class DLNADeviceDialog extends StatefulWidget {
  const DLNADeviceDialog({super.key});

  @override
  State<DLNADeviceDialog> createState() => _DLNADeviceDialogState();
}

class _DLNADeviceDialogState extends State<DLNADeviceDialog> {
  DLNAManager? _dlnaManager;
  Map<String, DLNADevice> _devices = {};
  bool _isScanning = false;
  String _scanStatus = '准备扫描设备...';
  Timer? _scanTimer;

  @override
  void initState() {
    super.initState();
    _startScanning();
  }

  @override
  void dispose() {
    _stopScanning();
    super.dispose();
  }

  Future<void> _startScanning() async {
    try {
      setState(() {
        _isScanning = true;
        _scanStatus = '正在扫描DLNA设备...';
      });

      _dlnaManager = DLNAManager();
      final manager = await _dlnaManager!.start();
      
      // 监听设备发现
      manager.devices.stream.listen((deviceList) {
        if (mounted) {
          setState(() {
            _devices = deviceList;
            _scanStatus = '发现 ${_devices.length} 个设备';
          });
        }
      });

      // 设置扫描超时
      _scanTimer = Timer(const Duration(seconds: 10), () {
        if (mounted) {
          setState(() {
            _isScanning = false;
            _scanStatus = '扫描完成，发现 ${_devices.length} 个设备';
          });
        }
      });

    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _scanStatus = '扫描失败: $e';
        });
      }
    }
  }

  void _stopScanning() {
    _scanTimer?.cancel();
    _dlnaManager?.stop();
  }

  void _refreshScanning() {
    _stopScanning();
    _devices.clear();
    _startScanning();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
        child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).dialogBackgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '选择投屏设备',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 扫描状态
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  if (_isScanning)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      Icons.wifi_find,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _scanStatus,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (!_isScanning)
                    TextButton(
                      onPressed: _refreshScanning,
                      child: const Text('重新扫描'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // 设备列表
            Expanded(
              child: _devices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.devices_other,
                            size: 64,
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _isScanning ? '正在搜索设备...' : '未发现DLNA设备',
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (!_isScanning) ...[
                            const SizedBox(height: 8),
                            Text(
                              '请确保设备与手机在同一网络下',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _devices.length,
                      itemBuilder: (context, index) {
                        final deviceEntry = _devices.entries.elementAt(index);
                        final device = deviceEntry.value;
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            leading: Icon(
                              _getDeviceIcon(device.info.friendlyName),
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            title: Text(
                              device.info.friendlyName,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).textTheme.titleMedium?.color,
                              ),
                            ),
                            subtitle: Text(
                              '活跃时间: ${_formatTime(device.activeTime)}',
                              style: TextStyle(
                                color: Theme.of(context).textTheme.bodyMedium?.color,
                              ),
                            ),
                            onTap: () {
                              // 直接连接设备
                              _showConnectionDialog(device);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getDeviceIcon(String deviceName) {
    final name = deviceName.toLowerCase();
    if (name.contains('tv') || name.contains('电视')) {
      return Icons.tv;
    } else if (name.contains('box') || name.contains('盒子')) {
      return Icons.device_hub;
    } else if (name.contains('player') || name.contains('播放器')) {
      return Icons.play_circle_outline;
    } else {
      return Icons.devices_other;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else {
      return '${difference.inDays}天前';
    }
  }

  void _showConnectionDialog(DLNADevice device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('连接设备'),
        content: Text('正在连接到 ${device.info.friendlyName}...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    
    // 模拟连接过程
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pop(); // 关闭连接对话框
        Navigator.of(context).pop(); // 关闭设备选择对话框
        
        // 显示连接成功提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已连接到 ${device.info.friendlyName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }
}
