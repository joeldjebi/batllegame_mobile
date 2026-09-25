import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import 'feed_view.dart';

/// Accueil: « Pour toi », playing only while this tab is shown.
class HomeFeedScreen extends ConsumerWidget {
  const HomeFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => FeedView(visible: ref.watch(currentTabProvider) == 0);
}

/// The performances of one competition, full screen (opened from its page).
class CompetitionFeedScreen extends StatelessWidget {
  const CompetitionFeedScreen({super.key, required this.slug, this.title});

  final String slug;
  final String? title;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: FeedView(competition: slug, title: title ?? 'Prestations', visible: true, onBack: () => Navigator.of(context).maybePop()),
      );
}
