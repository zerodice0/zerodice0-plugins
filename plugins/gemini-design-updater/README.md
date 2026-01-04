# Gemini Design Updater

> Gemini Pro를 활용한 안전한 디자인 업데이트 워크플로우

[English](#english) | [한국어](#한국어)

---

## English

A Claude Code skill that enables safe design updates using Gemini Pro with automatic review and scope validation.

### Features

- **Git Branch Isolation**: All Gemini work happens in a separate branch
- **Scope-Based Tracking**: Specify exact file/line ranges for changes
- **Automatic Review**: Claude reviews Gemini's changes for issues
- **4-Option Decision Flow**: Full control over accepting/rejecting changes
- **Out-of-Scope Detection**: Identifies changes outside requested range

### Requirements

- Claude Code CLI
- Gemini CLI (`npm install -g @google/gemini-cli` or equivalent)
- Git 2.0+
- Bash 4.0+

### Usage

**Method 1: Slash Command (Recommended)**
```
/gemini-design
```

**Method 2: Natural Language**
```
gemini-design 스킬 사용해줘
```

**Method 3: With Scope**
```
@src/components/Button.tsx#L20-50 이 버튼을 Gemini로 모던하게 바꿔줘
```

2. Claude will:
   - Create a work branch
   - Run Gemini with your request
   - Review changes and report issues
   - Present 4 options for handling changes

3. Choose an option:
   - **Option 1**: Apply all changes
   - **Option 2**: Apply only in-scope changes
   - **Option 3**: Revert everything
   - **Option 4**: Revert only out-of-scope changes

### Scope Specification

| Format | Example | Description |
|--------|---------|-------------|
| Full file | `src/Button.tsx` | Target entire file |
| IDE range | `@src/Button.tsx#L10-50` | Auto-generated from IDE selection |
| Line range | `src/Button.tsx#L10-50` | Without @ prefix |
| Legacy | `src/Button.tsx:10-50` | Colon separator |
| Multiple | `src/Button.tsx, src/Card.tsx` | Multiple files |

### Scripts

- `create-branch.sh` - Creates isolated work branch
- `analyze-changes.sh` - Analyzes changes with scope validation
- `apply-partial.sh` - Partial apply/revert
- `cleanup-branch.sh` - Cleans up work branch

---

## 한국어

Gemini Pro를 활용하여 디자인을 안전하게 업데이트하는 Claude Code skill입니다.

### 기능

- **Git 브랜치 격리**: 모든 Gemini 작업은 별도 브랜치에서 수행
- **범위 기반 추적**: 정확한 파일/라인 범위 지정 가능
- **자동 리뷰**: Claude가 Gemini 변경사항을 자동으로 검토
- **4가지 선택지**: 변경사항 채택/거부에 대한 완전한 제어권
- **범위 외 변경 탐지**: 요청 범위 외 변경사항 자동 식별

### 요구사항

- Claude Code CLI
- Gemini CLI (`npm install -g @google/gemini-cli` 또는 동등한 방법)
- Git 2.0+
- Bash 4.0+

### 사용법

**방법 1: 슬래시 명령어 (권장)**
```
/gemini-design
```

**방법 2: 자연어로 호출**
```
gemini-design 스킬 사용해줘
```

**방법 3: 범위와 함께 호출**
```
@src/components/Button.tsx#L20-50 이 버튼을 Gemini로 모던하게 바꿔줘
```

2. Claude가 다음을 수행합니다:
   - 작업 브랜치 생성
   - Gemini 실행
   - 변경사항 리뷰 및 이슈 보고
   - 4가지 처리 옵션 제시

3. 옵션을 선택합니다:
   - **옵션 1**: 모든 변경사항 적용
   - **옵션 2**: 지정 범위 내 변경만 적용
   - **옵션 3**: 모든 변경 취소
   - **옵션 4**: 범위 외 변경만 되돌리기

### 범위 지정 형식

| 형식 | 예시 | 설명 |
|------|------|------|
| 파일 전체 | `src/Button.tsx` | 파일 전체 대상 |
| IDE 범위 | `@src/Button.tsx#L10-50` | IDE 선택 시 자동 생성 |
| 라인 범위 | `src/Button.tsx#L10-50` | @ 없이 직접 지정 |
| 레거시 | `src/Button.tsx:10-50` | 콜론 구분자 |
| 여러 파일 | `src/Button.tsx, src/Card.tsx` | 쉼표로 구분 |

### 스크립트

- `create-branch.sh` - 격리된 작업 브랜치 생성
- `analyze-changes.sh` - 범위 검증 포함 변경사항 분석
- `apply-partial.sh` - 부분 적용/원복
- `cleanup-branch.sh` - 작업 브랜치 정리

---

## License

MIT License - see [LICENSE](../../LICENSE) for details.

## Author

- **zerodice0** - [GitHub](https://github.com/zerodice0)
