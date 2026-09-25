import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/toast.dart';
import 'auth_scaffold.dart';

/// Mandatory for accounts created with a temporary password (judges).
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  Map<String, String> _errors = const {};

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final errors = {
      if (_current.text.isEmpty) 'current_password': 'Saisis le mot de passe reçu.',
      if (_password.text.length < 8) 'password': '8 caractères minimum.',
    };
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;

    setState(() => _busy = true);
    try {
      await ref.read(sessionProvider.notifier).changePassword(current: _current.text, password: _password.text);
      if (mounted) {
        showToast(context, 'Mot de passe modifié.');
        context.go('/');
      }
    } on ApiException catch (e) {
      setState(() => _errors = e.fieldErrors);
      if (e.fieldErrors.isEmpty && mounted) showToast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final forced = ref.watch(currentUserProvider)?.mustChangePassword ?? false;

    return AuthScaffold(
      title: 'Choisis ton mot de passe',
      subtitle: forced ? 'Ton compte a été créé avec un mot de passe provisoire : remplace-le pour continuer.' : null,
      canClose: !forced,
      footer: forced
          ? TextButton(onPressed: () => ref.read(sessionProvider.notifier).logout(), child: const Text('Se déconnecter'))
          : null,
      children: [
        AppTextField(
          label: forced ? 'Mot de passe provisoire' : 'Mot de passe actuel',
          controller: _current,
          obscure: true,
          error: _errors['current_password'],
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.password],
        ),
        const SizedBox(height: Space.lg),
        AppTextField(
          label: 'Nouveau mot de passe',
          controller: _password,
          obscure: true,
          error: _errors['password'],
          helper: '8 caractères minimum, différent du mot de passe provisoire.',
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: Space.xl),
        AppButton(label: 'Enregistrer', loading: _busy, onPressed: _submit),
      ],
    );
  }
}
