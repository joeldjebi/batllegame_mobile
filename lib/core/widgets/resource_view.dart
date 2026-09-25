import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/resource.dart';
import '../theme/app_icons.dart';
import 'app_button.dart';
import 'empty_state.dart';
import 'skeleton.dart';

/// Loading → data (possibly the local copy) → error only when nothing is known.
class ResourceView<T> extends StatelessWidget {
  const ResourceView({super.key, required this.value, required this.builder, required this.onRetry, this.loading});

  final AsyncValue<Resource<T>> value;
  final Widget Function(T data, Resource<T> resource) builder;
  final VoidCallback onRetry;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    final resource = value.valueOrNull;
    final data = resource?.data;
    if (data != null) return builder(data, resource!);
    if (resource?.error != null) {
      return EmptyState(
        icon: AppIcons.offline,
        title: 'Contenu indisponible',
        message: resource!.error!.message,
        action: AppButton(label: 'Réessayer', expand: false, onPressed: onRetry),
      );
    }
    return loading ?? const SkeletonList();
  }
}
