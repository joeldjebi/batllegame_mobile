import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/feed/data/feed_item.dart';
import '../theme/app_colors.dart';
import '../theme/tokens.dart';
import 'cached_image.dart';

/// Three columns of vertical posters, the artist on each; a tap plays the video.
class VideoGrid extends StatelessWidget {
  const VideoGrid({super.key, required this.items, this.shrink = false});

  final List<FeedItem> items;
  final bool shrink;

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: shrink,
    physics: shrink ? const NeverScrollableScrollPhysics() : null,
    padding: const EdgeInsets.all(2),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2, childAspectRatio: 0.66),
    itemCount: items.length,
    itemBuilder: (context, i) {
      final item = items[i];
      return GestureDetector(
        onTap: () => context.push('/lecture', extra: (key: item.key, media: item.media, title: item.stageName)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: const Color(0xFF1E1E2A),
              child: item.media.posterUrl == null ? null : CachedImage(cacheKey: '${item.key}-poster', url: item.media.posterUrl),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.black.withValues(alpha: 0.45),
                padding: const EdgeInsets.fromLTRB(Space.sm, Space.xs, Space.sm, Space.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.stageName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      item.competitionName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

