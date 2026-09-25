import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/env.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';

/// One realtime signal: something changed, the app reloads it through the API.
class RealtimeEvent {
  const RealtimeEvent({required this.channel, required this.type, this.competitionId, this.matchId, this.message});

  factory RealtimeEvent.fromJson(Map<dynamic, dynamic> json) {
    final data = json['data'] is Map ? json['data'] as Map : const <dynamic, dynamic>{};
    return RealtimeEvent(
      channel: '${json['channel']}',
      type: '${json['type']}',
      competitionId: data['competition_id'] is int ? data['competition_id'] as int : null,
      matchId: data['match_id'] is int ? data['match_id'] as int : null,
      message: json['message'] as String?,
    );
  }

  final String channel;
  final String type;
  final int? competitionId;
  final int? matchId;

  /// French text meant for a notification (null for bare signals).
  final String? message;

  bool get isPersonal => channel.startsWith('user.');

  bool get isJury => channel.startsWith('jury.');
}

/// Socket.IO connection of the app: a signed token from GET /realtime for the private
/// channels (user.{id}, jury.competition.{id}), public channels of the screens shown
/// (competition.{id}), automatic reconnection and token renewal before it expires.
class RealtimeClient {
  RealtimeClient(this._api);

  final ApiClient _api;
  final _events = StreamController<RealtimeEvent>.broadcast();
  final Map<String, int> _watched = {};
  final Set<String> _private = {};
  io.Socket? _socket;
  String? _token;
  Timer? _renew;
  bool _signedIn = false;

  Stream<RealtimeEvent> get events => _events.stream;

  bool get connected => _socket?.connected ?? false;

  /// Signed in: personal channel + [privateChannels] (jury). Guests: public channels only.
  Future<void> start({required bool signedIn, Set<String> privateChannels = const {}}) async {
    _signedIn = signedIn;
    _private
      ..clear()
      ..addAll(privateChannels);
    await _connect();
  }

  Future<void> _connect() async {
    _renew?.cancel();
    var url = Env.apiUrl;
    _token = null;
    if (_signedIn) {
      try {
        final channels = [..._private, ..._watched.keys];
        final json = (await _api.get('/realtime', query: {if (channels.isNotEmpty) 'channels[]': channels})).json;
        if (json['enabled'] != true) return;
        url = (json['url'] as String?) ?? url;
        _token = json['token'] as String?;
        final ttl = (json['expires_in'] as int?) ?? 3600;
        // Renew a little before the token expires (reconnections need a valid one).
        _renew = Timer(Duration(seconds: (ttl * 0.9).round()), _connect);
      } on ApiException {
        _renew = Timer(const Duration(minutes: 1), _connect);
        return;
      }
    }

    if (_socket == null) {
      final socket = io.io(
        url,
        // forceNew: the client caches one manager per URL; after stop() (sign-out, account
        // switch) a cached, disposed one would never reconnect.
        io.OptionBuilder()
            .setTransports(['websocket'])
            .enableForceNew()
            .disableAutoConnect()
            .enableReconnection()
            .setReconnectionDelay(2000)
            .setReconnectionDelayMax(30000)
            .build(),
      );
      socket
        ..onConnect((_) => _subscribe())
        ..on('update', (data) {
          if (data is Map) _events.add(RealtimeEvent.fromJson(data));
        });
      _socket = socket..connect();
    } else if (_socket!.connected) {
      _subscribe();
    } else {
      _socket!.connect();
    }
  }

  void _subscribe() => _socket?.emit('subscribe', {'channels': _watched.keys.toList(), 'token': ?_token});

  /// A screen shows [channel] (competition.{id}): listen while at least one does.
  void watch(String channel) {
    _watched[channel] = (_watched[channel] ?? 0) + 1;
    if (_watched[channel] == 1) _subscribe();
  }

  void unwatch(String channel) {
    final count = (_watched[channel] ?? 1) - 1;
    if (count > 0) {
      _watched[channel] = count;
      return;
    }
    _watched.remove(channel);
    _socket?.emit('unsubscribe', {'channels': [channel]});
  }

  void stop() {
    _renew?.cancel();
    _socket?.dispose();
    _socket = null;
    _token = null;
  }

  void dispose() {
    stop();
    _events.close();
  }
}
