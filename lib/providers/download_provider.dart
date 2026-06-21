import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

class DownloadTask {
  final String id;
  final String url;
  final String title;
  final String thumbnail;
  final int duration;
  final int fileSize;
  final String platform;
  final DateTime downloadDate;
  final bool favoriteState;
  final String status; // PENDING, DOWNLOADING, PAUSED, COMPLETED, FAILED
  final String? filePath;
  final int progress;
  final String speed;
  final String eta;

  DownloadTask({
    required this.id,
    required this.url,
    required this.title,
    required this.thumbnail,
    required this.duration,
    required this.fileSize,
    required this.platform,
    required this.downloadDate,
    required this.favoriteState,
    required this.status,
    this.filePath,
    required this.progress,
    required this.speed,
    required this.eta,
  });

  DownloadTask copyWith({
    String? id,
    String? url,
    String? title,
    String? thumbnail,
    int? duration,
    int? fileSize,
    String? platform,
    DateTime? downloadDate,
    bool? favoriteState,
    String? status,
    String? filePath,
    int? progress,
    String? speed,
    String? eta,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      thumbnail: thumbnail ?? this.thumbnail,
      duration: duration ?? this.duration,
      fileSize: fileSize ?? this.fileSize,
      platform: platform ?? this.platform,
      downloadDate: downloadDate ?? this.downloadDate,
      favoriteState: favoriteState ?? this.favoriteState,
      status: status ?? this.status,
      filePath: filePath ?? this.filePath,
      progress: progress ?? this.progress,
      speed: speed ?? this.speed,
      eta: eta ?? this.eta,
    );
  }

  factory DownloadTask.fromMap(Map<dynamic, dynamic> map) {
    return DownloadTask(
      id: map['id'] as String,
      url: map['url'] as String,
      title: map['title'] as String,
      thumbnail: map['thumbnail'] as String,
      duration: map['duration'] as int? ?? 0,
      fileSize: map['fileSize'] as int? ?? 0,
      platform: map['platform'] as String? ?? 'unknown',
      downloadDate: DateTime.fromMillisecondsSinceEpoch(map['downloadDate'] as int? ?? DateTime.now().millisecondsSinceEpoch),
      favoriteState: map['favoriteState'] as bool? ?? false,
      status: map['status'] as String? ?? 'PENDING',
      filePath: map['filePath'] as String?,
      progress: map['progress'] as int? ?? 0,
      speed: map['speed'] as String? ?? '',
      eta: map['eta'] as String? ?? '',
    );
  }
}

class DownloadQueueState {
  final List<DownloadTask> downloads;
  final bool isLoading;

  DownloadQueueState({required this.downloads, this.isLoading = false});

