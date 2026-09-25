import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/toast.dart';
import 'registration.dart';

/// Name and profile photo (the server crops it square, 512 px).
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final _name = TextEditingController(text: ref.read(currentUserProvider)?.name ?? '');
  File? _photo;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 88);
      if (picked != null) setState(() => _photo = File(picked.path));
    } catch (_) {
      if (mounted) showToast(context, 'Accès aux photos refusé : autorise-le dans les réglages.');
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Saisis ton nom.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await ref.read(artistApiProvider).updateProfile(name: _name.text.trim(), photo: _photo);
      await ref.read(sessionProvider.notifier).replaceUser(user);
      if (!mounted) return;
      showToast(context, 'Profil mis à jour.');
      Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() => _error = e.fieldErrors['name'] ?? e.fieldErrors['photo'] ?? e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Space.gutter),
          children: [
            Center(
              child: Semantics(
                button: true,
                label: 'Changer ma photo',
                child: GestureDetector(
                  onTap: () => _pick(ImageSource.gallery),
                  child: Stack(
                    children: [
                      _photo != null
                          ? ClipOval(child: Image.file(_photo!, width: 112, height: 112, fit: BoxFit.cover))
                          : Avatar(name: user?.name ?? '', url: user?.avatarUrl, size: 112),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle, border: Border.all(color: c.background, width: 3)),
                          child: Icon(AppIcons.camera, size: 18, color: c.onPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: Space.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(onPressed: () => _pick(ImageSource.gallery), child: const Text('Galerie')),
                TextButton(onPressed: () => _pick(ImageSource.camera), child: const Text('Appareil photo')),
              ],
            ),
            const SizedBox(height: Space.lg),
            AppTextField(label: 'Nom', controller: _name, error: _error, textInputAction: TextInputAction.done, onSubmitted: (_) => _save()),
            const SizedBox(height: Space.xl),
            AppButton(label: 'Enregistrer', loading: _busy, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
