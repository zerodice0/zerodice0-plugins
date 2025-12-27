---
name: gemini-design-updater
description: This skill should be used when the user asks to "update design with Gemini", "Gemini로 디자인 수정", "use Gemini for UI changes", "Gemini 디자인 업데이트", "AI design update", "Gemini로 UI 변경", "use gemini-design-updater", "gemini-design-updater 사용", "/gemini-design-updater", "gemini-design-updater skill", "gemini-design-updater 스킬", "디자인 스킬", "gemini 디자인 스킬", "디자인 업데이트 스킬", or wants to delegate visual/UI updates to Gemini Pro with Claude review. Provides safe workflow with Git branch isolation, scope-based change tracking, and post-change review.
---

# Gemini Design Updater

Gemini Pro를 활용하여 디자인을 업데이트하고, Claude가 변경사항을 리뷰하는 안전한 워크플로우를 제공합니다.

## 핵심 원칙

- **사용자 프롬프트 원문 전달**: Claude는 프롬프트를 정제하지 않고 그대로 Gemini에게 전달
- **범위 제한**: 파일 경로 + 라인 범위로 작업 범위를 명확히 지정
- **Git 브랜치 격리**: Gemini 작업은 별도 브랜치에서 수행
- **범위 외 변경 탐지**: 지정 범위 외 수정사항을 탐지하고 분류
- **사용자 최종 결정**: 4가지 옵션으로 채택/거부 선택권 보장

---

## 워크플로우 개요

```
[범위 확인] → [브랜치 생성] → [Gemini 실행] → [범위 검증] → [Claude 리뷰] → [사용자 결정] → [커밋]
```

---

## Phase 1: 범위 확인

### 1.1 범위 파싱

사용자 입력에서 변경 범위를 파싱합니다. 지원 형식:

| 형식 | 예시 | 설명 |
|------|------|------|
| 파일 전체 | `src/Button.tsx` | 파일 전체를 대상으로 |
| IDE 라인 범위 | `@src/Button.tsx#L10-50` | Claude Code IDE에서 범위 선택 시 자동 생성 |
| 라인 범위 | `src/Button.tsx#L10-50` | `@` 없이도 지원 |
| 레거시 형식 | `src/Button.tsx:10-50` | 콜론 구분자 (하위 호환) |
| 여러 파일 | `src/Button.tsx, src/Card.tsx` | 여러 파일 대상 |
| 혼합 | `@src/Button.tsx#L10-50, src/Card.tsx` | 혼합 지정 |

> **Tip**: IDE에서 코드를 선택한 후 프롬프트에 드래그하면 `@파일명#L시작-종료` 형식으로 자동 입력됩니다.

### 1.2 범위 확인 절차

1. 사용자 입력에서 파일 경로 추출
2. 라인 범위 지정 여부 확인 (`#L시작-종료` 또는 `:시작-종료` 형식)
3. `@` 접두사가 있으면 자동 제거
4. 범위가 명시되지 않은 경우, 사용자에게 확인:

```
변경할 범위를 지정해주세요:
1. 파일 전체: src/components/Button.tsx
2. 특정 라인: src/components/Button.tsx#L10-50 (또는 IDE에서 범위 선택 후 드래그)
3. 여러 파일: 쉼표로 구분

예: @src/components/Button.tsx#L20-80
```

### 1.3 원본 코드 캡처

지정된 범위의 원본 코드를 기록하여 이후 비교에 사용합니다:

```bash
# 라인 범위 지정 시
sed -n '10,50p' src/components/Button.tsx > /tmp/original_scope.txt

# 파일 전체 시
cp src/components/Button.tsx /tmp/original_scope.txt
```

---

## Phase 2: Git 브랜치 준비

### 2.1 Git 상태 확인 및 브랜치 생성

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/create-branch.sh"
```

**스크립트 동작**:
1. Git 저장소 여부 확인
2. uncommitted changes 확인 (있으면 중단)
3. 작업 브랜치 생성: `gemini-design-{timestamp}`
4. JSON 결과 반환

**실패 시 대응**:
- uncommitted changes가 있으면 사용자에게 commit 또는 stash 안내
- Git 저장소가 아니면 초기화 안내

### 2.2 브랜치 정보 기록

스크립트 출력에서 `original_branch`와 `work_branch` 값을 기록하여 이후 단계에서 사용합니다.

---

## Phase 3: Gemini 실행

### 3.1 프롬프트 구성 (핵심!)

**중요**: Claude는 사용자의 프롬프트를 정제하거나 구조화하지 않습니다. 원문을 그대로 전달하되, 범위 제한만 추가합니다.

**Gemini에게 전달할 프롬프트 형식**:

```
[작업 범위 제한]
다음 파일/범위만 수정하세요:
- {file_path}#L{start_line}-{end_line}
- {file_path2} (전체)

