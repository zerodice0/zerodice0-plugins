# zerodice0-plugins

> zerodice0의 Claude Code 플러그인 마켓플레이스

---

## 플러그인

### Development

#### [flutter-perf-agent](./plugins/flutter-perf-agent/) `v3.0.0`

Dart VM Service 직접 연동을 통한 Flutter 종합 성능 분석 에이전트

| 항목 | 내용 |
|------|------|
| 제공 | skill 1, command 1, agent 1 |
| 요구 | Flutter SDK, Dart SDK, 연결된 디바이스/에뮬레이터(런타임 분석 시) |
| 주요 기능 | 실시간 FPS/메모리/GC 측정, 10종 안티패턴 탐지(AP-001~AP-010), 마크다운 리포트 생성 |
| 사용법 | `/flutter-perf` 또는 "Flutter 성능 분석해줘" |

#### [codex-plan-reviewer](./plugins/codex-plan-reviewer/) `v1.1.0`

Plan 에이전트로 구현 계획을 수립하고, Codex 리뷰를 받아 최종 계획을 완성하고, 태스크별로 Codex에 위임하여 실행하는 워크플로우

| 항목 | 내용 |
|------|------|
| 제공 | skill 2, command 2 |
| 요구 | Codex 플러그인 (`codex@openai-codex`) 설치 및 인증 |
| 주요 기능 | 코드베이스 분석 기반 계획 수립, Codex 교차 검증, 태스크 분할 + Wave 기반 병렬 실행 |
| 사용법 | `/codex-plan <작업 설명>`, `/codex-plan-execute <계획 파일>` |

### Design

#### [gemini-design-updater](./plugins/gemini-design-updater/) `v1.1.0`

Gemini Pro를 활용한 안전한 디자인 업데이트 워크플로우 (Git 브랜치 격리 + Claude 리뷰)

| 항목 | 내용 |
|------|------|
| 제공 | skill 1, command 1 |
| 요구 | Gemini CLI, Git 2.0+, Bash 4.0+ |
| 주요 기능 | Git 브랜치 격리, 범위 기반 변경 추적, 4단계 결정 플로우, 범위 외 변경 감지 |
| 사용법 | `/gemini-design` 또는 `@src/Button.tsx#L20-50 이 버튼을 모던하게 바꿔줘` |

#### [gemini-image-generator](./plugins/gemini-image-generator/) `v1.0.0`

Gemini 3 Pro Preview를 활용한 앱 에셋(아이콘, 배경, UI 요소) 생성

| 항목 | 내용 |
|------|------|
| 제공 | skill 1 |
| 요구 | Gemini CLI, ImageMagick 또는 macOS `sips`(멀티 해상도 변환 시) |
| 주요 기능 | SVG/PNG/WebP 포맷 지원, 멀티 플랫폼 해상도(Flutter/iOS/Android/Web), 이미지 변형 |
| 사용법 | "앱 로고 생성해줘, Flutter 프로젝트에 맞게 1x~3x로 저장해줘" |

---

## 설치 방법

```bash
# 마켓플레이스 추가
/plugin marketplace add zerodice0/zerodice0-plugins

# 원하는 플러그인 설치
/plugin install flutter-perf-agent@zerodice0-plugins
/plugin install codex-plan-reviewer@zerodice0-plugins
/plugin install gemini-design-updater@zerodice0-plugins
/plugin install gemini-image-generator@zerodice0-plugins
```

## 요구사항

- Claude Code CLI
- 각 플러그인별 추가 요구사항은 위 테이블 참고

## 변경 이력

[CHANGELOG.md](./CHANGELOG.md)를 참조하세요.

## 기여

Issue와 Pull Request를 환영합니다!

## 라이선스

MIT License - [LICENSE](./LICENSE) 참조

## 작성자

- **zerodice0** - [GitHub](https://github.com/zerodice0)
