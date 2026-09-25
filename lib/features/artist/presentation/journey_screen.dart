import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/offline/uploads.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/labels.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/resource_view.dart';
import '../../../core/widgets/status_chip.dart';
import '../data/models.dart';
import '../data/providers.dart';
import '../data/reminders.dart';
import 'submit_sheet.dart';

String performanceLabel(String status) => switch (status) {
      'traitement' => 'Vérification en cours',
      'en_attente' => 'En attente de validation',
      'validee' => 'Validée',
      'rejetee' => 'Refusée',
      _ => status,
    };

ChipTone performanceTone(String status) => switch (status) {
      'validee' => ChipTone.success,
      'rejetee' => ChipTone.danger,
      _ => ChipTone.info,
    };

/// The upload line of a target: while sending or refused, and once sent until the server gives its status.
UploadState? visibleUpload(Map<String, UploadState> uploads, String target, SubmittedMedia? submission) {
  final upload = uploads.values.where((u) => u.target == target).lastOrNull;
  if (upload == null || upload.active || upload.phase == UploadPhase.failed) return upload;
  return submission == null || submission.status == 'traitement' ? upload : null;
}

/// « Mon parcours »: where I stand in a competition and the one thing to do next.
class JourneyScreen extends ConsumerStatefulWidget {
  const JourneyScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends ConsumerState<JourneyScreen> {
  Timer? _poll;

  String get slug => widget.slug;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  /// While the server checks a performance (« traitement »), look again every 5 s.
  void _pollWhileChecking(Journey journey) {
    final checking = [
      journey.preselection?.entry,
      for (final phase in journey.phases)
        for (final stage in phase.stages) stage.submission,
    ].any((s) => s?.status == 'traitement');
    if (checking && _poll == null) {
      _poll = Timer.periodic(const Duration(seconds: 5), (_) => ref.invalidate(journeyProvider(slug)));
    } else if (!checking && _poll != null) {
      _poll!.cancel();
      _poll = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(journeyProvider(slug), (_, next) {
      final resource = next.valueOrNull;
      final journey = resource?.data;
      if (journey == null) return;
      _pollWhileChecking(journey);
      // Fresh dates from the server: reminders follow them.
      // A reminder is a bonus: its failure (permission, platform) never reaches the screen.
      if (!resource!.refreshing && resource.error == null) unawaited(ReminderScheduler(ref.read(localNotifierProvider)).sync(journey).catchError((Object _) {}));
    });
    // A performance of mine reached the server: its new status.
    ref.listen<String?>(lastUploadDoneProvider, (_, done) {
      if (done != null && done.contains(slug)) ref.invalidate(journeyProvider(slug));
    });
    final uploads = ref.watch(uploadsProvider);
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(title: const Text('Mon parcours')),
      body: ResourceView(
        value: ref.watch(journeyProvider(slug)),
        onRetry: () => ref.invalidate(journeyProvider(slug)),
        builder: (journey, _) => RefreshIndicator(
          color: c.primary,
          onRefresh: () async => ref.invalidate(journeyProvider(slug)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxxl),
            children: [
              Text(journey.competitionName, style: context.text.titleMedium?.copyWith(color: c.textMuted)),
              const SizedBox(height: Space.md),
              _Hero(journey: journey),
              if (journey.paymentRequired) ...[
                const SizedBox(height: Space.md),
                _Notice(
                  icon: AppIcons.payment,
                  title: 'Inscription à régler',
                  message: 'Ta participation compte une fois les frais payés.',
                  action: AppButton(label: 'Payer mon inscription', onPressed: () => context.push('/competitions/$slug/paiement')),
                ),
              ] else if (journey.awaitsApproval) ...[
                const SizedBox(height: Space.md),
                const _Notice(icon: AppIcons.pending, title: 'Inscription en attente', message: 'L\'organisateur valide ton inscription : tu pourras ensuite envoyer ta prestation.'),
              ],
              if (journey.preselection != null) ...[
                const SizedBox(height: Space.xl),
                _PreselectionCard(slug: slug, journey: journey, preselection: journey.preselection!, uploads: uploads),
              ],
              for (final phase in journey.phases) ...[
                const SizedBox(height: Space.xl),
                _PhaseCard(slug: slug, journey: journey, phase: phase, uploads: uploads),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends ConsumerWidget {
  const _Hero({required this.journey});

  final Journey journey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final user = ref.watch(currentUserProvider);
    final next = journey.effectiveNext;
    final (Color bg, String title) = journey.champion
        ? (c.warning, 'Vainqueur de la compétition')
        : journey.out
            ? (c.surfaceRaised, 'Parcours terminé')
            : (c.primary, next?.stage ?? 'En attente de la suite');
    final onBg = journey.out ? c.text : Colors.white;

    return Container(
      padding: const EdgeInsets.all(Space.xl),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.xl)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(name: journey.stageName, url: user?.avatarUrl, size: 48),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(journey.stageName, style: context.text.bodyMedium?.copyWith(color: onBg.withValues(alpha: 0.8))),
                    Text(title, style: context.text.headlineSmall?.copyWith(color: onBg)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          Text(
            journey.out
                ? 'Merci pour ta participation. Tes résultats restent disponibles ci-dessous.'
                : next?.text ?? 'Rien à faire pour le moment : tu seras prévenu dès que la prochaine étape commence.',
            style: context.text.bodyLarge?.copyWith(color: onBg),
          ),
          if (next?.deadline != null && !journey.out) ...[
            const SizedBox(height: Space.md),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(Radii.md)),
              child: Text('Échéance ${Labels.remaining(next!.deadline!)} · ${Labels.date(next.deadline)}', style: context.text.labelMedium?.copyWith(color: onBg)),
            ),
          ],
          if (next?.type == 'vote' && next?.matchId != null && !journey.out) ...[
            const SizedBox(height: Space.lg),
            AppButton(
              label: 'Voir mon match et partager',
              variant: AppButtonVariant.secondary,
              icon: AppIcons.share,
              onPressed: () => context.push('/competitions/${journey.slug}/matchs/${next!.matchId}'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.title, required this.message, this.action});

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: c.warning.withValues(alpha: 0.5))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: c.warning), const SizedBox(width: Space.sm), Expanded(child: Text(title, style: context.text.titleMedium))]),
          const SizedBox(height: Space.xs),
          Text(message, style: context.text.bodyMedium?.copyWith(color: c.textMuted)),
          if (action != null) ...[const SizedBox(height: Space.md), action!],
        ],
      ),
    );
  }
}

