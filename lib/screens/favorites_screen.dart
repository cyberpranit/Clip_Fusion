import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clip_fusion/providers/download_provider.dart';
import 'package:clip_fusion/theme/theme.dart';
import 'package:clip_fusion/theme/dynamic_color_helper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:open_file/open_file.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  void _openFile(String? path, BuildContext context) async {
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (await file.exists()) {
      await OpenFile.open(path);
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('File does not exist on disk! It may have been deleted.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueState = ref.watch(downloadQueueProvider);
    // Filter favorites
    final favorites = queueState.downloads
        .where((t) => t.favoriteState && t.status == 'COMPLETED')
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
      ),
      body: favorites.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.favorite_border, color: Colors.grey, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'No favorites yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap the heart icon on downloaded files to save them here.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Column 1: Even items
                  Expanded(
                    child: Column(
                      children: List.generate(
                        (favorites.length / 2).ceil(),
                        (index) => _buildStaggeredItem(context, favorites[index * 2], ref),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Column 2: Odd items
                  Expanded(
                    child: Column(
                      children: List.generate(
                        favorites.length ~/ 2,
                        (index) => _buildStaggeredItem(context, favorites[index * 2 + 1], ref),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStaggeredItem(BuildContext context, DownloadTask task, WidgetRef ref) {
    final platformColor = DynamicColorHelper.getPlatformColor(task.platform);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: ClipFusionTheme.border),
      ),
      child: InkWell(
        onTap: () => _openFile(task.filePath, context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail with aspect ratio based on ID length or simple variation
            Stack(
              children: [
                AspectRatio(
                  // Variable aspect ratio to give a staggered Pinterest effect
                  aspectRatio: (task.id.hashCode % 2 == 0) ? 16 / 9 : 4 / 3,
                  child: task.thumbnail.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: task.thumbnail,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => Container(color: Colors.white10),
                          errorWidget: (_, _, _) => Container(color: Colors.white10),
                        )
                      : Container(color: Colors.white10),
                ),
                // Heart overlay top-right
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      ref.read(downloadQueueProvider.notifier).toggleFavorite(
                            task.id,
                            false,
                          );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.favorite, color: Colors.redAccent, size: 16),
                    ),
                  ),
                ),
                // Platform overlay bottom-left
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: platformColor.withValues(alpha: 0.5), width: 0.5),
                    ),
                    child: Text(
                      task.platform.toUpperCase(),
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: platformColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  if (task.fileSize > 0)
                    Text(
                      '${(task.fileSize / (1024 * 1024)).toStringAsFixed(1)} MB',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
