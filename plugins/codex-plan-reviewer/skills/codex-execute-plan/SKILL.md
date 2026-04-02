---
name: codex-execute-plan
description: This skill should be used when the user asks to "execute plan with codex", "계획 실행해줘", "태스크별로 Codex 실행", "plan 나눠서 실행", "Codex로 태스크 실행", "계획을 Codex에 맡겨", "태스크 분할 실행", or wants to split a plan into tasks and delegate each to a separate Codex thread.
---

# Codex Execute Plan

이 스킬이 트리거되면 `/codex-plan-execute` 커맨드를 실행합니다.

## 사전 요구사항

- Codex 플러그인 (`codex@openai-codex`) 설치 및 활성화 필요
- Codex CLI 인증 완료 필요 (미설치 시 `/codex:setup` 실행)
