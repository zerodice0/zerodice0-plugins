# flutter-perf-agent

> Flutter performance analysis agent using Dart VM Service direct integration

[English](#english) | [한국어](#한국어)

---

## English

A Claude Code skill that provides comprehensive Flutter performance analysis by combining static antipattern detection with runtime metrics collection via Dart VM Service.

### Features

- **Real-time Performance Measurement**: Connects to Dart VM Service to collect FPS, memory, GC, and allocation profiling data
- **Static Antipattern Analysis**: Detects 10 known Flutter performance antipatterns (AP-001 ~ AP-010)
- **Automated App Launch**: Uses `flutter run --profile --vm-service-port` for automated app launch and VM Service connection
- **Markdown Report Generation**: Produces comprehensive, terminal-friendly performance reports
- **Priority-based Recommendations**: Provides improvement suggestions with Before/After code examples
- **Graceful Degradation**: Falls back to static analysis only when a connected device is unavailable

### Prerequisites

- **Flutter SDK** (required)
- **Dart SDK** (included with Flutter)
- **Connected device or emulator** (optional, for runtime analysis)

### Usage

**Method 1: Slash Command (Recommended)**
```
/flutter-perf
```

**Method 2: Natural Language**
```
Analyze Flutter performance
```
```
Measure FPS and memory usage
```
```
Find performance antipatterns
```
```
Generate performance report
```

### How It Works

1. **Environment Check**: Verifies Flutter SDK and connected devices
2. **Static Analysis**: Scans code for 10 known performance antipatterns
3. **Runtime Measurement**: Launches app via `flutter run --profile --vm-service-port`, connects to VM Service, collects FPS/memory/GC data
4. **Diagnosis**: Combines static + runtime results with priority scoring
5. **Report**: Generates terminal-friendly markdown report

### Antipatterns Detected

| ID | Pattern | Severity |
|----|---------|----------|
| AP-001 | setState inside build | Critical |
| AP-002 | Missing const constructors | Major |
| AP-003 | I/O in build method | Critical |
| AP-004 | Inefficient ListView | Major |
| AP-005 | Missing Keys in lists | Minor |
| AP-006 | Excessive rebuild scope | Major |
| AP-007 | No image caching | Minor |
| AP-008 | Missing RepaintBoundary | Minor |
| AP-009 | Excessive GlobalKey | Minor |
| AP-010 | Synchronous file I/O | Critical |

### Scripts

- `scripts/collect_vm_performance.dart` — Dart VM Service performance collector (FPS, memory, GC, allocation)

---

## 한국어

Dart VM Service를 활용하여 Flutter 앱의 성능을 종합적으로 분석하는 Claude Code skill입니다. 정적 안티패턴 탐지와 런타임 메트릭 수집을 결합하여 분석합니다.

### 기능

- **실시간 성능 측정**: Dart VM Service에 연결하여 FPS, 메모리, GC, 할당 프로파일링 데이터 수집
- **정적 안티패턴 분석**: 10가지 Flutter 성능 안티패턴 탐지 (AP-001 ~ AP-010)
- **자동 앱 실행**: `flutter run --profile --vm-service-port`를 활용한 자동화된 앱 실행 및 VM Service 연결
- **마크다운 보고서 생성**: 터미널 친화적인 종합 성능 보고서 생성
- **우선순위 기반 개선 권장사항**: Before/After 코드 예제가 포함된 개선 제안 제공
- **우아한 폴백**: 연결된 디바이스가 없을 경우 정적 분석만으로 동작

### 사전 요구사항

- **Flutter SDK** (필수)
- **Dart SDK** (Flutter에 포함)
- **연결된 디바이스 또는 에뮬레이터** (선택, 런타임 분석용)

### 사용법

**방법 1: 슬래시 명령어 (권장)**
```
/flutter-perf
```

**방법 2: 자연어로 호출**
```
Flutter 성능 분석해줘
```
```
FPS와 메모리 사용량 측정해줘
```
```
성능 안티패턴 찾아줘
```
```
성능 보고서 만들어줘
```

### 작동 원리

1. **환경 확인**: Flutter SDK, 연결된 디바이스 확인
2. **정적 분석**: 10가지 성능 안티패턴에 대한 코드 스캔
3. **런타임 측정**: `flutter run --profile --vm-service-port`로 앱 실행, VM Service 연결, FPS/메모리/GC 데이터 수집
4. **진단**: 정적 분석 + 런타임 결과를 우선순위 점수와 함께 종합
5. **보고서**: 터미널 친화적인 마크다운 보고서 생성

### 탐지 안티패턴

| ID | 패턴 | 심각도 |
|----|------|--------|
| AP-001 | build 내부에서 setState 호출 | Critical |
| AP-002 | const 생성자 누락 | Major |
| AP-003 | build 메서드 내 I/O 수행 | Critical |
| AP-004 | 비효율적인 ListView 사용 | Major |
| AP-005 | 리스트에서 Key 누락 | Minor |
| AP-006 | 과도한 리빌드 범위 | Major |
| AP-007 | 이미지 캐싱 미사용 | Minor |
| AP-008 | RepaintBoundary 누락 | Minor |
| AP-009 | 과도한 GlobalKey 사용 | Minor |
| AP-010 | 동기식 파일 I/O | Critical |

### 스크립트

- `scripts/collect_vm_performance.dart` — Dart VM Service 성능 수집기 (FPS, 메모리, GC, 할당)

---

## License

MIT License - see [LICENSE](../../LICENSE) for details.

## Author

- **zerodice0** - [GitHub](https://github.com/zerodice0)
