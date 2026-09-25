import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';

/// Discreet strip under the status bar while the server is unreachable: the app keeps
/// working on its local copy, actions are queued.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(networkStatusProvider);
    final pending = ref.watch(pendingActionsProvider).valueOrNull ?? 0;
    final c = context.colors;

    return AnimatedSize(
      duration: context.motion(Motion.base),
      curve: Motion.enter,
      child: online
          ? const SizedBox(width: double.infinity)
          : Semantics(
              liveRegion: true,
              child: Container(
                width: double.infinity,
                color: c.surfaceRaised,
                padding: EdgeInsets.fromLTRB(Space.lg, MediaQuery.paddingOf(context).top + Space.sm, Space.lg, Space.sm),
                child: Row(
                  children: [
                    Icon(AppIcons.offline, size: 16, color: c.warning),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Text(
                        pending > 0
                            ? 'Hors ligne · $pending action(s) seront envoyées au retour du réseau'
                            : 'Hors ligne · affichage des données enregistrées',
                        style: context.text.labelSmall?.copyWith(color: c.text),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
