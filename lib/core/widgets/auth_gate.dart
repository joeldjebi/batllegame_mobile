import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/tokens.dart';
import 'app_button.dart';

/// Runs [action] only for a signed-in user with a verified phone (votes, likes);
/// otherwise explains why in a sheet and offers the way in.
Future<void> requireVerifiedUser(BuildContext context, WidgetRef ref, {required String reason, required VoidCallback action}) async {
  final user = ref.read(currentUserProvider);
  if (user != null && user.phoneVerified) {
    action();
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(user == null ? AppIcons.profile : AppIcons.unverified, size: 36, color: sheet.colors.accent),
            const SizedBox(height: Space.md),
            Text(user == null ? 'Connecte-toi pour $reason' : 'Vérifie ton numéro pour $reason',
                textAlign: TextAlign.center, style: sheet.text.titleLarge),
            const SizedBox(height: Space.sm),
            Text(
              user == null ? 'Un compte gratuit suffit : ton numéro et un mot de passe.' : 'Un code à 6 chiffres t\'est envoyé par SMS : un vote par personne.',
              textAlign: TextAlign.center,
              style: sheet.text.bodyMedium?.copyWith(color: sheet.colors.textMuted),
            ),
            const SizedBox(height: Space.xl),
            if (user == null) ...[
              AppButton(label: 'Créer un compte', onPressed: () => _go(sheet, context, '/auth/inscription')),
              const SizedBox(height: Space.md),
              AppButton(label: 'Se connecter', variant: AppButtonVariant.secondary, onPressed: () => _go(sheet, context, '/auth/connexion')),
            ] else
              AppButton(label: 'Vérifier mon numéro', onPressed: () => _go(sheet, context, '/auth/verification')),
          ],
        ),
      ),
    ),
  );
}

void _go(BuildContext sheet, BuildContext context, String path) {
  Navigator.pop(sheet);
  context.push(path);
}
