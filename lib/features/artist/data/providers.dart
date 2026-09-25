import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/resource.dart';
import '../../../core/providers.dart';
import 'models.dart';

/// My competitions (cached, per account).
final participationsProvider = StreamProvider.autoDispose<Resource<List<Participation>>>((ref) {
  if (ref.watch(currentUserProvider) == null) return Stream.value(const Resource(data: []));
  return watchResource(
    ref.watch(apiClientProvider),
    '/me/participations',
    (json) => [for (final p in ((json! as Map<String, dynamic>)['data'] as List<dynamic>)) Participation.fromJson(p as Map<String, dynamic>)],
  );
});

final journeyProvider = StreamProvider.autoDispose.family<Resource<Journey>, String>((ref, slug) => watchResource(
      ref.watch(apiClientProvider),
      '/me/participations/$slug',
      (json) => Journey.fromJson(json! as Map<String, dynamic>),
    ));
