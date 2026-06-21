import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clip_fusion/providers/download_provider.dart';
import 'package:clip_fusion/theme/theme.dart';
import 'package:clip_fusion/theme/dynamic_color_helper.dart';

class FloatingIsland extends ConsumerStatefulWidget {
  const FloatingIsland({super.key});

  @override
  ConsumerState<FloatingIsland> createState() => _FloatingIslandState();
}

class _FloatingIslandState extends ConsumerState<FloatingIsland> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final queueState = ref.watch(downloadQueueProvider);
    final activeDownloads = queueState.downloads
        .where((t) => t.status == 'DOWNLOADING' || t.status == 'PENDING')
        .toList();

    if (activeDownloads.isEmpty) {
      return const SizedBox.shrink();
    }

    final primaryActive = activeDownloads.first;
    final platformColor = DynamicColorHelper.getPlatformColor(primaryActive.platform);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.fastOutSlowIn,
      top: 16,
      left: _isExpanded ? 16 : (MediaQuery.of(context).size.width - 240) / 2,
      right: _isExpanded ? 16 : (MediaQuery.of(context).size.width - 240) / 2,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        child: Material(
          color: Colors.transparent,
          child: GlassCard(
            borderRadius: 24,
            opacity: 0.12,
            blur: 20,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              child: _isExpanded
                  ? _buildExpandedQueue(activeDownloads, context)
                  : _buildCollapsedCapsule(primaryActive, platformColor),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedCapsule(DownloadTask task, Color platformColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Pulsing Neon indicator
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: platformColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: platformColor.withValues(alpha: 0.6),
                blurRadius: 8,
                spreadRadius: 2,
              )
            ],
          ),
        ),
        const SizedBox(width: 10),
        // Mini Progress & Speed
        Text(
          '${task.progress}%',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Container(
          width: 1,
          height: 12,
          color: Colors.white24,
        ),
        const SizedBox(width: 8),
        Text(
          task.speed.isNotEmpty ? task.speed : 'Loading...',
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
        if (task.eta.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(
            '(${task.eta})',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ]
      ],
    );
  }

  Widget _buildExpandedQueue(List<DownloadTask> activeList, BuildContext context) {
    final theme = Theme.of(context);
    final notifier = ref.read(downloadQueueProvider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud_download, color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Active Queue (${activeList.length})',
                  style: theme.textTheme.labelLarge?.copyWith(fontSize: 15),
                ),
              ],
            ),
            const Icon(Icons.keyboard_arrow_up, color: Colors.grey, size: 20),
          ],
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 250),
          child: ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: activeList.length,
            separatorBuilder: (_, _) => const Divider(color: Colors.white12, height: 16),
            itemBuilder: (context, index) {
              final task = activeList[index];
              final accentColor = DynamicColorHelper.getPlatformColor(task.platform);

              return Row(
                children: [
                  // Circular Glowing Progress
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: task.progress / 100.0,
                        strokeWidth: 3,
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                      ),
                      Text(
                        '${task.progress}%',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Title and details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              task.speed,
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            if (task.eta.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              const Text('•', style: TextStyle(fontSize: 10, color: Colors.white24)),
                              const SizedBox(width: 8),
                              Text(
                                'ETA ${task.eta}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ]
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Control Buttons (Pause / Cancel)
                  IconButton(
                    icon: Icon(
                      task.status == 'DOWNLOADING' ? Icons.pause_circle_outline : Icons.play_circle_outline,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: () {
                      if (task.status == 'DOWNLOADING') {
                        notifier.pauseDownload(task.id);
                      } else {
                        notifier.resumeDownload(task);
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 24),
                    onPressed: () => notifier.cancelDownload(task.id),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
