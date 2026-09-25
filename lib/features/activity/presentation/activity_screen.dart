import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/empty_state.dart';
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
      return const SafeArea(child: SignInPrompt(icon: AppIcons.activity, title: 'Ton activité', message: 'Connecte-toi pour suivre tes votes et tes compétitions.'));
    }
    final c = context.colors;
    final items = ref.watch(activityItemsProvider).valueOrNull ?? const [];
    final queue = ref.watch(outboxProvider).watch();

    return SafeArea(
      bottom: false,
      child: StreamBuilder(
        stream: queue,
        builder: (context, snapshot) {
          final actions = snapshot.data ?? const [];
          if (items.isEmpty && actions.isEmpty) {
            return const EmptyState(icon: AppIcons.activity, title: 'Rien pour le moment', message: 'Validation de tes prestations, votes, résultats : tout arrive ici.');
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, Space.xxl),
            children: [
              Text('Activité', style: context.text.headlineMedium),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: Space.lg),
                Text('En attente d\'envoi', style: context.text.titleMedium),
                const SizedBox(height: Space.sm),
                for (final action in actions)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(action.state == 'failed' ? AppIcons.error : AppIcons.pending, color: action.state == 'failed' ? c.danger : c.warning),
                    title: Text(action.label),
                    subtitle: Text(action.state == 'failed' ? (action.lastError ?? 'Refusé') : 'Sera envoyé au retour du réseau', style: context.text.bodySmall),
                    trailing: action.state == 'failed'
                        ? IconButton(tooltip: 'Retirer', icon: const Icon(AppIcons.close), onPressed: () => ref.read(outboxProvider).discard(action.id))
                        : null,
                  ),
              ],
              if (items.isNotEmpty) ...[
                const SizedBox(height: Space.lg),
                for (final item in items)
                  Container(
                    margin: const EdgeInsets.only(bottom: Space.sm),
                    decoration: BoxDecoration(
                      color: item.read ? c.surface : c.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(Radii.md),
                      border: Border.all(color: item.read ? c.border : c.primary.withValues(alpha: 0.4)),
                    ),
                    child: ListTile(
                      leading: Icon(_icon(item.type), color: c.accent),
                      title: Text(item.message, style: context.text.bodyMedium),
                      subtitle: Text(DateFormat('d MMM · HH:mm', 'fr').format(item.createdAt), style: context.text.bodySmall),
                      trailing: item.link == null ? null : Icon(AppIcons.forward, color: c.textMuted),
                      onTap: item.link == null ? null : () => context.push(item.link!),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  static IconData _icon(String type) => switch (type) {
        final t when t.startsWith('performance') || t.startsWith('preselection') => AppIcons.performance,
        final t when t.startsWith('payment') => AppIcons.payment,
        final t when t.startsWith('match') || t.startsWith('vote') => AppIcons.vote,
        final t when t.startsWith('jury') || t.startsWith('judge') => AppIcons.jury,
        final t when t.startsWith('phase') => AppIcons.trophy,
        _ => AppIcons.activity,
      };
}
