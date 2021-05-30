/// This class exposes a singleton logger via [log].
///
/// The singleton logger is initialized as follows:
///
/// - If the build system logger is defined, that logger is used.
/// - Otherwise, create a new Logger named 'package:code_excerpter'
///

import 'dart:async';

import 'package:logging/logging.dart';

// Singleton logger
late final Logger log = () {
  // Use build logger if there is one:
  var logger = Zone.current[_buildLogKey] as Logger?;

  if (logger == null) {
    logger = _default;
    Logger.root.level = initLevel;
    Logger.root.onRecord.listen((record) {
      for (final listener in logListeners) {
        listener(record);
      }
    });
  }
  return logger;
}();

const _buildLogKey = #buildLog;
final _default = Logger('package:code_excerpter');

/// Initial logging level. It must be set before calling [log].
const Level initLevel = Level.FINE;

//---------------------------------------------------------

typedef LogListener = void Function(LogRecord);

final List<LogListener> logListeners = [
  printLogRecord,
];

void printLogRecord(LogRecord r) => print('${r.level.name}: ${r.message}');
