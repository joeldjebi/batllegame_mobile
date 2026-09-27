import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/labels.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/toast.dart';

/// Réglages: data saver for videos, space used on the phone, version.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int? _bytes;

  @override
  void initState() {
    super.initState();
    _measure();
  }

  Future<void> _measure() async {
    final bytes = await ref.read(mediaCacheProvider).size();
    if (mounted) setState(() => _bytes = bytes);
  }

  String get _size => _bytes == null ? '…' : '${(_bytes! / 1024 / 1024).toStringAsFixed(_bytes! > 100 * 1024 * 1024 ? 0 : 1).replaceAll('.', ',')} Mo';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final mode = ref.watch(prefetchModeProvider);
    const options = [
      (mode: PrefetchMode.wifi, title: 'En Wi-Fi seulement', subtitle: 'Recommandé : les vidéos suivantes se préparent en Wi-Fi ; celles que tu regardes restent sur le téléphone pour les revoir sans recharger.'),
      (mode: PrefetchMode.always, title: 'Toujours', subtitle: 'Défilement le plus fluide, consomme des données mobiles.'),
      (mode: PrefetchMode.never, title: 'Jamais', subtitle: 'Économie maximale : rien n\'est gardé, chaque vidéo se recharge à chaque lecture.'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(
        padding: const EdgeInsets.all(Space.gutter),
        children: [
          Text('Apparence', style: context.text.titleMedium),
          const SizedBox(height: Space.sm),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: ThemeMode.light, label: Text('Clair')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Sombre')),
                ButtonSegment(value: ThemeMode.system, label: Text('Système')),
              ],
              selected: {ref.watch(themeModeProvider)},
              onSelectionChanged: (value) => ref.read(themeModeProvider.notifier).set(value.first),
            ),
          ),
          const SizedBox(height: Space.xs),
          Text('Le fil vidéo reste sur fond noir pour mieux regarder les prestations.', style: context.text.bodySmall),
          const SizedBox(height: Space.xl),
          Text('Disciplines préférées', style: context.text.titleMedium),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final d in const ['rap', 'chant', 'freestyle', 'slam', 'beatbox', 'autre'])
                FilterChip(
                  label: Text(Labels.discipline(d)),
                  selected: ref.watch(favoriteDisciplinesProvider).contains(d),
                  onSelected: (_) => ref.read(favoriteDisciplinesProvider.notifier).toggle(d),
                ),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text('Leurs compétitions passent en premier dans Battles et Découvrir.', style: context.text.bodySmall),
          const SizedBox(height: Space.xl),
          Text('Qualité vidéo', style: context.text.titleMedium),
          const SizedBox(height: Space.sm),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<VideoQuality>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: VideoQuality.auto, label: Text('Auto')),
                ButtonSegment(value: VideoQuality.hd, label: Text('HD')),
                ButtonSegment(value: VideoQuality.eco, label: Text('Économie')),
              ],
              selected: {ref.watch(videoQualityProvider)},
              onSelectionChanged: (value) => ref.read(videoQualityProvider.notifier).set(value.first),
            ),
          ),
          const SizedBox(height: Space.xs),
          Text(
            switch (ref.watch(videoQualityProvider)) {
              VideoQuality.auto => 'HD en Wi-Fi, version légère en données mobiles : la vidéo démarre vite partout.',
              VideoQuality.hd => 'Toujours la meilleure qualité, même en données mobiles (consomme plus).',
              VideoQuality.eco => 'Toujours la version légère : moins de données, image un peu moins nette.',
            },
            style: context.text.bodySmall,
          ),
          const SizedBox(height: Space.xl),
          Text('Préchargement des vidéos', style: context.text.titleMedium),
          const SizedBox(height: Space.sm),
          RadioGroup<PrefetchMode>(
            groupValue: mode,
            onChanged: (value) => value == null ? null : ref.read(prefetchModeProvider.notifier).set(value),
            child: Column(
              children: [
                for (final option in options)
                  Container(
                    margin: const EdgeInsets.only(bottom: Space.sm),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(Radii.md),
                      border: Border.all(color: option.mode == mode ? c.primary : c.border, width: option.mode == mode ? 2 : 1),
                    ),
                    child: RadioListTile<PrefetchMode>(
                      value: option.mode,
                      activeColor: c.primary,
                      title: Text(option.title, style: context.text.titleSmall),
                      subtitle: Text(option.subtitle, style: context.text.bodySmall),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Space.xl),
          Text('Stockage', style: context.text.titleMedium),
          const SizedBox(height: Space.sm),
          Container(
            padding: const EdgeInsets.all(Space.lg),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: c.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Vidéos et images enregistrées : $_size', style: context.text.bodyLarge),
                const SizedBox(height: Space.xs),
                Text('Elles permettent de regarder hors ligne et sans attendre. Les plus anciennes sont effacées au-delà de 500 Mo.', style: context.text.bodySmall),
                const SizedBox(height: Space.md),
                AppButton(
                  label: 'Libérer de l\'espace',
                  variant: AppButtonVariant.secondary,
                  onPressed: _bytes == 0
                      ? null
                      : () async {
                          await ref.read(mediaCacheProvider).clear();
                          await _measure();
                          if (context.mounted) showToast(context, 'Espace libéré.');
                        },
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.xxl),
          Center(child: Text('${Env.appName} · version ${Env.version}', style: context.text.bodySmall)),
        ],
      ),
    );
  }
}
