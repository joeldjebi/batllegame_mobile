import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import 'app_button.dart';

/// After a vote: a short check animation, then « Merci » with a way to share the
/// artist's battle (a shared link brings them more votes). Offline: the vote is
/// queued, the sheet says so.
Future<void> celebrateVote(BuildContext context, {required String artist, required String competition, required String shareUrl, bool offline = false}) async {
  unawaited(HapticFeedback.heavyImpact());
  if (!context.reduceMotion) {
    unawaited(
      showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black26,
        transitionDuration: Duration.zero,
        pageBuilder: (dialog, _, _) => const _VoteBurst(),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(offline ? AppIcons.pending : AppIcons.done, size: 40, color: offline ? sheet.colors.warning : sheet.colors.success),
            const SizedBox(height: Space.md),
            Text(offline ? 'Vote en attente' : 'Merci pour ton vote', textAlign: TextAlign.center, style: sheet.text.titleLarge),
            const SizedBox(height: Space.xs),
            Text(
              offline
                  ? 'Ton vote pour $artist sera envoyé dès le retour du réseau.'
                  : 'Ton vote pour $artist compte. Partage sa battle : chaque voix peut faire la différence.',
              textAlign: TextAlign.center,
              style: sheet.text.bodyMedium?.copyWith(color: sheet.colors.textMuted),
            ),
            const SizedBox(height: Space.xl),
            AppButton(
              label: 'Partager pour soutenir $artist',
              icon: AppIcons.share,
              onPressed: () async {
                Navigator.pop(sheet);
                await SharePlus.instance.share(ShareParams(text: 'Vote pour $artist dans « $competition » sur Battle Game : $shareUrl'));
              },
            ),
            const SizedBox(height: Space.md),
            AppButton(label: 'Continuer', variant: AppButtonVariant.secondary, onPressed: () => Navigator.pop(sheet)),
          ],
        ),
      ),
    ),
  );
}

/// A check that pops in with a ring expanding around it (solid colors, no gradient).
class _VoteBurst extends StatefulWidget {
  const _VoteBurst();

  @override
  State<_VoteBurst> createState() => _VoteBurstState();
}

class _VoteBurstState extends State<_VoteBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.colors.primary;
    return Semantics(
      liveRegion: true,
      label: 'Vote enregistré',
      child: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final pop = Curves.elasticOut.transform((_c.value * 1.4).clamp(0, 1));
            final ring = Curves.easeOut.transform(_c.value);
            return SizedBox.square(
              dimension: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: (1 - ring).clamp(0, 1),
                    child: Container(
                      width: 90 + 90 * ring,
                      height: 90 + 90 * ring,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 4 * (1 - ring) + 1),
                      ),
                    ),
                  ),
                  Transform.scale(
                    scale: 0.4 + 0.6 * pop,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      child: const Icon(AppIcons.done, color: Colors.white, size: 46),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
