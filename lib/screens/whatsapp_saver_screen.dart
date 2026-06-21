import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clip_fusion/providers/download_provider.dart';
import 'package:clip_fusion/theme/theme.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class WhatsAppSaverScreen extends ConsumerWidget {
  const WhatsAppSaverScreen({super.key});

  void _saveStatus(BuildContext context, String uri) async {
    final savedPath = await WhatsAppStatusManager.saveStatus(uri);
    if (savedPath != null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text('Status Saved to Downloads! ($savedPath)'),
          ),
        );
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Failed to save status!'),
          ),
        );
      }
    }
  }

  void _previewStatus(BuildContext context, Map<String, dynamic> status) {
    final isVideo = status['type'] == 'video';
    final thumbnail = status['thumbnail'] as String? ?? '';
    final name = status['name'] as String;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                backgroundColor: Colors.black,
                title: Text(name, style: const TextStyle(fontSize: 14)),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: Center(
                  child: thumbnail.isNotEmpty
                      ? Image.file(
                          File(thumbnail),
                          fit: BoxFit.contain,
                        )
                      : const Icon(Icons.image, size: 80, color: Colors.grey),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isVideo) ...[
                      const Icon(Icons.video_library, color: Colors.greenAccent),
                      const SizedBox(width: 8),
                      const Text('Video Status', style: TextStyle(color: Colors.white70)),
                      const Spacer(),
                    ],
                    ElevatedButton.icon(
                      icon: const Icon(Icons.download),
                      label: const Text('Save to Gallery'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _saveStatus(context, status['uri'] as String);
                      },
                    ),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treeUri = ref.watch(whatsappTreeUriProvider);
    final statusesAsync = ref.watch(whatsappStatusesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('WhatsApp Status Saver'),
      ),
      body: treeUri == null
          ? _buildPermissionPrompt(context)
          : statusesAsync.when(
              data: (list) {
                if (list.isEmpty) {
                  return _buildEmptyState(ref);
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final status = list[index];
                    final isVideo = status['type'] == 'video';
                    final thumbnail = status['thumbnail'] as String? ?? '';

                    return Card(
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: ClipFusionTheme.border),
                      ),
                      child: Stack(
                        children: [
                          // Thumbnail Preview
                          Positioned.fill(
                            child: thumbnail.isNotEmpty
                                ? Image.file(
                                    File(thumbnail),
                                    fit: BoxFit.cover,
                                  )
                                : Container(color: Colors.white10),
                          ),
                          // Video watermark overlay
                          if (isVideo)
                            const Positioned(
                              top: 10,
                              left: 10,
                              child: CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.black54,
                                child: Icon(Icons.play_arrow, size: 16, color: Colors.white),
                              ),
                            ),
                          // Click preview detector
                          Positioned.fill(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _previewStatus(context, status),
                              ),
                            ),
                          ),
                          // Save button bottom-right
                          Positioned(
                            bottom: 10,
                            right: 10,
                            child: FloatingActionButton.small(
                              heroTag: 'save_fab_$index',
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: const CircleBorder(),
                              onPressed: () => _saveStatus(context, status['uri'] as String),
                              child: const Icon(Icons.download, size: 18),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.green)),
              ),
              error: (err, stack) => Center(
                child: Text('Error: ${err.toString()}', style: const TextStyle(color: Colors.redAccent)),
              ),
            ),
    );
  }

  Widget _buildPermissionPrompt(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: const Color(0x1B25D366),
              child: const Icon(PhosphorIcons.whatsappLogo, color: Color(0xFF25D366), size: 48),
            ),
            const SizedBox(height: 24),
            const Text(
              'Permission Required',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            const Text(
              'To save WhatsApp statuses, you need to grant explicit access to the WhatsApp Media Statuses directory. This uses Scoped Storage Safely.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.folder_open),
              label: const Text('Select Statuses Folder'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => WhatsAppStatusManager.requestSAFPermission(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_open_outlined, color: Colors.grey, size: 64),
            const SizedBox(height: 16),
            const Text(
              'No statuses found',
              style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please open WhatsApp and view statuses first, then refresh this page.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              icon: const Icon(Icons.refresh, color: Colors.green),
              label: const Text('Refresh', style: TextStyle(color: Colors.green)),
              onPressed: () => ref.invalidate(whatsappStatusesProvider),
            )
          ],
        ),
      ),
    );
  }
}
