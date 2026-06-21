import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clip_fusion/providers/download_provider.dart';
import 'package:clip_fusion/theme/theme.dart';
import 'package:clip_fusion/theme/dynamic_color_helper.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  void _openFile(String? path, BuildContext context) async {
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (await file.exists()) {
      await OpenFile.open(path);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('File does not exist on disk! It may have been deleted.'),
          ),
        );
      }
    }
  }

  void _shareFile(String? path, String title) {
    if (path == null || path.isEmpty) return;
    Share.shareXFiles([XFile(path)], text: title);
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref, DownloadTask task) {
    final controller = TextEditingController(text: task.title);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: ClipFusionTheme.cardBg,
          title: const Text('Rename File', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Enter new title...',
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text('Rename', style: TextStyle(color: ClipFusionTheme.cyan)),
              onPressed: () {
                final newName = controller.text.trim();
                if (newName.isNotEmpty && task.filePath != null) {
                  ref.read(downloadQueueProvider.notifier).renameDownload(
                    task.id,
                    newName,
                    task.filePath!,
                  );
                }
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueState = ref.watch(downloadQueueProvider);
    final downloads = queueState.downloads;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
      ),
      body: queueState.isLoading && downloads.isEmpty
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(ClipFusionTheme.cyan)))
          : downloads.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(PhosphorIcons.cloudArrowDown, color: Colors.grey, size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        'Your download queue is empty',
                        style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Paste links on the home page to start downloads.',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: downloads.length,
                  itemBuilder: (context, index) {
                    final task = downloads[index];
                    final platformColor = DynamicColorHelper.getPlatformColor(task.platform);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      // Slide-to-dismiss gesture for deleting
                      child: Dismissible(
                        key: Key(task.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
                        ),
                        confirmDismiss: (direction) async {
                          // Double check deletion
                          return await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: ClipFusionTheme.cardBg,
                              title: const Text('Delete Download', style: TextStyle(color: Colors.white)),
                              content: const Text(
                                'Are you sure you want to remove this download record from database?',
                                style: TextStyle(color: Colors.white70),
                              ),
                              actions: [
                                TextButton(
                                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                                  onPressed: () => Navigator.pop(context, false),
                                ),
                                TextButton(
                                  child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                                  onPressed: () => Navigator.pop(context, true),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (_) {
                          ref.read(downloadQueueProvider.notifier).deleteDownload(task.id);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: ClipFusionTheme.cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: ClipFusionTheme.border, width: 1),
                          ),
                          child: Column(
                            children: [
                              ListTile(
                                contentPadding: const EdgeInsets.all(12),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: task.thumbnail.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: task.thumbnail,
                                          width: 80,
                                          height: 54,
                                          fit: BoxFit.cover,
                                          placeholder: (_, _) => Container(color: Colors.white10),
                                          errorWidget: (_, _, _) => Container(color: Colors.white10),
                                        )
                                      : Container(color: Colors.white10, width: 80, height: 54),
                                ),
                                title: Text(
                                  task.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Row(
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
                                      if (task.fileSize > 0) ...[
                                        Text(
                                          '${(task.fileSize / (1024 * 1024)).toStringAsFixed(1)} MB',
                                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Text(
                                        task.status,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: task.status == 'COMPLETED'
                                              ? Colors.greenAccent
                                              : task.status == 'FAILED'
                                                  ? Colors.redAccent
                                                  : Colors.amberAccent,
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                                onTap: task.status == 'COMPLETED'
                                    ? () => _openFile(task.filePath, context)
                                    : null,
                              ),
                              // Live download bar if task is downloading
                              if (task.status == 'DOWNLOADING') ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: LinearProgressIndicator(
                                    value: task.progress / 100.0,
                                    backgroundColor: Colors.white10,
                                    valueColor: AlwaysStoppedAnimation<Color>(platformColor),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${task.progress}% @ ${task.speed}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                      Text('ETA: ${task.eta}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                              ],
                              // Actions bar for completed downloads
                              if (task.status == 'COMPLETED') ...[
                                const Divider(color: Colors.white10, height: 1),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          task.favoriteState ? Icons.favorite : Icons.favorite_border,
                                          color: task.favoriteState ? Colors.redAccent : Colors.grey,
                                          size: 20,
                                        ),
                                        onPressed: () => ref.read(downloadQueueProvider.notifier).toggleFavorite(
                                              task.id,
                                              !task.favoriteState,
                                            ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.share_outlined, color: Colors.grey, size: 20),
                                        onPressed: () => _shareFile(task.filePath, task.title),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_note, color: Colors.grey, size: 22),
                                        onPressed: () => _showRenameDialog(context, ref, task),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.play_circle_outline, color: ClipFusionTheme.cyan, size: 22),
                                        onPressed: () => _openFile(task.filePath, context),
                                      ),
                                    ],
                                  ),
                                )
                              ]
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
