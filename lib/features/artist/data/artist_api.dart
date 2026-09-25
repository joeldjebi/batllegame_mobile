import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../auth/data/models.dart';

/// Artist writes that need the network at once (not queued): registering,
/// paying, updating the profile.
class ArtistApi {
  const ArtistApi(this._api);

  final ApiClient _api;

  /// → status (`paiement_en_attente` when there is a fee), payment_required, amount, currency.
  Future<Map<String, dynamic>> register(String slug, String stageName) async =>
      (await _api.post('/competitions/$slug/registrations', data: {'stage_name': stageName})).json;

  /// Simulated until the Mobile Money provider is plugged in (402 = refused).
  Future<Map<String, dynamic>> pay(String slug, String method) async =>
      (await _api.post('/competitions/$slug/payment', data: {'method': method})).json['data'] as Map<String, dynamic>;

  Future<User> updateProfile({required String name, File? photo}) async {
    final response = await _api.post('/auth/profile', data: FormData.fromMap({
      'name': name,
      if (photo != null) 'photo': await MultipartFile.fromFile(photo.path, filename: photo.path.split('/').last),
    }));
    return User.fromJson(response.json['data'] as Map<String, dynamic>);
  }
}
