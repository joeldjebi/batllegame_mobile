import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/offline_banner.dart';

/// Jury space: its own light, calm theme (phase 4 fills it).
class JuryHomeScreen extends StatelessWidget {
  const JuryHomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.jury(),
    child: Builder(
      builder: (context) => Scaffold(
        body: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(Space.gutter, MediaQuery.paddingOf(context).top + Space.lg, Space.sm, 0),
                      child: Row(
                        children: [
                          Expanded(child: Text('Espace jury', style: context.text.headlineMedium)),
                          TextButton.icon(
                            onPressed: () => context.go('/profil'),
                            icon: const Icon(AppIcons.back, size: 18),
                            label: const Text('Quitter'),
                          ),
                        ],
                      ),
                    ),
                    const Expanded(
                      child: EmptyState(
                        icon: AppIcons.jury,
                        title: 'Tes compétitions à noter',
                        message: 'La liste des prestations à noter arrive bientôt.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
