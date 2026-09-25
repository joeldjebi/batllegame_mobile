import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/toast.dart';
import '../data/models.dart';
import 'auth_scaffold.dart';
import 'phone_field.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  Country? _country;
  bool _busy = false;
  Map<String, String> _errors = const {};

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final country = _country;
    if (country == null) return;
    final errors = {
      if (_name.text.trim().isEmpty) 'name': 'Saisis ton nom.',
      if (_phone.text.trim().isEmpty) 'phone': 'Saisis ton numéro.',
      if (_password.text.length < 8) 'password': '8 caractères minimum.',
    };
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(sessionProvider.notifier)
          .register(name: _name.text.trim(), countryId: country.id, phone: _phone.text.trim(), password: _password.text);
      if (mounted) context.go('/auth/verification');
    } on ApiException catch (e) {
      setState(() => _errors = e.fieldErrors);
      if (e.fieldErrors.isEmpty && mounted) showToast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final countries = ref.watch(countriesProvider).valueOrNull?.data ?? const <Country>[];
    _country ??= defaultCountry(countries);

    return AuthScaffold(
      title: 'Rejoins la battle',
      subtitle: 'Un compte pour voter, liker et participer aux compétitions.',
      footer: TextButton(
        onPressed: () => context.pushReplacement('/auth/connexion'),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Déjà un compte ? ',
                style: TextStyle(color: context.colors.textMuted),
              ),
              TextSpan(
                text: 'Se connecter',
                style: TextStyle(color: context.colors.accent, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
      children: [
        AutofillGroup(
          child: Column(
            children: [
              AppTextField(
                label: 'Nom',
                controller: _name,
                error: _errors['name'],
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
              ),
              const SizedBox(height: Space.lg),
              PhoneField(
                controller: _phone,
                country: _country,
                onCountry: (c) => setState(() => _country = c),
                error: _errors['phone'],
              ),
              const SizedBox(height: Space.lg),
              AppTextField(
                label: 'Mot de passe',
                controller: _password,
                obscure: true,
                error: _errors['password'],
                helper: '8 caractères minimum.',
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.xl),
        AppButton(label: 'Créer mon compte', loading: _busy, onPressed: _country == null ? null : _submit),
        const SizedBox(height: Space.md),
        Text('Tu recevras un code par SMS pour vérifier ton numéro.', textAlign: TextAlign.center, style: context.text.bodySmall),
      ],
    );
  }
}