class _PreselectionCard extends ConsumerWidget {
  const _PreselectionCard({required this.slug, required this.journey, required this.preselection, required this.uploads});

  final String slug;
  final Journey journey;
  final JourneyPreselection preselection;
  final Map<String, UploadState> uploads;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = preselection.entry;
    final target = 'preselection:$slug';
    final upload = visibleUpload(uploads, target, entry);
    final (String resultLabel, ChipTone tone) = preselection.published
        ? (preselection.selected == true ? ('Sélectionné${preselection.rank == null ? '' : ' · ${preselection.rank}e'}', ChipTone.success) : ('Non retenu', ChipTone.danger))
        : (_stateLabel(preselection.state), ChipTone.info);

    return _Section(
      icon: AppIcons.preselection,
      title: 'Présélection',
      subtitle: [
        if (preselection.endsAt != null) 'Envois jusqu\'au ${Labels.date(preselection.endsAt)}',
        '${preselection.selectionSize} artistes retenus',
      ].join(' · '),
      trailing: StatusChip(resultLabel, tone: tone),
      children: [
        if (entry != null) _Submitted(submission: entry, extra: entry.likes == null ? null : '${entry.likes} like(s)'),
        if (upload != null) _UploadProgress(upload: upload),
        if (preselection.canSubmit && upload?.active != true) ...[
          const SizedBox(height: Space.md),
          AppButton(
            label: entry == null ? 'Envoyer ma prestation' : 'Remplacer ma prestation',
            icon: AppIcons.video,
            variant: entry == null ? AppButtonVariant.primary : AppButtonVariant.secondary,
            onPressed: () => submitPerformance(
              context,
              ref,
              rules: preselection.rules,
              path: '/competitions/$slug/preselection/submission',
              target: target,
              label: 'Présélection · ${journey.competitionName}',
            ),
          ),
          const SizedBox(height: Space.xs),
          Text(preselection.rules.summary, style: context.text.bodySmall),
        ],
      ],
    );
  }

  static String _stateLabel(String state) => switch (state) {
        'programmee' => 'Bientôt',
        'ouverte' => 'Envois ouverts',
        'vote' => 'Vote du public',
        'deliberation' => 'Délibération du jury',
        'cloturee' => 'Résultats bientôt',
        _ => state,
      };
}

