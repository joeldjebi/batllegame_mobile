import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme/tokens.dart';

/// An image kept on disk by key (posters, photos): instant and available offline
/// once seen. Decoded at display size (memory stays low in long lists).
class CachedImage extends ConsumerStatefulWidget {
  const CachedImage({super.key, required this.cacheKey, required this.url, this.fit = BoxFit.cover, this.placeholder});

  final String cacheKey;
  final String? url;
  final BoxFit fit;
  final Widget? placeholder;

  @override
  ConsumerState<CachedImage> createState() => _CachedImageState();
}

class _CachedImageState extends ConsumerState<CachedImage> {
  File? _file;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CachedImage old) {
    super.didUpdateWidget(old);
    if (old.cacheKey != widget.cacheKey) {
      _file = null;
      _load();
    }
  }

  Future<void> _load() async {
    final cache = ref.read(mediaCacheProvider);
    final file = await cache.file(widget.cacheKey) ?? (widget.url == null ? null : await cache.fetch(widget.cacheKey, widget.url!));
    if (mounted && file != null) setState(() => _file = file);
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = widget.placeholder ?? const SizedBox.expand();
    final file = _file;
    if (file == null) return placeholder;
    return LayoutBuilder(
      builder: (context, box) => Image.file(
        file,
        fit: widget.fit,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: box.maxWidth.isFinite ? (box.maxWidth * MediaQuery.devicePixelRatioOf(context)).round() : null,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => placeholder,
        frameBuilder: (_, child, frame, sync) => sync
            ? child
            : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: Motion.base, child: child),
      ),
    );
  }
}
