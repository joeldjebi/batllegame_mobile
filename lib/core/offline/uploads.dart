import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../config/env.dart';
import '../storage/token_store.dart';

enum UploadPhase { queued, running, waitingNetwork, done, failed }

/// One performance being sent (what the journey shows under a stage).
class UploadState {
  const UploadState({required this.id, required this.target, required this.label, required this.phase, this.progress = 0, this.error});

  final String id;

  /// What it is for: `preselection:{slug}` or `stage:{slug}:{stageId}`.
  final String target;
  final String label;
  final UploadPhase phase;
  final double progress;
  final String? error;

  bool get active => phase == UploadPhase.queued || phase == UploadPhase.running || phase == UploadPhase.waitingNetwork;

  UploadState copyWith({UploadPhase? phase, double? progress, String? error}) =>
      UploadState(id: id, target: target, label: label, phase: phase ?? this.phase, progress: progress ?? this.progress, error: error ?? this.error);
}

/// Background uploads of performances: handed to the system (they go on with the
/// app closed and retry after a network loss), with their progress. The file is
/// first copied into the app's own space (the picker's temporary files may vanish).
class UploadCenter extends StateNotifier<Map<String, UploadState>> {
  UploadCenter({required TokenStore tokens, FileDownloader? downloader, this.onFinished})
      : _tokens = tokens,
        _downloader = downloader ?? FileDownloader(),
        super(const {});

  final TokenStore _tokens;
  final FileDownloader _downloader;

  /// A performance was received by the server (refresh the journey of [target]).
  final void Function(String target)? onFinished;
  StreamSubscription<TaskUpdate>? _updates;

  static const String group = 'submissions';

  Future<void> start() async {
    _downloader.configureNotification(
      running: const TaskNotification('Envoi de ta prestation', '{displayName} · {progress}'),
      complete: const TaskNotification('Prestation envoyée', '{displayName} : en cours de vérification.'),
      error: const TaskNotification('Envoi interrompu', '{displayName} : ouvre l\'app pour réessayer.'),
      progressBar: true,
    );
    _updates = _downloader.updates.listen(_onUpdate);
    // Tasks sent before the app was closed: back in the list, status caught up.
    await _downloader.start(markDownloadedComplete: false);
    final records = await _downloader.database.allRecordsWithStatus(TaskStatus.running, group: group)
      ..addAll(await _downloader.database.allRecordsWithStatus(TaskStatus.enqueued, group: group))
      ..addAll(await _downloader.database.allRecordsWithStatus(TaskStatus.waitingToRetry, group: group));
    for (final record in records) {
      final meta = _meta(record.task);
      state = {...state, record.taskId: UploadState(id: record.taskId, target: meta.target, label: meta.label, phase: UploadPhase.running, progress: record.progress.clamp(0, 1))};
    }
  }

  /// Sends [file] to the API [path] (multipart « media »). Returns the task id.
  Future<String> send({required File file, required String path, required String target, required String label, DateTime? modifiedAt}) async {
    final id = const Uuid().v4();
    final extension = file.path.contains('.') ? file.path.substring(file.path.lastIndexOf('.')) : '.mp4';
    final directory = Directory('${(await getApplicationDocumentsDirectory()).path}/uploads');
    await directory.create(recursive: true);
    final filename = '$id$extension';
    await file.copy('${directory.path}/$filename');

    final task = UploadTask(
      taskId: id,
      url: '${Env.apiBase}$path',
      filename: filename,
      directory: 'uploads',
      baseDirectory: BaseDirectory.applicationDocuments,
      fileField: 'media',
      fields: {if (modifiedAt != null) 'client_modified_at': '${modifiedAt.millisecondsSinceEpoch}'},
      headers: {
        'Accept': 'application/json',
        'Accept-Language': 'fr',
        if (_tokens.token != null) 'Authorization': 'Bearer ${_tokens.token}',
        // Several tries of one upload replace the same performance once.
        'Idempotency-Key': id,
      },
      group: group,
      updates: Updates.statusAndProgress,
      retries: 5,
      displayName: label,
      metaData: jsonEncode({'target': target, 'label': label}),
    );
    state = {...state, id: UploadState(id: id, target: target, label: label, phase: UploadPhase.queued)};
    if (!await _downloader.enqueue(task)) {
      state = {...state, id: state[id]!.copyWith(phase: UploadPhase.failed, error: 'Impossible de lancer l\'envoi.')};
    }
    return id;
  }

  Future<void> dismiss(String id) async {
    state = {...state}..remove(id);
    await _downloader.database.deleteRecordWithId(id);
  }

  void _onUpdate(TaskUpdate update) {
    if (update.task.group != group) return;
    final current = state[update.task.taskId] ??
        UploadState(id: update.task.taskId, target: _meta(update.task).target, label: _meta(update.task).label, phase: UploadPhase.queued);

    switch (update) {
      case TaskProgressUpdate(:final progress):
        if (progress >= 0) state = {...state, current.id: current.copyWith(phase: UploadPhase.running, progress: progress)};
      case TaskStatusUpdate(:final status):
        state = {...state, current.id: _applyStatus(current, update, status)};
    }
  }

  UploadState _applyStatus(UploadState current, TaskStatusUpdate update, TaskStatus status) {
    switch (status) {
      case TaskStatus.complete:
        final code = update.responseStatusCode ?? 200;
        _cleanup(update.task);
        if (code >= 400) return current.copyWith(phase: UploadPhase.failed, error: _message(update.responseBody) ?? 'Envoi refusé.');
        onFinished?.call(current.target);
        return current.copyWith(phase: UploadPhase.done, progress: 1);
      case TaskStatus.waitingToRetry:
        // A refusal (validation, closed period…) will not change by retrying: stop and say why.
        final code = update.responseStatusCode;
        if (code != null && code >= 400 && code < 500 && code != 408 && code != 429) {
          unawaited(_downloader.cancelTaskWithId(update.task.taskId));
          _cleanup(update.task);
          return current.copyWith(phase: UploadPhase.failed, error: _message(update.responseBody) ?? 'Envoi refusé.');
        }
        return current.copyWith(phase: UploadPhase.waitingNetwork);
      case TaskStatus.canceled when current.phase == UploadPhase.failed:
        return current;
      case TaskStatus.failed || TaskStatus.notFound || TaskStatus.canceled:
        _cleanup(update.task);
        return current.copyWith(
          phase: UploadPhase.failed,
          error: _message(update.responseBody) ?? (update.exception is TaskConnectionException ? 'Pas de connexion : réessaie.' : 'Envoi interrompu : réessaie.'),
        );
      case TaskStatus.running || TaskStatus.enqueued:
        return current.copyWith(phase: UploadPhase.running);
      case TaskStatus.paused:
        return current.copyWith(phase: UploadPhase.waitingNetwork);
    }
  }

  Future<void> _cleanup(Task task) async {
    try {
      await File(await task.filePath()).delete();
    } catch (_) {}
  }

  static ({String target, String label}) _meta(Task task) {
    try {
      final json = jsonDecode(task.metaData) as Map<String, dynamic>;
      return (target: json['target'] as String, label: json['label'] as String);
    } catch (_) {
      return (target: '', label: task.displayName);
    }
  }

  static String? _message(String? body) {
    if (body == null || body.isEmpty) return null;
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final errors = json['errors'];
      if (errors is Map && errors.isNotEmpty && errors.values.first is List) return '${(errors.values.first as List).first}';
      return json['message'] as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _updates?.cancel();
    super.dispose();
  }
}
