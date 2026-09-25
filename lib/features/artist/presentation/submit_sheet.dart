import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/toast.dart';
import '../data/models.dart';

/// Film or pick the performance, check it against the rules on the phone (no
/// useless upload), then send it in the background.
Future<void> submitPerformance(
  BuildContext context,
  WidgetRef ref, {
  required MediaRules rules,
  required String path,
  required String target,
  required String label,
}) async {
  if (!rules.acceptsVideo) {
    showToast(context, 'Cette étape attend un fichier audio : envoi depuis le site pour l\'instant.');
    return;
  }
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ta prestation', textAlign: TextAlign.center, style: sheet.text.titleLarge),
            const SizedBox(height: Space.xs),
            Text(rules.summary, textAlign: TextAlign.center, style: sheet.text.bodyMedium?.copyWith(color: sheet.colors.textMuted)),
            const SizedBox(height: Space.xl),
            AppButton(label: 'Filmer maintenant', icon: AppIcons.video, onPressed: () => Navigator.pop(sheet, ImageSource.camera)),
            const SizedBox(height: Space.md),
            AppButton(label: 'Choisir une vidéo', variant: AppButtonVariant.secondary, icon: AppIcons.gallery, onPressed: () => Navigator.pop(sheet, ImageSource.gallery)),
          ],
        ),
      ),
    ),
  );
  if (source == null || !context.mounted) return;

  final XFile? picked;
  try {
    picked = await ImagePicker().pickVideo(source: source, maxDuration: Duration(seconds: rules.maxDurationSeconds));
  } catch (_) {
    if (context.mounted) showToast(context, 'Accès à la caméra ou aux vidéos refusé : autorise-le dans les réglages.');
    return;
  }
  if (picked == null || !context.mounted) return;

  final file = File(picked.path);
  final check = await checkVideo(file, rules);
  if (!context.mounted) return;
  if (check.error != null) {
    showToast(context, check.error!);
    return;
  }

  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(AppIcons.done, size: 40, color: sheet.colors.success),
            const SizedBox(height: Space.md),
            Text('Prête à partir', textAlign: TextAlign.center, style: sheet.text.titleLarge),
            const SizedBox(height: Space.xs),
            Text(
              '${check.duration == null ? '' : '${_clock(check.duration!)} · '}${(check.bytes / 1024 / 1024).toStringAsFixed(1).replaceAll('.', ',')} Mo\n'
              'L\'envoi continue même si tu fermes l\'app.',
              textAlign: TextAlign.center,
              style: sheet.text.bodyMedium?.copyWith(color: sheet.colors.textMuted),
            ),
            const SizedBox(height: Space.xl),
            AppButton(label: 'Envoyer ma prestation', onPressed: () => Navigator.pop(sheet, true)),
            const SizedBox(height: Space.sm),
            AppButton(label: 'Choisir une autre vidéo', variant: AppButtonVariant.ghost, onPressed: () => Navigator.pop(sheet, false)),
          ],
        ),
      ),
    ),
  );
  if (confirmed != true || !context.mounted) return;

  await ref.read(uploadsProvider.notifier).send(file: file, path: path, target: target, label: label, modifiedAt: await file.lastModified());
  if (context.mounted) showToast(context, 'Envoi en cours : suis la progression ici.');
}

/// Size and real duration of the file against the rules.
Future<({String? error, Duration? duration, int bytes})> checkVideo(File file, MediaRules rules) async {
  final bytes = await file.length();
  if (bytes > rules.maxSizeMb * 1024 * 1024) {
    return (error: 'Vidéo trop lourde : ${rules.maxSizeMb} Mo maximum.', duration: null, bytes: bytes);
  }
  final player = VideoPlayerController.file(file);
  try {
    await player.initialize();
    final duration = player.value.duration;
    // A little tolerance for encoders rounding the duration (same as the server).
    if (duration.inSeconds > rules.maxDurationSeconds + 2) {
      return (error: 'Vidéo trop longue (${_clock(duration)}) : ${_clock(Duration(seconds: rules.maxDurationSeconds))} maximum.', duration: duration, bytes: bytes);
    }
    return (error: null, duration: duration, bytes: bytes);
  } catch (_) {
    // Unreadable here: the server checks it anyway.
    return (error: null, duration: null, bytes: bytes);
  } finally {
    await player.dispose();
  }
}

String _clock(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
