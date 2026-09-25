import 'dart:async';

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
import 'auth_scaffold.dart';

/// 6-digit SMS code: sent on sign-up, required to vote and like.
class VerifyPhoneScreen extends ConsumerStatefulWidget {
  const VerifyPhoneScreen({super.key});

  @override
  ConsumerState<VerifyPhoneScreen> createState() => _VerifyPhoneScreenState();
}

class _VerifyPhoneScreenState extends ConsumerState<VerifyPhoneScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;
  int _cooldown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_cooldown <= 1) t.cancel();
      if (mounted) setState(() => _cooldown--);
    });
  }

  Future<void> _verify() async {
    if (_code.text.length != 6) {
      setState(() => _error = 'Le code contient 6 chiffres.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).verifyCode(_code.text);
      unawaited(HapticFeedback.mediumImpact());
      if (mounted) {
        showToast(context, 'Numéro vérifié.');
        context.go('/');
      }
    } on ApiException catch (e) {
      setState(() => _error = e.fieldErrors['code'] ?? e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    try {
      await ref.read(sessionProvider.notifier).sendCode();
      _startCooldown();
      if (mounted) showToast(context, 'Nouveau code envoyé.');
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = ref.watch(currentUserProvider)?.phone ?? '';

    return AuthScaffold(
      title: 'Vérifie ton numéro',
      subtitle: 'Saisis le code à 6 chiffres envoyé par SMS au $phone.',
      canClose: false,
      footer: TextButton(
        onPressed: () => context.go('/'),
        child: Text('Plus tard', style: TextStyle(color: context.colors.textMuted)),
      ),
      children: [
        AppTextField(
          label: 'Code reçu',
          controller: _code,
          error: _error,
          autofocus: true,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 6,
          textAlign: TextAlign.center,
          style: context.text.headlineSmall?.copyWith(letterSpacing: 12),
          onChanged: (value) {
            if (value.length == 6) _verify();
          },
        ),
        const SizedBox(height: Space.xl),
        AppButton(label: 'Vérifier', loading: _busy, onPressed: _verify),
        const SizedBox(height: Space.md),
        AppButton(
          label: _cooldown > 0 ? 'Renvoyer le code dans $_cooldown s' : 'Renvoyer le code',
          variant: AppButtonVariant.ghost,
          onPressed: _cooldown > 0 ? null : _resend,
        ),
      ],
    );
  }
}