[사용자 요청 (원문)]
{user_prompt_verbatim}

[주의사항]
- 지정된 범위 외의 파일은 가능하면 수정하지 마세요
- 범위 외 수정이 불가피한 경우 (예: import 추가) 최소한으로 유지하세요
```

**예시**:

사용자 입력:
```
@src/components/Button.tsx#L20-50 라인의 버튼 스타일을 좀 더 모던하게 바꿔줘
```

Gemini에게 전달:
```
[작업 범위 제한]
다음 파일/범위만 수정하세요:
- src/components/Button.tsx#L20-50

[사용자 요청 (원문)]
버튼 스타일을 좀 더 모던하게 바꿔줘

[주의사항]
- 지정된 범위 외의 파일은 가능하면 수정하지 마세요
- 범위 외 수정이 불가피한 경우 (예: import 추가) 최소한으로 유지하세요
```

### 3.2 Gemini 실행

```bash
gemini -y -m gemini-3-pro-preview "<프롬프트>"
```

**옵션 설명**:
- `-y` (또는 `--yolo`): 모든 액션 자동 승인 (별도 브랜치이므로 안전)
- `-m gemini-3-pro-preview`: Gemini 3 Pro 모델 사용 (일관된 고품질 결과)

**실행 중 표시**:
```
[2/6] Gemini 실행 중...
  - 범위: src/components/Button.tsx#L20-50
  - 사용자 요청: "버튼 스타일을 좀 더 모던하게 바꿔줘"
  - 실행 중... (약 30-60초 소요)
```

### 3.3 실행 결과 처리

**성공 시**: Phase 4로 진행
**실패 시**:
1. 오류 메시지 표시
2. 사용자에게 옵션 제시:
   - 다시 시도
   - 작업 브랜치 정리 후 종료

---

## Phase 4: 범위 검증 및 Claude 리뷰

### 4.1 변경사항 분석

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/analyze-changes.sh" <original_branch> "<scope_spec>"
```

**스크립트 출력**:
- 변경된 파일 목록
- **범위 내 변경**: 지정한 파일/라인 범위 내 변경
- **범위 외 변경**: 지정 범위 밖의 변경 (탐지!)
- 범위 외 변경 사유 분류:
  - `필연적`: import 추가, type 정의 등
  - `과도한 변경`: 요청하지 않은 리팩토링 등

### 4.2 리뷰 체크리스트 적용

`references/review-checklist.md`의 체크리스트를 기반으로 변경사항을 검토합니다.

**확인 항목**:

| 심각도 | 항목 |
|--------|------|
| Critical | 보안 관련 변경, 핵심 로직 변경, 설정 파일 변경 |
| Major | 하드코딩된 값, 기존 컴포넌트 미사용, import 누락 |
| Minor | 접근성, 반응형, 주석/문서화 |

### 4.3 린트/로직 에러 수정

Claude가 직접 수정 가능한 에러를 처리합니다:
- 린트 에러 (ESLint, TypeScript 등)
- 명백한 로직 에러
- import 누락

### 4.4 리뷰 결과 보고

```markdown
## Gemini 변경사항 리뷰 결과

### 지정 범위 분석
- 요청 범위: src/components/Button.tsx#L20-50
- 실제 변경 범위: src/components/Button.tsx#L18-55
- 범위 일치도: 85%

### 범위 내 변경 요약
- 수정된 파일: 1개
- 추가: +25, 삭제: -15

### 범위 외 변경 (주의!)
| 파일 | 변경 내용 | 사유 분류 |
|------|----------|----------|
| src/components/Button.tsx:1-5 | import 추가 | 필연적 |
| src/styles/button.css | 스타일 추가 | 과도한 변경 |

### Critical 이슈
(없음 또는 목록)

### Major 이슈
(없음 또는 목록)

### Minor 이슈
(없음 또는 목록)

### Claude가 수정한 항목
- src/components/Button.tsx:23 - 린트 에러 수정 (missing semicolon)
```

---

## Phase 5: 사용자 결정

### 5.1 옵션 제시

```
변경사항을 어떻게 처리하시겠습니까?

1. 전체 적용 - Gemini가 수정한 모든 변경사항 적용
2. 지정 범위만 적용 - 요청한 범위 내 변경만 적용 (범위 외 변경 원복)
3. 전체 원복 - 모든 변경 폐기
4. 범위 외만 원복 - 범위 외 변경만 되돌리고 범위 내 변경 유지

[d] diff 보기 - 상세 변경사항 확인
```

### 5.2 각 옵션 처리

