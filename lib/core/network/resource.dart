import 'api_client.dart';
import 'api_exception.dart';

/// What a screen shows: the data (possibly the local copy), whether a refresh is
/// running, and the last error (the data stays displayed when offline).
class Resource<T> {
  const Resource({this.data, this.refreshing = false, this.error});

  final T? data;
  final bool refreshing;
  final ApiException? error;

  bool get hasData => data != null;

  /// Showing the local copy because the network failed.
  bool get isStale => data != null && error != null;
}

/// Stale-while-revalidate: the local copy at once (no spinner on a known screen),
/// then the server's answer — a 304 costs almost nothing.
Stream<Resource<T>> watchResource<T>(
  ApiClient api,
  String path,
  T Function(Object? json) parse, {
  Map<String, dynamic>? query,
}) async* {
  T? current;
  final local = await api.peek(path, query: query);
  if (local != null) {
    try {
      current = parse(local.data);
    } catch (_) {
      current = null; // Old format after an update: ignore the copy.
    }
  }
  yield Resource(data: current, refreshing: true);

  try {
    final response = await api.get(path, query: query);
    yield Resource(data: parse(response.data));
  } on ApiException catch (error) {
    yield Resource(data: current, error: error);
  }
}