class _PhaseCard extends ConsumerWidget {
  const _PhaseCard({required this.slug, required this.journey, required this.phase, required this.uploads});

  final String slug;
  final Journey journey;
  final JourneyPhase phase;
  final Map<String, UploadState> uploads;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return _Section(
      icon: AppIcons.trophy,
      title: phase.title,
      subtitle: [
        phase.online ? 'En ligne : vidéo à envoyer à chaque étape' : 'Sur scène',
        if (phase.qualifiersPerGroup != null) '${phase.qualifiersPerGroup} qualifié(s) par poule',
      ].join(' · '),
      children: [
        if (phase.stages.isEmpty) Text('Le programme de cette phase sera communiqué à son démarrage.', style: context.text.bodyMedium?.copyWith(color: c.textMuted)),
        for (final stage in phase.stages) _StageRow(slug: slug, journey: journey, stage: stage, uploads: uploads),
      ],
    );
  }
}

class _StageRow extends ConsumerWidget {
  const _StageRow({required this.slug, required this.journey, required this.stage, required this.uploads});

  final String slug;
  final Journey journey;
  final JourneyStage stage;
  final Map<String, UploadState> uploads;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final (Color dot, ChipTone tone) = switch (stage.state) {
      'won' || 'done' => (c.success, ChipTone.success),
      'current' => (c.primary, ChipTone.live),
      'waiting' => (c.warning, ChipTone.info),
      'lost' => (c.danger, ChipTone.danger),
      _ => (c.textMuted, ChipTone.neutral),
    };
    final target = 'stage:$slug:${stage.id}';
    final upload = visibleUpload(uploads, target, stage.submission);

