// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

const List<String> _requiredStartupStages = <String>[
  'main_enter',
  'widgets_binding_ready',
  'pre_runapp_init_done',
  'runapp_called',
  'first_frame_rasterized',
];

void main(List<String> args) async {
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    _printUsage();
    exit(args.isEmpty ? 1 : 0);
  }

  final wsUrl = args[0];
  var durationSec = 15;
  var humanMode = false;
  var measurementMode = 'attach';
  var rawStartup = false;
  var enableTimeline = false;
  bool? clearInitialTimelineOverride;
  String? vmServiceDiscoveredIso;

  for (var i = 1; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--duration' && i + 1 < args.length) {
      durationSec = int.tryParse(args[i + 1]) ?? 15;
      i++;
      continue;
    }
    if (arg == '--human') {
      humanMode = true;
      continue;
    }
    if (arg == '--json') {
      humanMode = false;
      continue;
    }
    if (arg == '--mode' && i + 1 < args.length) {
      measurementMode = args[i + 1];
      i++;
      continue;
    }
    if (arg == '--no-clear-initial-timeline') {
      clearInitialTimelineOverride = false;
      continue;
    }
    if (arg == '--raw-startup') {
      rawStartup = true;
      continue;
    }
    if (arg == '--timeline') {
      enableTimeline = true;
      continue;
    }
    if (arg == '--vm-service-discovered-iso' && i + 1 < args.length) {
      vmServiceDiscoveredIso = args[i + 1];
      i++;
    }
  }

  final clearInitialTimeline =
      clearInitialTimelineOverride ?? measurementMode != 'launch';

  final collector = PerfCollector(
    wsUrl: wsUrl,
    durationSec: durationSec,
    humanMode: humanMode,
    measurementMode: measurementMode,
    clearInitialTimeline: clearInitialTimeline,
    rawStartup: rawStartup,
    enableTimeline: enableTimeline,
    vmServiceDiscoveredIso: vmServiceDiscoveredIso,
  );
  await collector.run();
  exit(0);
}

void _printUsage() {
  stderr.writeln(
      'Usage: dart run collect_vm_performance.dart <ws_url> [options]');
  stderr.writeln('');
  stderr.writeln('Options:');
  stderr.writeln(
      '  --duration SECONDS               Collection duration (default: 15)');
  stderr.writeln(
      '  --json                           JSON output to stdout (default)');
  stderr.writeln(
      '  --human                          Human-readable terminal report');
  stderr.writeln(
      '  --mode launch|attach             Measurement mode (default: attach)');
  stderr.writeln(
      '  --no-clear-initial-timeline      Keep existing timeline events');
  stderr.writeln(
      '  --raw-startup                    Include raw startup analysis sections');
  stderr.writeln(
      '  --timeline                       Enable Timeline recording (OFF by default; adds overhead)');
  stderr.writeln(
      '  --vm-service-discovered-iso ISO  Wrapper-provided discovery timestamp');
  stderr.writeln('  --help, -h                       Show this message');
}

class PerfCollector {
  PerfCollector({
    required this.wsUrl,
    required this.durationSec,
    required this.humanMode,
    required this.measurementMode,
    required this.clearInitialTimeline,
    required this.rawStartup,
    required this.enableTimeline,
    required this.vmServiceDiscoveredIso,
  }) : _vmServiceDiscoveredAt = _parseIso(vmServiceDiscoveredIso);

  final String wsUrl;
  final int durationSec;
  final bool humanMode;
  final String measurementMode;
  final bool clearInitialTimeline;
  final bool rawStartup;
  final bool enableTimeline;
  final String? vmServiceDiscoveredIso;
  final DateTime? _vmServiceDiscoveredAt;

  WebSocket? _ws;
  int _msgId = 1;
  final Map<int, Completer<Map<String, dynamic>>> _pending =
      <int, Completer<Map<String, dynamic>>>{};
  String? _mainIsolateId;

  final List<int> _flutterFramesBuildUs = <int>[];
  final List<int> _flutterFramesRasterUs = <int>[];
  final List<int> _flutterFramesElapsedUs = <int>[];
  final List<Map<String, dynamic>> _frameSamples = <Map<String, dynamic>>[];
  final Map<String, int> _beginEvents = <String, int>{};
  final List<double> _timelineBuildDurations = <double>[];
  final List<double> _timelineRasterDurations = <double>[];
  final List<int> _frameTimestamps = <int>[];
  final List<Map<String, dynamic>> _memSnapshots = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> _gcSamples = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> _allocTop10 = <Map<String, dynamic>>[];
  final Map<String, int> _eventCounts = <String, int>{};
  final Map<String, Map<String, dynamic>> _timelineHotspotMap =
      <String, Map<String, dynamic>>{};
  final Map<String, int> _startupMarkerWallUs = <String, int>{};
  final Map<String, int> _startupMarkerTimelineUs = <String, int>{};