#### 옵션 1: 전체 적용

```bash
git checkout <original_branch>
git merge <work_branch> --no-ff -m "Gemini design update: <설명>"
git branch -d <work_branch>
```

#### 옵션 2: 지정 범위만 적용

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/apply-partial.sh" \
  <original_branch> <work_branch> "<scope_spec>" --scope-only
```

#### 옵션 3: 전체 원복

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/cleanup-branch.sh" \
  <original_branch> <work_branch> --force
```

#### 옵션 4: 범위 외만 원복

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/apply-partial.sh" \
  <original_branch> <work_branch> "<scope_spec>" --revert-out-of-scope
```

---

## Phase 6: 커밋

### 6.1 커밋 메시지 생성

사용자 컨펌 후 변경 내용 기반 커밋 메시지를 작성합니다:

```bash
git commit -m "$(cat <<'EOF'
feat(design): <변경 요약>

Gemini를 통한 디자인 업데이트:
- 변경 범위: <scope>
- 주요 변경: <changes>

🤖 Updated with Gemini via gemini-design-updater skill

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Gemini <noreply@google.com>
EOF
)"
```

### 6.2 사용자에게 결과 안내

```
✅ 변경사항이 적용되었습니다!

- 브랜치: main
- 커밋: abc1234
- 변경된 파일: 2개

다음 단계:
- git push로 원격에 푸시하세요
- 또는 git log로 커밋 내역을 확인하세요
```

---

## 에러 처리

### uncommitted changes 발생

```
작업 전 변경사항을 정리해주세요:
- git stash push -m "before-gemini"
- git add . && git commit -m "WIP"
```

### Gemini 실행 실패

1. 오류 메시지 확인
2. 다시 시도 또는 브랜치 정리 후 종료

### Critical 이슈 발견

1. 자동 채택 차단
2. 문제점 상세 설명
3. 수동 확인 후 결정 요청

### 범위 외 과도한 변경

1. 범위 외 변경 목록 표시
2. "지정 범위만 적용" 또는 "범위 외만 원복" 권장

---

## 진행 상황 표시

```
=== Gemini Design Updater ===

[1/6] 범위 확인 중...
  - 지정 범위: src/components/Button.tsx#L20-50
  ✓ 완료

[2/6] 브랜치 준비 중...
  - 현재 브랜치: main
  - 작업 브랜치: gemini-design-20251215-143022
  ✓ 완료

[3/6] Gemini 실행 중...
  - 사용자 요청: "버튼 스타일을 좀 더 모던하게 바꿔줘"
  - 실행 중... (약 30-60초 소요)
  ✓ 완료

[4/6] 범위 검증 중...
  - 범위 내 변경: 1개 파일
  - 범위 외 변경: 2개 (import 추가, 스타일 파일)
  ✓ 완료

[5/6] 리뷰 결과
  - Critical: 0개
  - Major: 1개
  - Minor: 2개
  - 범위 외 변경: 2개 (1개 필연적, 1개 과도함)

=== 결정 필요 ===
```

---

## 추가 리소스

### 참조 문서

- **`references/review-checklist.md`** - 상세 리뷰 체크리스트
- **`references/rollback-procedures.md`** - 롤백 및 부분 채택 절차

### 예시

- **`examples/scope-examples.md`** - 범위 지정 예시

### 스크립트

- **`scripts/create-branch.sh`** - Git 브랜치 생성
- **`scripts/analyze-changes.sh`** - 변경사항 분석 (범위 검증 포함)
- **`scripts/apply-partial.sh`** - 부분 적용/원복
- **`scripts/cleanup-branch.sh`** - 브랜치 정리

---

## 사용 팁

### 범위를 명확히 지정

범위가 명확할수록 Gemini가 집중적으로 작업합니다:
```
# 좋음 (IDE에서 범위 선택 후 드래그)
@src/components/Button.tsx#L20-50

# 좋음 (직접 입력)
src/components/Button.tsx#L20-50

# 나쁨
Button 파일 좀 수정해줘
```

### 작은 단위로 요청

복잡한 디자인 변경은 여러 번에 나눠서 요청합니다:
1. 버튼 스타일 변경
2. 카드 레이아웃 개선
3. 색상 시스템 정리

### 범위 외 변경 주의

Gemini가 범위 외 수정을 많이 했다면:
- "지정 범위만 적용" 선택
- 또는 범위를 좁혀서 다시 요청

### 원문 전달의 이점

Claude가 프롬프트를 정제하지 않으므로:
- 사용자의 의도가 그대로 전달됨
- Gemini가 창의적으로 해석할 수 있음
- 예상치 못한 좋은 결과를 얻을 수 있음
