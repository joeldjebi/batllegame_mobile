import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/labels.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/toast.dart';
import '../../competitions/data/models.dart';
import '../../competitions/data/providers.dart';
import '../data/artist_api.dart';
import '../data/providers.dart';

final artistApiProvider = Provider<ArtistApi>((ref) => ArtistApi(ref.watch(apiClientProvider)));

/// « Participer »: stage name, then the payment when there is a fee, then the journey.
Future<void> startRegistration(BuildContext context, WidgetRef ref, CompetitionDetail competition) async {
  final user = ref.read(currentUserProvider);
  if (user == null) {
    await context.push('/auth/connexion');
    return;
  }
  final registered = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _RegisterSheet(competition: competition, defaultName: user.name),
  );
  if (registered != true || !context.mounted) return;
  ref.invalidate(participationsProvider);
  await context.push(competition.entryFee > 0 ? '/competitions/${competition.slug}/paiement' : '/competitions/${competition.slug}/parcours');
}

class _RegisterSheet extends ConsumerStatefulWidget {
  const _RegisterSheet({required this.competition, required this.defaultName});

  final CompetitionDetail competition;
  final String defaultName;

  @override
  ConsumerState<_RegisterSheet> createState() => _RegisterSheetState();
}

class _RegisterSheetState extends ConsumerState<_RegisterSheet> {
  late final _name = TextEditingController(text: widget.defaultName);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Choisis ton nom de scène.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(artistApiProvider).register(widget.competition.slug, _name.text.trim());
      unawaited(HapticFeedback.mediumImpact());
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() => _error = e.fieldErrors['stage_name'] ?? e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final competition = widget.competition;
    return Padding(
      padding: EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, MediaQuery.viewInsetsOf(context).bottom + Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Participer à ${competition.name}', textAlign: TextAlign.center, style: context.text.titleLarge),
          const SizedBox(height: Space.xs),
          Text(
            competition.entryFee > 0 ? 'Frais d\'inscription : ${Labels.money(competition.entryFee, competition.currency)}' : 'Inscription gratuite',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(color: context.colors.textMuted),
          ),
          const SizedBox(height: Space.xl),
          AppTextField(label: 'Nom de scène', controller: _name, error: _error, autofocus: true, textInputAction: TextInputAction.done, onSubmitted: (_) => _submit()),
          const SizedBox(height: Space.xl),
          AppButton(label: competition.entryFee > 0 ? 'Continuer vers le paiement' : 'M\'inscrire', loading: _busy, onPressed: _submit),
        ],
      ),
    );
  }
}

const _methods = [
  (value: 'orange_money', label: 'Orange Money', detail: 'Paiement depuis ton numéro Orange'),
  (value: 'mtn_momo', label: 'MTN Mobile Money', detail: 'Paiement depuis ton numéro MTN'),
  (value: 'moov_money', label: 'Moov Money', detail: 'Paiement depuis ton numéro Moov'),
  (value: 'wave', label: 'Wave', detail: 'Paiement depuis ton compte Wave'),
  (value: 'carte', label: 'Carte bancaire', detail: 'Visa ou Mastercard'),
];

/// Entry fee (simulated until the Mobile Money provider is connected).
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  String _method = _methods.first.value;
  bool _busy = false;

  Future<void> _pay() async {
    setState(() => _busy = true);
    try {
      await ref.read(artistApiProvider).pay(widget.slug, _method);
      unawaited(HapticFeedback.heavyImpact());
      ref
        ..invalidate(journeyProvider(widget.slug))
        ..invalidate(participationsProvider);
      if (!mounted) return;
      showToast(context, 'Paiement reçu. Inscription confirmée.');
      context.pushReplacement('/competitions/${widget.slug}/parcours');
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.statusCode == 402 ? 'Paiement refusé : réessaie ou choisis un autre moyen.' : e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final competition = ref.watch(competitionProvider(widget.slug)).valueOrNull?.data;
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Paiement')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Space.gutter),
          children: [
            Text(competition?.name ?? '', style: context.text.titleMedium?.copyWith(color: c.textMuted)),
            const SizedBox(height: Space.xs),
            Text(competition == null ? '…' : Labels.money(competition.entryFee, competition.currency), style: context.text.displaySmall),
            Text('Frais d\'inscription', style: context.text.bodyMedium?.copyWith(color: c.textMuted)),
            const SizedBox(height: Space.xl),
            Text('Moyen de paiement', style: context.text.titleMedium),
            const SizedBox(height: Space.md),
            RadioGroup<String>(
              groupValue: _method,
              onChanged: (value) => setState(() => _method = value ?? _method),
              child: Column(
                children: [
                  for (final method in _methods)
                    Container(
                      margin: const EdgeInsets.only(bottom: Space.sm),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(Radii.md),
                        border: Border.all(color: method.value == _method ? c.primary : c.border, width: method.value == _method ? 2 : 1),
                      ),
                      child: RadioListTile<String>(
                        value: method.value,
                        activeColor: c.primary,
                        title: Text(method.label, style: context.text.titleSmall),
                        subtitle: Text(method.detail, style: context.text.bodySmall),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Space.lg),
            AppButton(label: competition == null ? 'Payer' : 'Payer ${Labels.money(competition.entryFee, competition.currency)}', loading: _busy, onPressed: _pay),
            const SizedBox(height: Space.md),
            Text('Paiement de test : aucun montant n\'est réellement débité pour le moment.', textAlign: TextAlign.center, style: context.text.bodySmall),
          ],
        ),
      ),
    );
  }
}
