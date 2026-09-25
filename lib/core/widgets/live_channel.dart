import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../realtime/realtime_client.dart';

/// Listens to a public realtime channel (competition.{id}) while this screen is shown:
/// its data reloads on each change.
class LiveChannel extends ConsumerStatefulWidget {
  const LiveChannel({super.key, required this.channel, required this.child});

  final String channel;
  final Widget child;

  @override
  ConsumerState<LiveChannel> createState() => _LiveChannelState();
}

class _LiveChannelState extends ConsumerState<LiveChannel> {
  // Kept from the start: `ref` cannot be used any more in dispose().
  late final RealtimeClient _client = ref.read(realtimeClientProvider);

  @override
  void initState() {
    super.initState();
    _client.watch(widget.channel);
  }

  @override
  void didUpdateWidget(LiveChannel old) {
    super.didUpdateWidget(old);
    if (old.channel != widget.channel) {
      _client
        ..unwatch(old.channel)
        ..watch(widget.channel);
    }
  }

  @override
  void dispose() {
    _client.unwatch(widget.channel);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
