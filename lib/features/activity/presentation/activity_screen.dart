import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/grouped_list.dart';
import '../../shell/presentation/tabs.dart';
import '../data/activity_hub.dart';
import '../data/providers.dart';

/// Activité: my notifications (kept offline) and the actions waiting for the network.
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  late final ActivityHub _hub = ref.read(activityHubProvider);

  @override
  void initState() {
    super.initState();
    _hub; // Resolved while `ref` is usable.
  }

  @override
  void deactivate() {
    // Leaving the tab: what was shown is read.
    _hub.markAllRead();
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(currentUserProvider) == null) {
      return const SafeArea(
        child: SignInPrompt(icon: AppIcons.activity, title: 'Ton activité', message: 'Connecte-toi pour suivre tes votes et tes compétitions.'),
      );
    }
    final c = context.colors;
    final items = ref.watch(activityItemsProvider).valueOrNull ?? const [];
    final queue = ref.watch(outboxProvider).watch();

    return ColoredBox(
      color: groupedBackground(context),
      child: SafeArea(
        bottom: false,
        child: StreamBuilder(
          stream: queue,
          builder: (context, snapshot) {
            final actions = snapshot.data ?? const [];
            return ListView(
              padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xxl),
              children: [
                const LargeTitle('Activité'),
                if (items.isEmpty && actions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: Space.xxxl),
                    child: EmptyState(
                      icon: AppIcons.activity,
                      title: 'Rien pour le moment',
                      message: 'Validation de tes prestations, votes, résultats : tout arrive ici.',
                    ),
                  ),
                if (actions.isNotEmpty)
                  GroupedSection(
                    header: 'En attente d\'envoi',
                    footer: 'Envoyé automatiquement au retour du réseau.',
                    children: [
                      for (final action in actions)
                        GroupedTile(
                          icon: action.state == 'failed' ? AppIcons.error : AppIcons.pending,
                          iconColor: action.state == 'failed' ? c.danger : c.warning,
                          title: action.label,
                          subtitle: action.state == 'failed' ? (action.lastError ?? 'Refusé') : 'En attente du réseau',
                          trailing: action.state == 'failed'
                              ? IconButton(
                                  tooltip: 'Retirer',
                                  visualDensity: VisualDensity.compact,
                                  icon: Icon(AppIcons.close, size: 18, color: c.textMuted),
                                  onPressed: () => ref.read(outboxProvider).discard(action.id),
                                )
                              : null,
                        ),
                    ],
                  ),
                if (items.isNotEmpty)
                  GroupedSection(
                    header: 'Notifications',
                    children: [
                      for (final item in items)
                        GroupedTile(
                          icon: _icon(item.type),
                          iconColor: _color(item.type, c),
                          title: item.message,
                          subtitle: DateFormat('d MMM · HH:mm', 'fr').format(item.createdAt),
                          unread: !item.read,
                          onTap: item.link == null ? null : () => context.push(item.link!),
                        ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  static Color _color(String type, AppColors c) => switch (type) {
    final t when t.startsWith('performance') || t.startsWith('preselection') => c.primary,
    final t when t.startsWith('payment') => c.success,
    final t when t.startsWith('match') || t.startsWith('vote') => c.like,
    final t when t.startsWith('jury') || t.startsWith('judge') => const Color(0xFF0A84FF),
    final t when t.startsWith('phase') => c.warning,
    _ => const Color(0xFF8E8E93),
  };

  static IconData _icon(String type) => switch (type) {
    final t when t.startsWith('performance') || t.startsWith('preselection') => AppIcons.performance,
    final t when t.startsWith('payment') => AppIcons.payment,
    final t when t.startsWith('match') || t.startsWith('vote') => AppIcons.vote,
    final t when t.startsWith('jury') || t.startsWith('judge') => AppIcons.jury,
    final t when t.startsWith('phase') => AppIcons.trophy,
    _ => AppIcons.activity,
  };
}