  int _gcScavengeCount = 0;
  int _gcMajorCount = 0;
  int _totalTimelineEvents = 0;
  DateTime? _collectionStartAt;
  DateTime? _firstFrameSeenAt;

  Future<void> run() async {
    StreamSubscription<dynamic>? subscription;
    try {
      stderr.writeln('[1/5] VM Service 연결 중: $wsUrl');
      _ws = await WebSocket.connect(wsUrl);
      stderr.writeln('  OK 연결 성공');

      subscription = _ws!.listen(
        _handleMessage,
        onError: (Object error) => stderr.writeln('  ERR WebSocket 에러: $error'),
        onDone: () => stderr.writeln('  WebSocket 종료'),
      );

      stderr.writeln('[2/5] VM 정보 조회...');
      final vm = await _call('getVM');
      final isolates = vm['isolates'] as List<dynamic>;
      _mainIsolateId = (isolates.first as Map<String, dynamic>)['id'] as String;
      stderr.writeln('  Main Isolate: $_mainIsolateId');
      stderr.writeln('  Dart: ${vm['version']}');

      stderr.writeln('[3/5] 스트림 활성화...');
      if (enableTimeline) {
        if (clearInitialTimeline) {
          await _call('clearVMTimeline');
          stderr.writeln('  초기 timeline 버퍼를 비웠습니다.');
        } else {
          stderr.writeln('  launch 모드: 초기 timeline 버퍼를 유지합니다.');
        }
        await _call('setVMTimelineFlags', <String, dynamic>{
          'recordedStreams': <String>['Dart', 'Embedder', 'GC'],
        });
        await _call('streamListen', <String, dynamic>{'streamId': 'Timeline'});
      }
      await _call('streamListen', <String, dynamic>{'streamId': 'GC'});
      try {
        await _call('streamListen', <String, dynamic>{'streamId': 'Extension'});
      } catch (_) {}
      _collectionStartAt = DateTime.now().toUtc();
      stderr.writeln(enableTimeline
          ? '  OK Timeline/GC/Extension 스트림 활성화'
          : '  OK GC/Extension 스트림 활성화 (Timeline OFF)');

      stderr.writeln('[4/5] 성능 데이터 수집 중 ($durationSec초)...');
      stderr.writeln('  mode=$measurementMode');
      stderr.writeln('  >> 앱에서 시나리오를 테스트하세요 <<');

      final stopwatch = Stopwatch()..start();
      final memTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _collectMemory(),
      );
      final timelineTimer = enableTimeline
          ? Timer.periodic(
              const Duration(seconds: 3),
              (_) => _pollTimeline(),
            )
          : null;
      final progressTimer = Timer.periodic(
        const Duration(seconds: 10),
        (Timer timer) {
          if (stopwatch.elapsed.inSeconds >= durationSec) {
            timer.cancel();
            return;
          }
          final remaining = durationSec - stopwatch.elapsed.inSeconds;
          stderr.writeln(
            '  [${stopwatch.elapsed.inSeconds}s] '
            'Flutter.Frames: ${_flutterFramesElapsedUs.length}, '
            'TimelineFrames: ${_timelineBuildDurations.length}, '
            'Mem: ${_memSnapshots.length}, '
            'GC(s/m): $_gcScavengeCount/$_gcMajorCount '
            '(${remaining}s 남음)',
          );
        },
      );

      await Future<void>.delayed(Duration(seconds: durationSec));
      memTimer.cancel();
      timelineTimer?.cancel();
      progressTimer.cancel();
      stopwatch.stop();

      stderr.writeln('[5/5] 최종 데이터 수집 및 분석...');
      await _collectMemory();
      if (enableTimeline) {
        await _pollTimeline();
      }
      await _collectAllocationProfile();

      if (humanMode) {
        _printHumanReport();
      } else {
        _printJsonReport();
      }
    } catch (error, stackTrace) {
      stderr.writeln('에러: $error');
      stderr.writeln(stackTrace.toString());
      exit(1);
    } finally {
      for (final completer in _pending.values) {
        if (!completer.isCompleted) {
          completer.completeError('collector shutdown');
        }
      }
      _pending.clear();
      await subscription?.cancel();
      await _ws?.close();
    }
  }

  Future<void> _collectMemory() async {
    if (_mainIsolateId == null) {
      return;
    }
    try {
      final mem = await _call(
        'getMemoryUsage',
        <String, dynamic>{'isolateId': _mainIsolateId},
      );
      final now = DateTime.now().toUtc();
      _memSnapshots.add(<String, dynamic>{
        'timestamp_iso': now.toIso8601String(),
        'relative_ms_from_collection_start':
            _relativeMsFromCollectionStart(now),
        'heap_usage_bytes': mem['heapUsage'] as int? ?? 0,
        'heap_capacity_bytes': mem['heapCapacity'] as int? ?? 0,
        'external_usage_bytes': mem['externalUsage'] as int? ?? 0,
      });
    } catch (_) {}
  }

  Future<void> _pollTimeline() async {
    try {
      final timeline = await _call('getVMTimeline');
      final events = timeline['traceEvents'] as List<dynamic>? ?? <dynamic>[];
      for (final dynamic event in events) {
        _processTimelineEvent(event as Map<String, dynamic>);
      }
      await _call('clearVMTimeline');
    } catch (_) {}
  }

  Future<void> _collectAllocationProfile() async {
    if (_mainIsolateId == null) {
      return;
    }
    try {
      final profile = await _call(
        'getAllocationProfile',
        <String, dynamic>{'isolateId': _mainIsolateId, 'gc': false},
      );
      final members = profile['members'] as List<dynamic>? ?? <dynamic>[];
      final sorted = members
          .cast<Map<String, dynamic>>()
          .where((Map<String, dynamic> member) =>
              (member['bytesCurrent'] as int? ?? 0) > 0)
          .toList()
        ..sort(
          (Map<String, dynamic> a, Map<String, dynamic> b) =>
              ((b['bytesCurrent'] as int?) ?? 0)
                  .compareTo((a['bytesCurrent'] as int?) ?? 0),
        );

      _allocTop10
        ..clear()
        ..addAll(
          sorted.take(10).map(
                (Map<String, dynamic> member) => <String, dynamic>{
                  'class': (member['class'] as Map?)?['name'] as String? ??
                      'unknown',
                  'instances': member['instancesCurrent'] as int? ?? 0,
                  'bytes': member['bytesCurrent'] as int? ?? 0,
                },
              ),
        );
    } catch (_) {}
  }

  void _processTimelineEvent(Map<String, dynamic> event) {
    final name = event['name'] as String?;
    final phase = event['ph'] as String?;
    final ts = event['ts'] as int?;
    final dur = event['dur'] as int?;
    final tid = event['tid'] as int?;

    if (name == null || ts == null) {
      return;
    }

    _totalTimelineEvents += 1;
    _eventCounts[name] = (_eventCounts[name] ?? 0) + 1;

    if (name.startsWith('startup.')) {
      _recordStartupMarker(name.substring('startup.'.length), ts, event);
    }

    if (name == 'Animator::BeginFrame' && phase == 'B') {
      _frameTimestamps.add(ts);
    }

    if (phase == 'X' && dur != null && dur > 0) {
      _categorizeTimelineEvent(name, dur / 1000.0);
      return;
    }

    final key = '$name|$tid';
    if (phase == 'B') {
      _beginEvents[key] = ts;
      return;
    }
    if (phase == 'E') {
      final beginTs = _beginEvents.remove(key);
      if (beginTs == null) {
        return;
      }
      final durMs = (ts - beginTs) / 1000.0;
      if (durMs > 0 && durMs < 10000) {
        _categorizeTimelineEvent(name, durMs);
      }
    }
  }

  void _categorizeTimelineEvent(String name, double durMs) {
    if (name == 'Animator::BeginFrame' ||
        name == 'Frame' ||
        name == 'vsync callback') {
      _timelineBuildDurations.add(durMs);
    }

    if (name == 'GPURasterizer::Draw' ||
        name == 'Rasterizer::Draw' ||
        name == 'Rasterizer::DoDraw' ||
        name == 'Rasterizer::DrawToSurfaces') {
      _timelineRasterDurations.add(durMs);
    }

    _recordHotspot(name, durMs);
  }

  void _recordHotspot(String name, double durMs) {
    final hotspot = _timelineHotspotMap.putIfAbsent(
      name,
      () => <String, dynamic>{
        'name': name,
        'count': 0,
        'total_ms': 0.0,
        'max_ms': 0.0,
      },
    );
    hotspot['count'] = (hotspot['count'] as int) + 1;
    hotspot['total_ms'] = (hotspot['total_ms'] as double) + durMs;
    hotspot['max_ms'] = max(hotspot['max_ms'] as double, durMs);
  }

  void _recordStartupMarker(
    String stage,
    int timelineTsUs,
    Map<String, dynamic> event,
  ) {
    _startupMarkerTimelineUs.putIfAbsent(stage, () => timelineTsUs);
    final wallEpochUs = _extractWallEpochUs(event);
    if (wallEpochUs != null) {
      _startupMarkerWallUs.putIfAbsent(stage, () => wallEpochUs);
      if (stage == 'first_frame_rasterized' && _firstFrameSeenAt == null) {
        _firstFrameSeenAt = _dateTimeFromEpochUs(wallEpochUs);
      }
    }
  }

  int? _extractWallEpochUs(Map<String, dynamic> event) {
    final args = event['args'];
    if (args is! Map) {
      return null;
    }
    final raw = args['wall_epoch_us'];
    if (raw is int) {
      return raw;
    }
    if (raw is String) {
      return int.tryParse(raw);
    }
    return null;
  }

  void _recordFrameSample({
    required DateTime receivedAt,
    int? buildUs,
    int? rasterUs,
    int? elapsedUs,
  }) {
    _frameSamples.add(<String, dynamic>{
      'received_iso': receivedAt.toIso8601String(),
      'relative_ms_from_collection_start':
          _relativeMsFromCollectionStart(receivedAt),
      'build_ms': buildUs != null ? _roundTo(buildUs / 1000.0, 3) : null,
      'raster_ms': rasterUs != null ? _roundTo(rasterUs / 1000.0, 3) : null,
      'elapsed_ms': elapsedUs != null ? _roundTo(elapsedUs / 1000.0, 3) : null,
    });
  }

  void _recordGcSample(String kind) {
    final now = DateTime.now().toUtc();
    _gcSamples.add(<String, dynamic>{
      'kind': kind,
      'received_iso': now.toIso8601String(),
      'relative_ms_from_collection_start': _relativeMsFromCollectionStart(now),
    });
  }

  void _handleMessage(dynamic data) {
    final msg = jsonDecode(data as String) as Map<String, dynamic>;

    if (msg.containsKey('id')) {
      final id = msg['id'] as int;
      final completer = _pending.remove(id);
      if (completer == null) {
        return;
      }
      if (msg.containsKey('error')) {
        completer.completeError(msg['error'] as Object);
      } else {
        completer.complete(
          (msg['result'] as Map<String, dynamic>?) ?? <String, dynamic>{},
        );
      }
      return;
    }

    if (msg['method'] != 'streamNotify') {
      return;
    }

    final params = msg['params'] as Map<String, dynamic>;
    final streamId = params['streamId'] as String;
    final event = params['event'] as Map<String, dynamic>;

    if (streamId == 'GC') {
      final kind = (event['kind'] as String? ?? '').toLowerCase();
      if (kind.contains('scavenge')) {
        _gcScavengeCount += 1;
        _recordGcSample('scavenge');
      } else {
        _gcMajorCount += 1;
        _recordGcSample(kind.isEmpty ? 'major' : kind);
      }
      return;
    }

    if (streamId == 'Timeline') {
      final traceEvents =
          event['timelineEvents'] as List<dynamic>? ?? <dynamic>[];
      for (final dynamic traceEvent in traceEvents) {
        _processTimelineEvent(traceEvent as Map<String, dynamic>);
      }
      return;
    }

    if (streamId == 'Extension') {
      final kind = event['extensionKind'] as String?;
      final now = DateTime.now().toUtc();
      if (kind == 'Flutter.Frame') {
        final data = event['extensionData'] as Map<String, dynamic>? ??
            <String, dynamic>{};
        final buildUs = data['build'] as int?;
        final rasterUs = data['raster'] as int?;
        final elapsedUs = data['elapsed'] as int?;
        if (buildUs != null) {
          _flutterFramesBuildUs.add(buildUs);
        }
        if (rasterUs != null) {
          _flutterFramesRasterUs.add(rasterUs);
        }
        if (elapsedUs != null) {
          _flutterFramesElapsedUs.add(elapsedUs);
        }
        _recordFrameSample(
          receivedAt: now,
          buildUs: buildUs,
          rasterUs: rasterUs,
          elapsedUs: elapsedUs,
        );
        return;
      }
      if (kind == 'Flutter.FirstFrame' && _firstFrameSeenAt == null) {
        _firstFrameSeenAt = now;
        stderr.writeln('  >> Flutter.FirstFrame 감지');
      }
    }
  }

  Future<Map<String, dynamic>> _call(
    String method, [
    Map<String, dynamic>? params,
  ]) async {
    final id = _msgId++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;

    _ws!.add(
      jsonEncode(<String, dynamic>{
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        if (params != null) 'params': params,
      }),
    );

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _pending.remove(id);
        throw TimeoutException('$method timed out');
      },
    );
  }

  List<double> get _effectiveElapsedMs {
    if (_flutterFramesElapsedUs.isNotEmpty) {
      return _flutterFramesElapsedUs
          .map((int us) => us / 1000.0)
          .toList(growable: false);
    }
    return List<double>.from(_timelineBuildDurations);
  }

  List<double> get _effectiveBuildMs {
    if (_flutterFramesBuildUs.isNotEmpty) {
      return _flutterFramesBuildUs
          .map((int us) => us / 1000.0)
          .toList(growable: false);
    }
    return List<double>.from(_timelineBuildDurations);
  }

  List<double> get _effectiveRasterMs {
    if (_flutterFramesRasterUs.isNotEmpty) {
      return _flutterFramesRasterUs
          .map((int us) => us / 1000.0)
          .toList(growable: false);
    }
    return List<double>.from(_timelineRasterDurations);
  }

  double _roundTo(double value, int decimals) {
    final mod = pow(10.0, decimals);
    return (value * mod).roundToDouble() / mod;
  }

  double _percentile(List<double> sorted, double percentile) {
    if (sorted.isEmpty) {
      return 0.0;
    }
    final index = min((sorted.length * percentile).floor(), sorted.length - 1);
    return sorted[index];
  }

  double _avg(List<double> values) {
    if (values.isEmpty) {
      return 0.0;
    }
    return values.reduce((double a, double b) => a + b) / values.length;
  }

  List<double> _computeFrameIntervals() {
    if (_frameTimestamps.length < 2) {
      return <double>[];
    }
    final intervals = <double>[];
    for (var i = 1; i < _frameTimestamps.length; i++) {
      final ms = (_frameTimestamps[i] - _frameTimestamps[i - 1]) / 1000.0;
      if (ms > 0 && ms < 1000) {
        intervals.add(ms);
      }
    }
    return intervals;
  }

  double _fpsFromTimestamps() {
    final intervals = _computeFrameIntervals();
    if (intervals.isNotEmpty) {
      final avgInterval = _avg(intervals);
      return avgInterval > 0 ? 1000.0 / avgInterval : 0.0;
    }
    if (_flutterFramesElapsedUs.isNotEmpty && durationSec > 0) {
      return _flutterFramesElapsedUs.length / durationSec.toDouble();
    }
    return 0.0;
  }

  Map<String, dynamic> _buildMemorySection() {
    if (_memSnapshots.isEmpty) {
      return <String, dynamic>{
        'heap_usage_bytes': 0,
        'heap_capacity_bytes': 0,
        'external_usage_bytes': 0,
        'utilization_pct': 0.0,
        'trend': 'UNKNOWN',
        'snapshots_count': 0,
      };
    }

    final heapUsages = _memSnapshots
        .map((Map<String, dynamic> sample) => sample['heap_usage_bytes'] as int)
        .toList(growable: false);
    final heapCapacities = _memSnapshots
        .map(
          (Map<String, dynamic> sample) => sample['heap_capacity_bytes'] as int,
        )
        .toList(growable: false);
    final externalUsages = _memSnapshots
        .map(
          (Map<String, dynamic> sample) =>
              sample['external_usage_bytes'] as int,
        )
        .toList(growable: false);

    final avgHeap =
        heapUsages.reduce((int a, int b) => a + b) / heapUsages.length;
    final avgCapacity =
        heapCapacities.reduce((int a, int b) => a + b) / heapCapacities.length;
    final avgExternal =
        externalUsages.reduce((int a, int b) => a + b) / externalUsages.length;

    var trend = 'STABLE';
    if (heapUsages.length > 5) {
      final half = heapUsages.length ~/ 2;
      final firstAvg =
          heapUsages.sublist(0, half).reduce((int a, int b) => a + b) / half;
      final secondHalf = heapUsages.length - half;
      final secondAvg =
          heapUsages.sublist(half).reduce((int a, int b) => a + b) / secondHalf;
      final growthPct = (secondAvg - firstAvg) / firstAvg * 100;
      if (growthPct > 5) {
        trend = 'GROWING';
      } else if (growthPct < -5) {
        trend = 'SHRINKING';
      }
    }

    return <String, dynamic>{
      'heap_usage_bytes': avgHeap.round(),
      'heap_capacity_bytes': avgCapacity.round(),
      'external_usage_bytes': avgExternal.round(),
      'utilization_pct':
          avgCapacity > 0 ? _roundTo(avgHeap / avgCapacity * 100, 2) : 0.0,
      'trend': trend,
      'snapshots_count': _memSnapshots.length,
    };
  }

  Map<String, dynamic> _buildFramesSection() {
    final elapsed = List<double>.from(_effectiveElapsedMs)..sort();
    final build = _effectiveBuildMs;
    final raster = _effectiveRasterMs;
    final total = elapsed.length;
    final janky = elapsed.where((double value) => value > 16.67).length;
    final severeJank = elapsed.where((double value) => value > 33.34).length;
    final jankPct = total > 0 ? _roundTo(janky / total * 100, 2) : 0.0;

    return <String, dynamic>{
      'total': total,
      'janky': janky,
      'severe_jank': severeJank,
      'avg_build_ms': _roundTo(_avg(build), 3),
      'avg_raster_ms': _roundTo(_avg(raster), 3),
      'p50_elapsed_ms': _roundTo(_percentile(elapsed, 0.50), 3),
      'p90_elapsed_ms': _roundTo(_percentile(elapsed, 0.90), 3),
      'p95_elapsed_ms': _roundTo(_percentile(elapsed, 0.95), 3),
      'p99_elapsed_ms': _roundTo(_percentile(elapsed, 0.99), 3),
      'max_elapsed_ms': elapsed.isNotEmpty ? _roundTo(elapsed.last, 3) : 0.0,
      'fps': _roundTo(_fpsFromTimestamps(), 2),
      'jank_pct': jankPct,
    };
  }

  Map<String, dynamic> _buildGcSection() {
    return <String, dynamic>{
      'scavenge_count': _gcScavengeCount,
      'major_gc_count': _gcMajorCount,
    };
  }

  Map<String, dynamic> _buildMeasurementMeta() {
    final collectionStart = _collectionStartAt;
    final firstFrame = _resolveFirstFrameAt();
    final attachDelayMs = collectionStart != null &&
            _vmServiceDiscoveredAt != null
        ? _roundTo(
            collectionStart.difference(_vmServiceDiscoveredAt).inMicroseconds /
                1000.0,
            3,
          )
        : null;

    return <String, dynamic>{
      'measurement_mode': measurementMode,
      'requested_duration_seconds': durationSec,
      'actual_collection_start_iso': collectionStart?.toIso8601String(),
      'vm_service_discovered_iso': vmServiceDiscoveredIso,
      'attach_delay_ms': attachDelayMs,
      'timeline_enabled': enableTimeline,
      'timeline_cleared_at_start': clearInitialTimeline,
      'total_timeline_events': _totalTimelineEvents,
      'first_frame_seen_iso': firstFrame?.toIso8601String(),
      'startup_window_complete': _hasCompleteStartupWindow(),
    };
  }

  Map<String, dynamic> _buildStartupSection() {
    final launchMarkerTimes = <String, dynamic>{};
    final collectionStartWallUs = _collectionStartAt?.microsecondsSinceEpoch;

    for (final stage in _requiredStartupStages) {
      final wallUs = _startupMarkerWallUs[stage];
      launchMarkerTimes[stage] = <String, dynamic>{
        'wall_epoch_us': wallUs,
        'wall_iso': wallUs != null ? _isoFromEpochUs(wallUs) : null,
        'relative_ms_from_collection_start':
            wallUs != null && collectionStartWallUs != null
                ? _roundTo((wallUs - collectionStartWallUs) / 1000.0, 3)
                : null,
      };
    }

    final mainEnter = _startupMarkerWallUs['main_enter'];
    final runAppCalled = _startupMarkerWallUs['runapp_called'];
    final firstFrame = _startupMarkerWallUs['first_frame_rasterized'];
    final collectionStart = _collectionStartAt?.microsecondsSinceEpoch;

    return <String, dynamic>{
      'launch_marker_times': launchMarkerTimes,
      'time_to_first_frame_ms': _diffMs(mainEnter, firstFrame),
      'time_to_runapp_ms': _diffMs(mainEnter, runAppCalled),
      'time_to_profile_ready_ms': _diffMs(mainEnter, collectionStart),
      'attach_delay_ms': _buildMeasurementMeta()['attach_delay_ms'],
    };
  }

  List<Map<String, dynamic>> _buildStartupMarkers() {
    final markers = <Map<String, dynamic>>[];
    final stages = _startupMarkerWallUs.keys.toList()..sort();
    final collectionStartWallUs = _collectionStartAt?.microsecondsSinceEpoch;
    for (final stage in stages) {
      final wallUs = _startupMarkerWallUs[stage];
      markers.add(<String, dynamic>{
        'stage': stage,
        'wall_epoch_us': wallUs,
        'wall_iso': wallUs != null ? _isoFromEpochUs(wallUs) : null,
        'relative_ms_from_collection_start':
            wallUs != null && collectionStartWallUs != null
                ? _roundTo((wallUs - collectionStartWallUs) / 1000.0, 3)
                : null,
      });
    }
    return markers;
  }

  List<Map<String, dynamic>> _buildWorstFrames() {
    final sorted = _frameSamples
        .where((Map<String, dynamic> sample) => sample['elapsed_ms'] != null)
        .toList()
      ..sort(
        (Map<String, dynamic> a, Map<String, dynamic> b) =>
            (b['elapsed_ms'] as double).compareTo(a['elapsed_ms'] as double),
      );
    return sorted.take(10).toList(growable: false);
  }

  List<Map<String, dynamic>> _buildTimelineHotspots() {
    final hotspots = _timelineHotspotMap.values
        .map(
          (Map<String, dynamic> hotspot) => <String, dynamic>{
            'name': hotspot['name'],
            'count': hotspot['count'],
            'total_ms': _roundTo(hotspot['total_ms'] as double, 3),
            'max_ms': _roundTo(hotspot['max_ms'] as double, 3),
          },
        )
        .toList()
      ..sort(
        (Map<String, dynamic> a, Map<String, dynamic> b) =>
            (b['total_ms'] as double).compareTo(a['total_ms'] as double),
      );
    return hotspots.take(20).toList(growable: false);
  }

  void _printJsonReport() {
    final output = <String, dynamic>{
      'schema_version': 3,
      'collected_at': DateTime.now().toUtc().toIso8601String(),
      'duration_seconds': durationSec,
      'vm_service_url': wsUrl,
      'measurement_meta': _buildMeasurementMeta(),
      'startup': _buildStartupSection(),
      'memory': _buildMemorySection(),
      'frames': _buildFramesSection(),
      'gc_events': _buildGcSection(),
      'allocation_top_10': _allocTop10,
      'startup_markers': _buildStartupMarkers(),
      'worst_frames': _buildWorstFrames(),
      'timeline_hotspots': _buildTimelineHotspots(),
      'memory_samples': rawStartup || measurementMode == 'launch'
          ? _memSnapshots
          : <Map<String, dynamic>>[],
      'gc_samples': rawStartup || measurementMode == 'launch'
          ? _gcSamples
          : <Map<String, dynamic>>[],
    };

    stdout.writeln(const JsonEncoder.withIndent('  ').convert(output));
  }

  void _printHumanReport() {
    final frames = _buildFramesSection();
    final startup = _buildStartupSection();
    final meta = _buildMeasurementMeta();
    final worstFrames = _buildWorstFrames();
    final hotspots = _buildTimelineHotspots();

    stdout.writeln('');
    stdout.writeln(
        '============================================================');
    stdout.writeln('       Flutter Launch-First Performance Report');
    stdout.writeln('  Mode: ${meta['measurement_mode']}');
    stdout.writeln('  VM: $wsUrl');
    stdout.writeln(
      '  Duration: ${durationSec}s  |  Collected: ${DateTime.now().toUtc().toIso8601String()}',
    );
    stdout.writeln(
        '============================================================');
    stdout.writeln('');
    stdout.writeln('--- Startup ---');
    stdout.writeln(
      '  Startup window complete: ${meta['startup_window_complete']}',
    );
    stdout.writeln(
      '  Time to first frame: ${startup['time_to_first_frame_ms'] ?? 'n/a'}ms',
    );
    stdout.writeln(
      '  Time to runApp: ${startup['time_to_runapp_ms'] ?? 'n/a'}ms',
    );
    stdout.writeln(
      '  Time to profile ready: ${startup['time_to_profile_ready_ms'] ?? 'n/a'}ms',
    );
    stdout.writeln(
      '  Attach delay: ${meta['attach_delay_ms'] ?? 'n/a'}ms',
    );
    stdout.writeln('');
    stdout.writeln('--- Frames ---');
    stdout.writeln('  Total frames: ${frames['total']}');
    stdout.writeln(
        '  Jank (>16.67ms): ${frames['janky']} (${frames['jank_pct']}%)');
    stdout.writeln('  Severe jank (>33.34ms): ${frames['severe_jank']}');
    stdout.writeln('  Avg build: ${frames['avg_build_ms']}ms');
    stdout.writeln('  Avg raster: ${frames['avg_raster_ms']}ms');
    stdout.writeln('  Worst frame: ${frames['max_elapsed_ms']}ms');
    stdout.writeln('  FPS: ${frames['fps']}');
    if (worstFrames.isNotEmpty) {
      stdout.writeln('');
      stdout.writeln('--- Worst Frames ---');
      for (final frame in worstFrames.take(5)) {
        stdout.writeln(
          '  elapsed=${frame['elapsed_ms']}ms '
          'build=${frame['build_ms']}ms '
          'raster=${frame['raster_ms']}ms '
          't=${frame['relative_ms_from_collection_start']}ms',
        );
      }
    }
    stdout.writeln('');
    stdout.writeln('--- Memory ---');
    final memory = _buildMemorySection();
    stdout.writeln(
        '  Heap used avg: ${_fmtB(memory['heap_usage_bytes'] as int)}');
    stdout.writeln(
      '  Heap capacity avg: ${_fmtB(memory['heap_capacity_bytes'] as int)}',
    );
    stdout.writeln('  Utilization: ${memory['utilization_pct']}%');
    stdout.writeln('  Trend: ${memory['trend']}');
    stdout.writeln('');
    stdout.writeln('--- GC ---');
    stdout.writeln('  Scavenge (minor): $_gcScavengeCount');
    stdout.writeln('  Major GC: $_gcMajorCount');
    stdout.writeln('');
    stdout.writeln('--- Timeline Hotspots ---');
    if (hotspots.isEmpty) {
      stdout.writeln('  No hotspot data');
    } else {
      for (final hotspot in hotspots.take(5)) {
        stdout.writeln(
          '  ${hotspot['name']}: total=${hotspot['total_ms']}ms '
          'max=${hotspot['max_ms']}ms count=${hotspot['count']}',
        );
      }
    }
    stdout.writeln('');
    stdout.writeln(
        '============================================================');
  }

  double? _relativeMsFromCollectionStart(DateTime timestamp) {
    if (_collectionStartAt == null) {
      return null;
    }
    return _roundTo(
      timestamp.difference(_collectionStartAt!).inMicroseconds / 1000.0,
      3,
    );
  }

  double? _diffMs(int? startUs, int? endUs) {
    if (startUs == null || endUs == null) {
      return null;
    }
    return _roundTo((endUs - startUs) / 1000.0, 3);
  }

  bool _hasCompleteStartupWindow() {
    for (final stage in _requiredStartupStages) {
      if (!_startupMarkerWallUs.containsKey(stage)) {
        return false;
      }
    }
    return true;
  }

  DateTime? _resolveFirstFrameAt() {
    if (_startupMarkerWallUs.containsKey('first_frame_rasterized')) {
      return _dateTimeFromEpochUs(
          _startupMarkerWallUs['first_frame_rasterized']!);
    }
    return _firstFrameSeenAt;
  }

  static DateTime? _parseIso(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toUtc();
  }

  DateTime _dateTimeFromEpochUs(int epochUs) {
    return DateTime.fromMicrosecondsSinceEpoch(epochUs, isUtc: true);
  }

  String _isoFromEpochUs(int epochUs) {
    return _dateTimeFromEpochUs(epochUs).toIso8601String();
  }

  String _fmtB(int bytes) {
    if (bytes < 1024) {
      return '${bytes}B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}
