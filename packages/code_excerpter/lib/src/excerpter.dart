import 'directive.dart';
import 'util/line.dart';
import 'util/logging.dart';

/// Key used for excerpt representing the entire file w/o directives
const fullFileKey = '\u0000';
const defaultRegionKey = '';
const defaultPlaster = '···';

class Excerpter {
  final String uri;
  final String content;
  final List<String> _lines; // content as list of lines

  final Map<String, List<String>> excerpts = {};
  final Set<String> _openExcerpts = {};

  // Index of next line to process.
  int _lineIdx;
  int get _lineNum => _lineIdx + 1;
  String get _line => _lines[_lineIdx];

  bool containsDirectives = false;

  int get numExcerpts => excerpts.length;

  Excerpter(this.uri, this.content)
      : _lines = content.split(eol),
        _lineIdx = 0;

  Excerpter weave() {
    final lines = content.split(eol);

    // Collect the full file in case we need it.
    _excerptStart(fullFileKey);

    for (_lineIdx = 0; _lineIdx < lines.length; _lineIdx++) {
      _processLine();
    }

    // Drop trailing blank lines for all excerpts.
    // Normalize indentation for all but the full file.
    for (final entry in excerpts.entries) {
      dropTrailingBlankLines(entry.value);
      _dropTrailingPlaster(entry.value);
      if (entry.key != fullFileKey) {
        excerpts[entry.key] = maxUnindent(entry.value).toList();
      }
    }

    // Final adjustment to excerpts relative to fullFileKey:
    if (!containsDirectives) {
      // No directives? Don't report any excerpts
      excerpts.clear();
    } else if (excerpts.containsKey(defaultRegionKey)) {
      // There was an explicitly named default region. Drop fullFileKey.
      excerpts.remove(fullFileKey);
    } else {
      // Report fullFileKey excerpt for defaultRegionKey
      excerpts[defaultRegionKey] = excerpts.remove(fullFileKey) ?? [];
    }
    return this;
  }

  void _processLine() {
    final directive = Directive.tryParse(_line);

    if (directive == null) {
      // Add line to open regions
      for (final excerptName in _openExcerpts) {
        excerpts[excerptName]?.add(_line);
      }

      return;
    }

    directive.issues.forEach(_warn);

    switch (directive.kind) {
      case Kind.startRegion:
        containsDirectives = true;
        _startRegion(directive);
        break;
      case Kind.endRegion:
        containsDirectives = true;
        _endRegion(directive);
        break;
      default:
        throw Exception('Unimplemented directive: $_line');
    }
  }

  void _startRegion(Directive directive) {
    List<String>? regionAlreadyStarted;

    final regionNames = directive.args;
    log.finer('_startRegion(regionNames = $regionNames)');

    if (regionNames.isEmpty) {
      regionNames.add(defaultRegionKey);
    }

    for (final name in regionNames) {
      final isNew = _excerptStart(name);
      if (!isNew) {
        regionAlreadyStarted ??= [];
        regionAlreadyStarted.add(_quoteName(name));
      }
    }

    _warnRegions(
      regionAlreadyStarted,
      (regions) => 'repeated start for $regions',
    );
  }

  void _endRegion(Directive directive) {
    List<String>? regionsWithoutStart;
    final regionNames = directive.args;
    log.finer('_endRegion(regionNames = $regionNames)');

    if (regionNames.isEmpty) {
      regionNames.add('');
      // _warn('${directive.lexeme} has no explicit arguments; assuming ""');
    }

    for (final name in regionNames) {
      if (_openExcerpts.remove(name)) {
        final excerpt = excerpts[name];
        if (excerpt != null) {
          if (excerpt.isEmpty) {
            _warnRegions(
              [name],
              (regions) => 'empty $regions',
            );
          }

          excerpt.add(directive.indentation + defaultPlaster);
        }
      } else {
        regionsWithoutStart ??= [];
        regionsWithoutStart.add(_quoteName(name));
      }
    }

    _warnRegions(
      regionsWithoutStart,
      (regions) => '$regions end without a prior start',
    );
  }

  void _warnRegions(
    List<String>? _regions,
    String Function(String) msg,
  ) {
    if (_regions == null) return;
    final regions = _regions.join(', ');
    final s = regions.isEmpty
        ? ''
        : _regions.length > 1
            ? 's ($regions)'
            : ' $regions';
    _warn(msg('region$s'));
  }

  /// Registers [name] as an open excerpt.
  ///
  /// If [name] is a new excerpt, then its value in
  /// [excerpts] is set to the empty list.
  ///
  /// Returns false iff name was already open
  bool _excerptStart(String name) {
    excerpts.putIfAbsent(name, () => []);
    return _openExcerpts.add(name);
  }

  void _warn(String msg) => log.warning('$msg at $uri:$_lineNum');

  /// Quote a region name if it isn't already quoted.
  String _quoteName(String name) => name.startsWith("'") ? name : '"$name"';

  void _dropTrailingPlaster(List<String> excerpt) {
    if (excerpt.isEmpty || !excerpt.last.contains(defaultPlaster)) return;
    excerpt.removeLast();
  }
}
