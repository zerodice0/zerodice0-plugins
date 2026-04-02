# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-04-02

### Added

- **codex-plan-reviewer** v1.1.0: `/codex-plan-execute` 커맨드 추가
  - 구현 계획을 태스크로 분할하고 각 태스크를 별도 Codex 백그라운드 스레드에 위임
  - Wave 기반 병렬 실행 (의존성 분석, 파일 충돌 검사)
  - 진행 상황 모니터링 및 결과 취합 보고

### Changed

- **codex-plan-reviewer**: `/plan-with-codex` 커맨드를 `/codex-plan`으로 리네이밍 (일관성)

---

## [1.1.0] - 2026-01-04

### Changed

- **[CLA-17]** gemini-design-updater 스킬 이름을 `gemini-design`으로 변경하고 슬래시 커맨드 추가
- **[CLA-17]** gemini-design-updater 스킬에 단축 트리거 키워드 추가
  - "gemini-design", "gemini-design 스킬", "gemini-design skill", "gemini-design 사용", "use gemini-design"

### Added

- **gemini-image-generator** 플러그인 추가 (v1.0.0)
  - Gemini 3 Pro Preview를 활용한 앱 에셋 생성 (아이콘, 배경, UI 요소)
  - SVG/PNG/WebP 포맷 지원, 멀티 해상도 출력 (Flutter/iOS/Android/Web)
- **flutter-perf-agent** 플러그인 추가 (v3.0.0)
  - Dart VM Service 직접 연동을 통한 Flutter 성능 분석
  - 실시간 FPS/메모리 측정, 10종 안티패턴 탐지, 마크다운 리포트
- **codex-plan-reviewer** 플러그인 추가 (v1.0.0)
  - Plan 에이전트 + Codex 교차 검증 워크플로우

---

## [1.0.0] - 2024-12-16

### Added

- **Initial release of zerodice0-plugins marketplace**
- **gemini-design-updater plugin** with the following features:
  - Git branch isolation workflow for safe Gemini operations
  - Scope-based change tracking with IDE integration (`@file#L10-50` format)
  - Automatic Claude review of Gemini changes
  - 4-option decision flow (apply all, scope only, revert all, revert out-of-scope)
  - Out-of-scope change detection and classification

### Scripts

- `create-branch.sh` - Creates isolated work branch with timestamp
- `analyze-changes.sh` - Analyzes changes with scope validation
- `apply-partial.sh` - Partial apply/revert functionality
- `cleanup-branch.sh` - Work branch cleanup

### Documentation

- Comprehensive SKILL.md with 6-phase workflow guide
- Review checklist (`references/review-checklist.md`)
- Rollback procedures (`references/rollback-procedures.md`)
- Scope examples (`examples/scope-examples.md`)
- Bilingual README (English/한국어)

### CI/CD

- ShellCheck validation for all bash scripts
- Automated GitHub Release on version tags
- Plugin structure validation

---

## Future Plans

- [ ] Additional Gemini-related plugins
- [ ] Enhanced scope validation with AST parsing
- [ ] Integration with more AI models