    return Opacity(
      opacity: stage.state == 'skipped' ? 0.55 : 1,
      child: Container(
        margin: const EdgeInsets.only(top: Space.md),
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(
          color: stage.state == 'current' ? c.primary.withValues(alpha: 0.08) : null,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: stage.state == 'current' ? c.primary.withValues(alpha: 0.5) : c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                const SizedBox(width: Space.sm),
                Expanded(child: Text(stage.name, style: context.text.titleSmall)),
                Flexible(child: StatusChip(stage.label, tone: tone)),
              ],
            ),
            if (stage.submissionDeadline != null || stage.votingClosesAt != null) ...[
              const SizedBox(height: Space.xs),
              Text(
                [
                  if (stage.submissionDeadline != null) 'Envoi avant le ${Labels.date(stage.submissionDeadline)}',
                  if (stage.votingClosesAt != null) 'Vote jusqu\'au ${Labels.date(stage.votingClosesAt)}',
                ].join(' · '),
                style: context.text.bodySmall,
              ),
            ],
            if (stage.matchId != null) ...[
              const SizedBox(height: Space.sm),
              InkWell(
                onTap: () => context.push('/competitions/$slug/matchs/${stage.matchId}'),
                child: Row(
                  children: [
                    if (stage.isGroup) ...[
                      Text('${stage.matchTitle} · ', style: context.text.bodyMedium),
                      Expanded(child: Text('toi + ${stage.others.length} artiste(s)', style: context.text.bodySmall)),
                    ] else if (stage.others.isNotEmpty) ...[
                      Text('Face à ', style: context.text.bodySmall),
                      Avatar(name: stage.others.first.name, url: stage.others.first.avatarUrl, size: 22),
                      const SizedBox(width: Space.xs),
                      Expanded(child: Text(stage.others.first.name, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                    ] else
                      Expanded(child: Text('Adversaire à déterminer', style: context.text.bodySmall)),
                    if (stage.myScore != null) Text('${stage.myScore!.toStringAsFixed(1).replaceAll('.', ',')} / 100', style: context.text.titleSmall),
                    Icon(AppIcons.forward, color: c.textMuted, size: 18),
                  ],
                ),
              ),
            ],
            if (stage.submission != null) _Submitted(submission: stage.submission!),
            if (upload != null) _UploadProgress(upload: upload),
            if (stage.canSubmit && upload?.active != true) ...[
              const SizedBox(height: Space.md),
              AppButton(
                label: stage.action?.type == 'sent' ? 'Remplacer ma prestation' : 'Envoyer ma prestation',
                icon: AppIcons.video,
                variant: stage.action?.type == 'sent' ? AppButtonVariant.secondary : AppButtonVariant.primary,
                onPressed: () => submitPerformance(
                  context,
                  ref,
                  rules: stage.rules!,
                  path: '/competitions/$slug/stages/${stage.id}/submission',
                  target: target,
                  label: '${stage.name} · ${journey.competitionName}',
                ),
              ),
              const SizedBox(height: Space.xs),
              Text(stage.rules!.summary, style: context.text.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _Submitted extends StatelessWidget {
  const _Submitted({required this.submission, this.extra});

  final SubmittedMedia submission;
  final String? extra;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(AppIcons.playOutline, size: 18, color: c.accent),
                const SizedBox(width: Space.xs),
                Text('Ma prestation', style: context.text.bodyMedium),
              ]),
              StatusChip(performanceLabel(submission.status), tone: performanceTone(submission.status)),
              if (extra != null) Text(extra!, style: context.text.bodySmall),
            ],
          ),
          if (submission.rejectionReason != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: Text('Motif : ${submission.rejectionReason}', style: context.text.bodySmall?.copyWith(color: c.danger)),
            ),
        ],
      ),
    );
  }
}

class _UploadProgress extends ConsumerWidget {
  const _UploadProgress({required this.upload});

  final UploadState upload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final (String text, Color color) = switch (upload.phase) {
      UploadPhase.queued => ('Envoi en préparation…', c.textMuted),
      UploadPhase.running => ('Envoi en cours · ${(upload.progress * 100).round()} %', c.accent),
      UploadPhase.waitingNetwork => ('En attente du réseau : l\'envoi reprendra tout seul', c.warning),
      UploadPhase.done => ('Envoyée : vérification en cours', c.success),
      UploadPhase.failed => (upload.error ?? 'Envoi interrompu', c.danger),
    };
    return Padding(
      padding: const EdgeInsets.only(top: Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (upload.active)
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.pill),
              child: LinearProgressIndicator(value: upload.phase == UploadPhase.running ? upload.progress : null, minHeight: 6),
            ),
          const SizedBox(height: Space.xs),
          Row(
            children: [
              Expanded(child: Text(text, style: context.text.bodySmall?.copyWith(color: color))),
              if (!upload.active)
                IconButton(
                  tooltip: 'Masquer',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(AppIcons.close, size: 18, color: c.textMuted),
                  onPressed: () => ref.read(uploadsProvider.notifier).dismiss(upload.id),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.subtitle, required this.children, this.trailing});

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: c.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: c.accent),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    Text(subtitle, style: context.text.bodySmall),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          ...children,
        ],
      ),
    );
  }
}
