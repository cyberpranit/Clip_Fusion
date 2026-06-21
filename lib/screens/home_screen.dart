import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clip_fusion/providers/download_provider.dart';
import 'package:clip_fusion/providers/clipboard_provider.dart';
import 'package:clip_fusion/theme/theme.dart';
import 'package:clip_fusion/theme/dynamic_color_helper.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final VoidCallback onNavigateToDownloads;
  final VoidCallback onNavigateToWhatsApp;

  const HomeScreen({
    super.key,
    required this.onNavigateToDownloads,
    required this.onNavigateToWhatsApp,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isFetching = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  // Pre-fill url controller with template URLs for demo
  void _prefillUrl(String platform) {
    String url = '';
    switch (platform) {
      case 'youtube':
        url = 'https://www.youtube.com/watch?v=aqz-KE-bpKQ'; // Sample short video
        break;
      case 'instagram':
        url = 'https://www.instagram.com/reel/C8C8C8C8/';
        break;
      case 'tiktok':
        url = 'https://www.tiktok.com/@sample/video/123456789';
        break;
      case 'facebook':
        url = 'https://www.facebook.com/watch/?v=12345678';
        break;
      case 'x':
        url = 'https://x.com/sample/status/1234567890';
        break;
      case 'whatsapp':
        widget.onNavigateToWhatsApp();
        return;
    }
    _urlController.text = url;
    setState(() {});
  }

  Future<void> _handleDownloadTrigger(String url, {String? quickFormat, bool isAudioOnly = false}) async {
    if (url.trim().isEmpty) return;

    setState(() {
      _isFetching = true;
    });

    try {
      final notifier = ref.read(downloadQueueProvider.notifier);
      final info = await notifier.getVideoInfo(url);

      if (info != null && mounted) {
        setState(() {
          _isFetching = false;
        });
        
        if (quickFormat != null) {
          // Automatic quick download
          await notifier.startDownload(
            url: url,
            title: info['title'] as String,
            thumbnail: info['thumbnail'] as String,
            duration: (info['duration'] as num?)?.toInt() ?? 0,
            platform: ref.read(clipboardProvider).platform ?? 'youtube',
            isAudioOnly: isAudioOnly,
          );
        } else {
          // Open format selection bottom sheet
          _showFormatSelector(url, info);
        }
      }
    } catch (e) {
      setState(() {
        _isFetching = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Failed to fetch video details: ${e.toString()}'),
          ),
        );
      }
    }
  }

  void _showFormatSelector(String url, Map<String, dynamic> info) {
    final formats = (info['formats'] as List<dynamic>?) ?? [];
    final title = info['title'] as String? ?? 'Video File';
    final thumbnail = info['thumbnail'] as String? ?? '';
    final duration = info['duration'] as int? ?? 0;
    final uploader = info['uploader'] as String? ?? 'Uploader';
    
    // Group heights/resolutions
    final videoFormats = formats.where((f) {
      final h = f['height'] as int?;
      final ext = f['ext'] as String? ?? '';
      final note = (f['note'] as String? ?? '').toLowerCase();
      if (ext == 'mhtml' || note.contains('storyboard')) {
        return false;
      }
      return h != null && h > 0;
    }).toList();

    // Deduplicate video resolutions by height
    final seenHeights = <int>{};
    final uniqueResolutions = <Map<String, dynamic>>[];
    for (var f in videoFormats) {
      final h = f['height'] as int;
      if (!seenHeights.contains(h)) {
        seenHeights.add(h);
        uniqueResolutions.add(Map<String, dynamic>.from(f));
      }
    }
    uniqueResolutions.sort((a, b) => (b['height'] as int).compareTo(a['height'] as int));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GlassCard(
          borderRadius: 28,
          opacity: 0.14,
          blur: 25,
          padding: const EdgeInsets.only(top: 24, left: 20, right: 20, bottom: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              // Video Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: thumbnail.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: thumbnail,
                            width: 100,
                            height: 60,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => Container(color: Colors.white10),
                            errorWidget: (_, _, _) => Container(color: Colors.white10),
                          )
                        : Container(color: Colors.white10, width: 100, height: 60),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          uploader,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          'Duration: ${Duration(seconds: duration).toString().split('.').first}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Select Format & Quality',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
              const SizedBox(height: 12),
              // Option lists
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  children: [
                    // MP3 Audio Option
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.white10),
                      ),
                      leading: const Icon(Icons.music_note, color: ClipFusionTheme.cyan),
                      title: const Text('Extract Audio (MP3)', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Best available bitrate'),
                      trailing: const Icon(Icons.download, color: Colors.white70),
                      onTap: () {
                        Navigator.pop(context);
                        ref.read(downloadQueueProvider.notifier).startDownload(
                          url: url,
                          title: title,
                          thumbnail: thumbnail,
                          duration: duration,
                          platform: _detectPlatformName(url),
                          isAudioOnly: true,
                        );
                        widget.onNavigateToDownloads();
                      },
                    ),
                    const SizedBox(height: 10),
                    // Video Options
                    if (uniqueResolutions.isEmpty)
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Colors.white10),
                        ),
                        leading: const Icon(Icons.video_library, color: ClipFusionTheme.electricPurple),
                        title: const Text('Best Video Quality'),
                        subtitle: const Text('Standard multiplexed MP4'),
                        trailing: const Icon(Icons.download, color: Colors.white70),
                        onTap: () {
                          Navigator.pop(context);
                          ref.read(downloadQueueProvider.notifier).startDownload(
                            url: url,
                            title: title,
                            thumbnail: thumbnail,
                            duration: duration,
                            platform: _detectPlatformName(url),
                          );
                          widget.onNavigateToDownloads();
                        },
                      )
                    else
                      ...uniqueResolutions.map((res) {
                        final h = res['height'] as int;
                        final note = res['note'] as String? ?? '';
                        final formatId = res['formatId'] as String;
                        final ext = res['ext'] as String;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Colors.white10),
                            ),
                            leading: const Icon(Icons.video_library, color: ClipFusionTheme.electricPurple),
                            title: Text('Download Video (${h}p)', style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('$ext • $note'),
                            trailing: const Icon(Icons.download, color: Colors.white70),
                            onTap: () {
                              Navigator.pop(context);
                              ref.read(downloadQueueProvider.notifier).startDownload(
                                url: url,
                                title: title,
                                thumbnail: thumbnail,
                                duration: duration,
                                platform: _detectPlatformName(url),
                                formatId: formatId,
                              );
                              widget.onNavigateToDownloads();
                            },
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _detectPlatformName(String url) {
    final cleanUrl = url.toLowerCase();
    if (cleanUrl.contains('youtube') || cleanUrl.contains('youtu.be')) return 'youtube';
    if (cleanUrl.contains('instagram')) return 'instagram';
    if (cleanUrl.contains('tiktok')) return 'tiktok';
    if (cleanUrl.contains('facebook') || cleanUrl.contains('fb.watch')) return 'facebook';
    if (cleanUrl.contains('x.com') || cleanUrl.contains('twitter')) return 'x';
    return 'unknown';
  }

  @override
  Widget build(BuildContext context) {
    final clipboardState = ref.watch(clipboardProvider);
    final queueState = ref.watch(downloadQueueProvider);
    final recentDownloads = queueState.downloads.take(4).toList();

    return Scaffold(
      body: Stack(
        children: [
          // Background Glow effect
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: ClipFusionTheme.cyan.withValues(alpha: 0.12),
                    blurRadius: 100,
                  )
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: ClipFusionTheme.electricPurple.withValues(alpha: 0.08),
                    blurRadius: 120,
                  )
                ],
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                const SizedBox(height: 10),
                // Header Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => ClipFusionTheme.primaryGradient.createShader(bounds),
                      child: const Text(
                        'ClipFusion',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(PhosphorIcons.folderOpen, color: Colors.white, size: 26),
                      onPressed: widget.onNavigateToDownloads,
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                // Paste Input Field
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PASTE MEDIA URL',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _urlController,
                            style: const TextStyle(fontSize: 14, color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Enter YouTube, Instagram reels, TikTok link...',
                              prefixIcon: const Icon(PhosphorIcons.link, color: Colors.grey, size: 20),
                              suffixIcon: _urlController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, color: Colors.grey, size: 18),
                                      onPressed: () {
                                        _urlController.clear();
                                        setState(() {});
                                      },
                                    )
                                  : null,
                            ),
                            onChanged: (text) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Download button with shimmer progress indicator
                        GestureDetector(
                          onTap: _isFetching ? null : () => _handleDownloadTrigger(_urlController.text),
                          child: Container(
                            height: 54,
                            width: 54,
                            decoration: BoxDecoration(
                              gradient: ClipFusionTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: ClipFusionTheme.cyan.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                )
                              ],
                            ),
                            child: Center(
                              child: _isFetching
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                                    )
                                  : const Icon(PhosphorIcons.arrowDown, color: Colors.white, size: 22),
                            ),
                          ),
                        )
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Clipboard Card
                if (clipboardState.hasLink) ...[
                  GestureDetector(
                    onTap: () {
                      _urlController.text = clipboardState.detectedUrl!;
                      ref.read(clipboardProvider.notifier).clear();
                      setState(() {});
                    },
                    child: GlassCard(
                      borderRadius: 18,
                      opacity: 0.16,
                      color: DynamicColorHelper.getPlatformColor(clipboardState.platform!),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                PhosphorIcons.clipboardTextBold,
                                color: DynamicColorHelper.getPlatformColor(clipboardState.platform!),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Link Detected from ${clipboardState.platform!.toUpperCase()}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () => ref.read(clipboardProvider.notifier).clear(),
                                child: const Icon(Icons.close, color: Colors.grey, size: 18),
                              )
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            clipboardState.detectedUrl!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Colors.white70),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(PhosphorIcons.video, size: 16),
                                  label: const Text('Video', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white10,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () {
                                    final url = clipboardState.detectedUrl!;
                                    ref.read(clipboardProvider.notifier).clear();
                                    _handleDownloadTrigger(url);
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(PhosphorIcons.musicNote, size: 16),
                                  label: const Text('Audio', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white10,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () {
                                    final url = clipboardState.detectedUrl!;
                                    ref.read(clipboardProvider.notifier).clear();
                                    _handleDownloadTrigger(url, quickFormat: 'bestaudio', isAudioOnly: true);
                                  },
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Platform Shortcuts
                const Text(
                  'SUPPORTED PLATFORMS',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.3,
                  children: [
                    _buildPlatformTile('YouTube', 'youtube', PhosphorIcons.youtubeLogo, const Color(0xFFE50914)),
                    _buildPlatformTile('Instagram', 'instagram', PhosphorIcons.instagramLogo, const Color(0xFFD62976)),
                    _buildPlatformTile('TikTok', 'tiktok', PhosphorIcons.tiktokLogo, const Color(0xFF00F2FE)),
                    _buildPlatformTile('Facebook', 'facebook', PhosphorIcons.facebookLogo, const Color(0xFF1877F2)),
                    _buildPlatformTile('X / Twitter', 'x', PhosphorIcons.xLogo, Colors.white),
                    _buildPlatformTile('WhatsApp', 'whatsapp', PhosphorIcons.whatsappLogo, const Color(0xFF25D366)),
                  ],
                ),
                const SizedBox(height: 30),

                // Recent Downloads
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'RECENT DOWNLOADS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1),
                    ),
                    if (recentDownloads.isNotEmpty)
                      GestureDetector(
                        onTap: widget.onNavigateToDownloads,
                        child: const Text(
                          'View All',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ClipFusionTheme.cyan),
                        ),
                      )
                  ],
                ),
                const SizedBox(height: 12),
                if (recentDownloads.isEmpty)
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: ClipFusionTheme.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ClipFusionTheme.border),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(PhosphorIcons.folder, color: Colors.grey, size: 28),
                          const SizedBox(height: 8),
                          const Text('No recent downloads', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recentDownloads.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final task = recentDownloads[index];
                      final platformColor = DynamicColorHelper.getPlatformColor(task.platform);

                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: ClipFusionTheme.cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: ClipFusionTheme.border),
                        ),
                        child: Row(
                          children: [
                            // Thumbnail
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: task.thumbnail.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: task.thumbnail,
                                      width: 64,
                                      height: 44,
                                      fit: BoxFit.cover,
                                      placeholder: (_, _) => Container(color: Colors.white10),
                                      errorWidget: (_, _, _) => Container(color: Colors.white10),
                                    )
                                  : Container(color: Colors.white10, width: 64, height: 44),
                            ),
                            const SizedBox(width: 12),
                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    task.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: platformColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          task.platform.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: platformColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        task.status,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: task.status == 'COMPLETED'
                                              ? Colors.greenAccent
                                              : task.status == 'FAILED'
                                                  ? Colors.redAccent
                                                  : Colors.amberAccent,
                                        ),
                                      )
                                    ],
                                  )
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // File action
                            if (task.status == 'COMPLETED')
                              const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 20)
                            else if (task.status == 'FAILED')
                              const Icon(Icons.error_outline, color: Colors.redAccent, size: 20)
                            else
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(ClipFusionTheme.cyan)),
                              )
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformTile(String title, String key, IconData icon, Color color) {
    return GestureDetector(
      onTap: () => _prefillUrl(key),
      child: Container(
        decoration: BoxDecoration(
          color: ClipFusionTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ClipFusionTheme.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70),
            )
          ],
        ),
      ),
    );
  }
}
