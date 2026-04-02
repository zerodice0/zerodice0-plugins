---
name: flutter-perf
description: |
  This skill should be used when the user asks to "analyze Flutter performance", "Flutter 성능 분석", "flutter-perf", "Flutter 성능 측정", "performance audit", "성능 개선 계획", "Flutter 성능 보고서", "Flutter 안티패턴 찾기", "Flutter 성능 진단", "flutter performance check", "성능 이슈 찾기", "FPS 측정", "메모리 분석", "jank 찾기", or wants to analyze Flutter project performance using Dart VM Service.
---

# Flutter Performance Analyzer

Flutter 프로젝트의 성능을 정적 분석과 런타임 측정을 통해 종합적으로 분석하고, 개선 계획을 제공하는 스킬입니다. 이 스킬은 `flutter-perf` 에이전트를 호출하여 분석을 수행합니다.

---

## 워크플로우

```
[환경 확인] → [정적 분석] → [런타임 측정] → [종합 진단] → [보고서 생성]
```

1. **환경 확인**: Flutter SDK 설치 여부, 디바이스 연결 상태 검증
2. **정적 분석**: `lib/` 디렉토리의 Dart 파일에서 10가지 안티패턴(AP-001~AP-010) 탐지 및 `dart analyze` 실행
3. **런타임 측정**: 두 가지 모드 지원
   - **Launch-first** (권장): `measure_launch_minute.sh`로 cold-start 프로파일링 (스타트업 마커, 타임라인 포함)
   - **Attach**: 실행 중인 앱에 `discover_vmservice.sh`로 연결하여 시나리오 샘플링
4. **종합 진단**: 심각도(Critical/Major/Minor) x 영향도 x 빈도로 우선순위 스코어링
5. **보고서 생성**: 프로젝트 요약, 측정 결과, 분석 결과, 개선 우선순위를 터미널 마크다운으로 출력

> 디바이스가 미연결인 경우, 런타임 측정은 건너뛰고 정적 분석 결과만으로 보고서를 생성합니다.

워크플로우 상세 내용은 에이전트 정의(`agents/flutter-perf.md`)를 참조합니다.

---

## 수집 메트릭 (Schema v3)

| 카테고리 | 메트릭 |
|---------|--------|
| Frames | total, janky (>16.67ms), severe_jank (>33.34ms), P50/P90/P95/P99, max, FPS |
| Memory | heap usage/capacity, utilization%, trend (STABLE/GROWING/SHRINKING) |
| Startup | time_to_first_frame, time_to_runapp, startup markers |
| GC | scavenge count, major GC count |
| Timeline | hotspots (top 20), worst frames (top 10) |
| Allocation | top 10 classes by bytes |

---

## 사전 요구사항

| 도구 | 필수 여부 | 설치 방법 |
|------|----------|----------|
| Flutter SDK | 필수 | [flutter.dev](https://flutter.dev) |
| 디바이스/에뮬레이터 | 선택 (런타임 분석용) | `flutter emulators --launch <name>` |

---

## 사용 예시

```
/flutter-perf
```

```
"Flutter 앱 성능 분석해줘"
"Flutter 안티패턴 찾아줘"
"FPS 측정하고 jank 분석해줘"
"Analyze Flutter performance"
"Find performance issues in this Flutter app"
"앱 시작 시간 측정해줘"
"cold-start 성능 프로파일링 해줘"
```

---

## 관련 파일

- `${CLAUDE_PLUGIN_ROOT}/agents/flutter-perf.md`: 에이전트 상세 워크플로우
- `${CLAUDE_PLUGIN_ROOT}/scripts/collect_vm_performance.dart`: Dart VM Service 성능 수집 스크립트 (v3)
- `${CLAUDE_PLUGIN_ROOT}/scripts/discover_vmservice.sh`: VM Service 탐색 스크립트 (3가지 fallback 전략)
- `${CLAUDE_PLUGIN_ROOT}/scripts/measure_launch_minute.sh`: Cold-start 측정 래퍼 스크립트
- `${CLAUDE_PLUGIN_ROOT}/references/antipattern-catalog.md`: 안티패턴 상세 카탈로그

---

## 주요 설계 결정

- **Timeline 기본 OFF**: Observer Effect로 인해 Timeline ON 시 FPS가 실제보다 낮게 측정됨
- **Launch-first가 기본**: Cold-start 병목은 launch 모드에서만 유효한 결론 도출 가능
- **3가지 VM Service 탐색 전략**: vmservice-out-file → Flutter 로그 파싱 → lsof 스캔
- **Schema v3**: 스타트업 마커, worst frames, timeline hotspots, memory trend 포함
