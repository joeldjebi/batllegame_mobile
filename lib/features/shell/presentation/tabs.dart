import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/empty_state.dart';

/// Profil: account, phone verification, jury space, sign-out.
class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final c = context.colors;
    if (user == null) {
      return const SafeArea(
        child: SignInPrompt(
          icon: AppIcons.profile,
          title: 'Ton profil',
          message: 'Crée ton compte en 30 secondes pour voter et participer.',
        ),
      );
    }

    return SafeArea(
      child: RefreshIndicator(
        color: c.primary,
        onRefresh: () => ref.read(sessionProvider.notifier).refresh().catchError((Object _) {}),
        child: ListView(
          padding: const EdgeInsets.all(Space.gutter),
          children: [
            const SizedBox(height: Space.lg),
            Center(
              child: Avatar(name: user.name, url: user.avatarUrl, size: 88),
            ),
            const SizedBox(height: Space.md),
            Text(user.name, textAlign: TextAlign.center, style: context.text.headlineSmall),
            const SizedBox(height: Space.xs),
            Text(
              user.phone,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(color: c.textMuted),
            ),
            if (user.locationLabel != null) Text(user.locationLabel!, textAlign: TextAlign.center, style: context.text.bodySmall),
            const SizedBox(height: Space.xl),
            if (!user.phoneVerified) ...[
              _Card(
                icon: AppIcons.unverified,
                iconColor: c.warning,
                title: 'Numéro non vérifié',
                message: 'Vérifie ton numéro pour pouvoir voter et liker.',
                action: AppButton(label: 'Vérifier mon numéro', onPressed: () => context.push('/auth/verification')),
              ),
              const SizedBox(height: Space.md),
            ],
            if (user.isJudge) ...[
              _Card(
                icon: AppIcons.jury,
                iconColor: c.accent,
                title: 'Espace jury',
                message: 'Note les prestations des compétitions où tu es juré.',
                action: AppButton(
                  label: 'Ouvrir l\'espace jury',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => context.go('/jury'),
                ),
              ),
              const SizedBox(height: Space.md),
            ],
            const SizedBox(height: Space.lg),
            AppButton(
              label: 'Modifier mon profil',
              variant: AppButtonVariant.secondary,
              icon: AppIcons.edit,
              onPressed: () => context.push('/profil/modifier'),
            ),
            const SizedBox(height: Space.md),
            AppButton(
              label: 'Mes compétitions',
              variant: AppButtonVariant.secondary,
              icon: AppIcons.trophy,
              onPressed: () => context.go('/publier'),
            ),
            const SizedBox(height: Space.md),
            AppButton(
              label: 'Réglages',
              variant: AppButtonVariant.secondary,
              icon: AppIcons.settings,
              onPressed: () => context.push('/reglages'),
            ),
            const SizedBox(height: Space.md),
            AppButton(
              label: 'Changer de mot de passe',
              variant: AppButtonVariant.secondary,
              icon: AppIcons.password,
              onPressed: () => context.push('/auth/mot-de-passe'),
            ),
            const SizedBox(height: Space.md),
            AppButton(
              label: 'Se déconnecter',
              variant: AppButtonVariant.danger,
              icon: AppIcons.logout,
              onPressed: () => ref.read(sessionProvider.notifier).logout(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.icon, required this.iconColor, required this.title, required this.message, required this.action});

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: Space.sm),
              Text(title, style: context.text.titleMedium),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text(message, style: context.text.bodyMedium?.copyWith(color: c.textMuted)),
          const SizedBox(height: Space.md),
          action,
        ],
      ),
    );
  }
}

/// For guests: what they get with an account, and the two ways in.
class SignInPrompt extends StatelessWidget {
  const SignInPrompt({super.key, required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: icon,
    title: title,
    message: message,
    action: Column(
      children: [
        AppButton(label: 'Créer un compte', onPressed: () => context.push('/auth/inscription')),
        const SizedBox(height: Space.md),
        AppButton(label: 'Se connecter', variant: AppButtonVariant.secondary, onPressed: () => context.push('/auth/connexion')),
      ],
    ),
  );
}
