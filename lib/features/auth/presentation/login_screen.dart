import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  Country? _country;
  bool _busy = false;
  Map<String, String> _errors = const {};

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final country = _country;
    if (country == null) return;
    final errors = {
      if (_phone.text.trim().isEmpty) 'phone': 'Saisis ton numéro.',
      if (_password.text.isEmpty) 'password': 'Saisis ton mot de passe.',
    };
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;

    setState(() => _busy = true);
    try {
      await ref.read(sessionProvider.notifier).login(countryId: country.id, phone: _phone.text.trim(), password: _password.text);
      TextInput.finishAutofillContext();
      if (mounted) context.go('/');
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
      title: 'Content de te revoir',
      subtitle: 'Connecte-toi pour liker, voter et suivre tes compétitions.',
      footer: TextButton(
        onPressed: () => context.pushReplacement('/auth/inscription'),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Pas encore de compte ? ',
                style: TextStyle(color: context.colors.textMuted),
              ),
              TextSpan(
                text: 'Créer un compte',
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
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.xl),
        AppButton(label: 'Se connecter', loading: _busy, onPressed: _country == null ? null : _submit),
      ],
    );
  }
}
