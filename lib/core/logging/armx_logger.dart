// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../config/app_config.dart';
import 'log_redactor.dart';

/// One captured log line, kept in memory for the Diagnostics screen.
@immutable
class LogRecord {
  /// Creates a captured record.
  const LogRecord({
    required this.time,
    required this.level,
    required this.message,
  });

  /// When the line was produced.
  final DateTime time;

  /// Severity name (`info`, `error`, …).
  final String level;

  /// Already-redacted message, including any error text.
  final String message;
}

/// Fixed-size ring buffer of recent log lines.
///
/// Used by Settings → Diagnostics so a field engineer can read the last lines without
/// attaching a debugger. Contents are always redacted.
class LogRingBuffer {
  /// Creates a buffer holding at most [capacity] records.
  LogRingBuffer({this.capacity = 400});

  /// Maximum number of records retained.
  final int capacity;

  final List<LogRecord> _records = <LogRecord>[];

  /// Records currently held, oldest first.
  List<LogRecord> get records => List<LogRecord>.unmodifiable(_records);

  /// Appends a record, dropping the oldest one when full.
  void add(LogRecord record) {
    _records.add(record);
    if (_records.length > capacity) {
      _records.removeRange(0, _records.length - capacity);
    }
  }

  /// Removes every record.
  void clear() => _records.clear();
}

/// `LogPrinter` that redacts before printing and mirrors output into a [LogRingBuffer].
class ArmxLogPrinter extends LogPrinter {
  /// Creates a printer. Pass [buffer] to capture lines for the in-app log viewer.
  ArmxLogPrinter({this.buffer, this.colors = true, this.includeTimestamp = true});

  /// Optional in-memory sink.
  final LogRingBuffer? buffer;

  /// Whether ANSI colours are emitted (debug consoles only).
  final bool colors;

  /// Whether each line is prefixed with an ISO-8601 timestamp.
  final bool includeTimestamp;

  static const Map<Level, String> _labels = <Level, String>{
    Level.trace: 'TRACE',
    Level.debug: 'DEBUG',
    Level.info: 'INFO ',
    Level.warning: 'WARN ',
    Level.error: 'ERROR',
    Level.fatal: 'FATAL',
  };

  static const Map<Level, String> _colors = <Level, String>{
    Level.trace: '\u001b[90m',
    Level.debug: '\u001b[36m',
    Level.info: '\u001b[32m',
    Level.warning: '\u001b[33m',
    Level.error: '\u001b[31m',
    Level.fatal: '\u001b[35m',
  };

  @override
  List<String> log(LogEvent event) {
    final label = _labels[event.level] ?? 'INFO ';
    final stamp = includeTimestamp ? '${event.time.toIso8601String()} ' : '';
    final safeMessage = LogRedactor.redact(event.message.toString());
    final rawError = event.error?.toString();
    final safeError = rawError == null ? '' : ' | ${LogRedactor.redact(rawError)}';
    final line = '$stamp$label $safeMessage$safeError';
    final coloured = colors && !kIsWeb ? '${_colors[event.level]}$line\u001b[0m' : line;

    buffer?.add(
      LogRecord(
        time: event.time,
        level: (event.level.name).toUpperCase(),
        message: '$safeMessage$safeError',
      ),
    );

    final lines = <String>[coloured];
    final trace = event.stackTrace;
    if (trace != null && event.level.index >= Level.error.index) {
      // Stack traces occasionally embed payloads; redact them too.
      lines.addAll(
        trace.toString().split('\n').take(12).map((row) => '    ${LogRedactor.redact(row)}'),
      );
    }
    return lines;
  }
}

/// Keeps only events at or above a configured level.
class LevelLogFilter extends LogFilter {
  /// Creates a filter for [level].
  const LevelLogFilter(this.level);

  /// Minimum level that passes.
  final AppLogLevel level;

  @override
  bool shouldLog(LogEvent event) => switch (level) {
        AppLogLevel.off => false,
        AppLogLevel.trace => true,
        AppLogLevel.debug => event.level.index >= Level.debug.index,
        AppLogLevel.info => event.level.index >= Level.info.index,
        AppLogLevel.warning => event.level.index >= Level.warning.index,
        AppLogLevel.error => event.level.index >= Level.error.index,
      };
}

/// Factory for the app-wide [Logger].
abstract final class ArmxLogging {
  /// Creates a redacting logger for the given [level].
  ///
  /// [buffer] is only retained in debug/profile builds so release builds cannot be
  /// inspected through the Diagnostics screen.
  static Logger create(AppLogLevel level, {LogRingBuffer? buffer}) {
    final effectiveBuffer = kReleaseMode ? null : buffer;
    return Logger(
      filter: LevelLogFilter(level),
      printer: ArmxLogPrinter(buffer: effectiveBuffer, colors: !kReleaseMode),
      output: ConsoleOutput(),
    );
  }
}
