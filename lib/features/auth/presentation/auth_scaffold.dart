import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/logo.dart';
import '../../../core/widgets/offline_banner.dart';

/// Layout of the sign-in screens: logo, title, the form, the footer link.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.title, this.subtitle, required this.children, this.footer, this.canClose = true});

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? footer;
  final bool canClose;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: SafeArea(
              top: false,
              child: CustomScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      Space.gutter,
                      MediaQuery.paddingOf(context).top + Space.md,
                      Space.gutter,
                      Space.xl,
                    ),
                    sliver: SliverList.list(
                      children: [
                        Row(
                          children: [
                            const Logo(size: 30),
                            const Spacer(),
                            if (canClose)
                              IconButton(
                                tooltip: 'Fermer',
                                onPressed: () => context.canPop() ? context.pop() : context.go('/'),
                                icon: Icon(AppIcons.close, color: c.textMuted),
                              ),
                          ],
                        ),
                        const SizedBox(height: Space.xxl),
                        Text(title, style: context.text.headlineMedium),
                        if (subtitle != null) ...[
                          const SizedBox(height: Space.sm),
                          Text(subtitle!, style: context.text.bodyLarge?.copyWith(color: c.textMuted)),
                        ],
                        const SizedBox(height: Space.xxl),
                        ...children,
                      ],
                    ),
                  ),
                  if (footer != null)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(padding: const EdgeInsets.all(Space.lg), child: footer),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