  DownloadQueueState copyWith({
    List<DownloadTask>? downloads,
    bool? isLoading,
  }) {
    return DownloadQueueState(
      downloads: downloads ?? this.downloads,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class DownloadQueueNotifier extends Notifier<DownloadQueueState> {
  static const _methodChannel = MethodChannel('com.antigravity.clipfusion/download');
  static const _eventChannel = EventChannel('com.antigravity.clipfusion/download_events');
  
  StreamSubscription? _eventSubscription;

  @override
  DownloadQueueState build() {
    _initChannels();
    Future.microtask(() {
      loadDownloads();
      updateYoutubeDLEngine();
    });
    
    ref.onDispose(() {
      _eventSubscription?.cancel();
    });

    return DownloadQueueState(downloads: [], isLoading: true);
  }

  void _initChannels() {
    _methodChannel.setMethodCallHandler((call) async {
      if (call.method == 'onSAFPermissionGranted') {
        final treeUri = call.arguments as String;
        ref.read(whatsappTreeUriProvider.notifier).setUri(treeUri);
      }
    });

    _eventSubscription = _eventChannel.receiveBroadcastStream().listen((data) {
      if (data is Map) {
        final id = data['id'] as String;
        final progress = data['progress'] as int;
        final speed = data['speed'] as String;
        final eta = data['eta'] as String;
        final status = data['status'] as String;

        _updateTaskProgress(id, progress, speed, eta, status);
      }
    });
  }

  void _updateTaskProgress(String id, int progress, String speed, String eta, String status) {
    state = state.copyWith(
      downloads: state.downloads.map((task) {
        if (task.id == id) {
          return task.copyWith(
            progress: progress,
            speed: speed,
            eta: eta,
            status: status,
          );
        }
        return task;
      }).toList(),
    );
    if (status == 'COMPLETED' || status == 'FAILED' || status == 'PAUSED') {
      loadDownloads();
    }
  }

  Future<void> loadDownloads() async {
    state = state.copyWith(isLoading: true);
    try {
      final List<dynamic> list = await _methodChannel.invokeMethod('getDownloads');
      final tasks = list.map((item) => DownloadTask.fromMap(item as Map)).toList();
      state = state.copyWith(downloads: tasks, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> updateYoutubeDLEngine() async {
    try {
      await _methodChannel.invokeMethod('updateYoutubeDL');
    } catch (e) {
      // Ignore update errors
    }
  }

  Future<Map<String, dynamic>?> getVideoInfo(String url) async {
    try {
      final Map<dynamic, dynamic>? info = await _methodChannel.invokeMethod('getVideoInfo', {'url': url});
      if (info != null) {
        return Map<String, dynamic>.from(info);
      }
    } catch (e) {
      rethrow;
    }
    return null;
  }

  Future<void> startDownload({
    required String url,
    required String title,
    required String thumbnail,
    required int duration,
    required String platform,
    String formatId = 'best',
    bool isAudioOnly = false,
  }) async {
    final id = url.hashCode.toString();
    final directory = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final outputPath = '${directory.path}/Downloads';

    final newTask = DownloadTask(
      id: id,
      url: url,
      title: title,
      thumbnail: thumbnail,
      duration: duration,
      fileSize: 0,
      platform: platform,
      downloadDate: DateTime.now(),
      favoriteState: false,
      status: 'PENDING',
      progress: 0,
      speed: '',
      eta: '',
    );

    state = state.copyWith(
      downloads: [newTask, ...state.downloads.where((t) => t.id != id)],
    );

    try {
      await _methodChannel.invokeMethod('startDownload', {
        'id': id,
        'url': url,
        'outputPath': outputPath,
        'formatId': formatId,
        'isAudioOnly': isAudioOnly,
        'title': title,
        'platform': platform,
        'thumbnail': thumbnail,
        'duration': duration,
      });
      loadDownloads();
    } catch (e) {
      _updateTaskProgress(id, 0, '', '', 'FAILED');
    }
  }

  Future<void> pauseDownload(String id) async {
    try {
      await _methodChannel.invokeMethod('pauseDownload', {'id': id});
      loadDownloads();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> resumeDownload(DownloadTask task) async {
    await startDownload(
      url: task.url,
      title: task.title,
      thumbnail: task.thumbnail,
      duration: task.duration,
      platform: task.platform,
      formatId: 'best',
    );
  }

  Future<void> cancelDownload(String id) async {
    try {
      await _methodChannel.invokeMethod('cancelDownload', {'id': id});
      loadDownloads();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> deleteDownload(String id) async {
    try {
      await _methodChannel.invokeMethod('deleteDownload', {'id': id});
      state = state.copyWith(
        downloads: state.downloads.where((t) => t.id != id).toList(),
      );
    } catch (e) {
      // Handle error
    }
  }

  Future<void> toggleFavorite(String id, bool favoriteState) async {
    try {
      await _methodChannel.invokeMethod('toggleFavorite', {
        'id': id,
        'favoriteState': favoriteState,
      });
      state = state.copyWith(
        downloads: state.downloads.map((t) {
          if (t.id == id) {
            return t.copyWith(favoriteState: favoriteState);
          }
          return t;
        }).toList(),
      );
    } catch (e) {
      // Handle error
    }
  }

  Future<void> renameDownload(String id, String newTitle, String filePath) async {
    try {
      final file = File(filePath);
      final extension = file.path.split('.').last;
      final newPath = '${file.parent.path}/$newTitle.$extension';
      
      if (await file.exists()) {
        await file.rename(newPath);
      }

      await _methodChannel.invokeMethod('renameDownload', {
        'id': id,
        'title': newTitle,
        'filePath': newPath,
      });
      
      loadDownloads();
    } catch (e) {
      // Handle error
    }
  }

}

final downloadQueueProvider = NotifierProvider<DownloadQueueNotifier, DownloadQueueState>(() {
  return DownloadQueueNotifier();
});

class WhatsAppTreeUriNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setUri(String? uri) {
    state = uri;
  }
}

final whatsappTreeUriProvider = NotifierProvider<WhatsAppTreeUriNotifier, String?>(() {
  return WhatsAppTreeUriNotifier();
});

final whatsappStatusesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final treeUri = ref.watch(whatsappTreeUriProvider);
  if (treeUri == null) return [];
  
  const channel = MethodChannel('com.antigravity.clipfusion/download');
  try {
    final List<dynamic>? list = await channel.invokeMethod('getWhatsAppStatuses', {'treeUri': treeUri});
    if (list != null) {
      return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    }
  } catch (e) {
    // Handle error
  }
  return [];
});

class WhatsAppStatusManager {
  static const _channel = MethodChannel('com.antigravity.clipfusion/download');

  static Future<void> requestSAFPermission() async {
    await _channel.invokeMethod('getSAFPermissionIntent');
  }

  static Future<String?> saveStatus(String fileUri) async {
    try {
      final String? path = await _channel.invokeMethod('saveWhatsAppStatus', {'fileUri': fileUri});
      return path;
    } catch (e) {
      return null;
    }
  }
}
