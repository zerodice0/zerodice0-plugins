# Codex Plan Reviewer

Plan agent로 구현 계획을 수립하고, Codex 리뷰를 받아 최종 계획을 완성하고, 태스크별로 Codex에 위임하여 실행하는 워크플로우 플러그인입니다.

## 사전 요구사항

- [Codex CLI](https://github.com/openai/codex) 설치 및 인증
- Codex Claude Code 플러그인 (`codex@openai-codex`) 활성화

## 커맨드

### `/codex-plan` — 계획 수립 + Codex 리뷰

구현 계획을 수립하고 Codex 리뷰를 받아 최종 계획을 완성합니다.

```
/codex-plan <구현할 작업 설명>
```

| Phase | 설명 |
|-------|------|
| 1. Codex 확인 | Codex CLI 사용 가능 여부 확인 |
| 2. 분석 & 계획 | 코드베이스 탐색 후 구현 계획 수립 |
| 3. Codex 리뷰 | 계획을 Codex에게 리뷰 요청 |
| 4. 피드백 검증 | Codex 피드백을 실제 코드와 대조 검증 |
| 5. 최종 계획 | 유효한 피드백 반영 후 최종 계획 확정 |

### `/codex-plan-execute` — 계획 분할 실행

구현 계획을 태스크로 분할하고 각 태스크를 별도 Codex 스레드에 위임하여 병렬 실행합니다.

```
/codex-plan-execute <계획 파일 경로 또는 계획 텍스트>
```

| Phase | 설명 |
|-------|------|
| 0. Codex 확인 | Codex CLI 및 companion 스크립트 확인 |
| 1. 계획 입력 | 파일 경로 또는 텍스트로 계획 수집 |
| 2. 태스크 분할 | 구현 단계 추출, 의존성 분석, 웨이브 할당 |
| 3. 충돌 검사 | 같은 웨이브 내 파일 충돌 감지 |
| 4. Codex 실행 | 웨이브별 백그라운드 Codex 스레드 시작 |
| 5. 모니터링 | 진행 상황 추적 및 웨이브 진행 |
| 6. 결과 보고 | 전체 실행 결과 취합 및 보고 |

### 예시

```
# 계획 수립 후 실행까지
/codex-plan 사용자 인증 모듈에 OAuth2 지원 추가
# (계획 완성 후 파일로 저장)
/codex-plan-execute ./PLAN.md

# 직접 계획 텍스트 전달
/codex-plan-execute "1. DB 스키마 생성 2. 모델 레이어 구현 3. API 엔드포인트 추가"
```

## 라이선스

MIT
