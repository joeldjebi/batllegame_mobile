import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/tokens.dart';
import '../data/models.dart';

/// Phone number with its country (flag + prefix, picked in a sheet). Countries come
/// from the API and stay available offline.
class PhoneField extends ConsumerWidget {
  const PhoneField({
    super.key,
    required this.controller,
    required this.country,
    required this.onCountry,
    this.error,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final Country? country;
  final ValueChanged<Country> onCountry;
  final String? error;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final resource = ref.watch(countriesProvider).valueOrNull;
    final countries = resource?.data ?? const <Country>[];
    final unavailable = countries.isEmpty && resource != null && !resource.refreshing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Numéro de téléphone', style: context.text.labelMedium?.copyWith(color: c.textMuted)),
        const SizedBox(height: Space.sm),
        TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.telephoneNumberNational],
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')), LengthLimitingTextInputFormatter(16)],
          onSubmitted: onSubmitted,
          style: context.text.bodyLarge,
          decoration: InputDecoration(
            hintText: country?.phoneExample ?? '07 00 00 00 00',
            errorText: error,
            prefixIcon: Semantics(
              button: true,
              label: 'Pays : ${country?.name ?? 'choisir'}',
              child: InkWell(
                borderRadius: BorderRadius.circular(Radii.md),
                onTap: countries.length < 2 ? null : () => _pick(context, countries),
                child: Padding(
                  padding: const EdgeInsets.only(left: Space.md, right: Space.sm),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _IsoBadge(country?.iso2 ?? '··'),
                      const SizedBox(width: Space.xs),
                      Text(country?.dialCode ?? '+', style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                      if (countries.length > 1) Icon(AppIcons.expand, size: 16, color: c.textMuted),
                      const SizedBox(width: Space.xs),
                      Container(width: 1, height: 22, color: c.border),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (unavailable)
          Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: Row(
              children: [
                Icon(AppIcons.offline, size: 14, color: c.warning),
                const SizedBox(width: Space.xs),
                Expanded(child: Text('Liste des pays indisponible : vérifie ta connexion.', style: context.text.bodySmall)),
                TextButton(onPressed: () => ref.invalidate(countriesProvider), child: const Text('Réessayer')),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _pick(BuildContext context, List<Country> countries) async {
    final picked = await showModalBottomSheet<Country>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final item in countries)
              ListTile(
                leading: _IsoBadge(item.iso2),
                title: Text(item.name),
                trailing: Text(item.dialCode, style: context.text.bodyMedium?.copyWith(color: context.colors.textMuted)),
                selected: item.id == country?.id,
                onTap: () => Navigator.pop(context, item),
              ),
          ],
        ),
      ),
    );
    if (picked != null) onCountry(picked);
  }
}

/// The default country: Côte d'Ivoire when active, else the first one.
Country? defaultCountry(List<Country> countries) => countries.where((c) => c.iso2 == 'CI').firstOrNull ?? countries.firstOrNull;

/// Country code chip (« CI »): readable everywhere, unlike flag emojis that some
/// devices and simulators fail to draw.
class _IsoBadge extends StatelessWidget {
  const _IsoBadge(this.iso2);

  final String iso2;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(Radii.sm),
      border: Border.all(color: context.colors.border),
    ),
    child: Text(
      iso2.toUpperCase(),
      style: context.text.labelSmall?.copyWith(color: context.colors.textMuted, letterSpacing: 0.5),
    ),
  );
}
