---
name: gemini-image-generator
description: This skill should be used when the user asks to "generate image with Gemini", "Gemini로 이미지 생성", "create app icon", "앱 아이콘 만들어줘", "generate asset", "에셋 생성", "make background image", "배경 이미지 생성", "create UI element", "UI 요소 생성", or wants to create app assets (icons, backgrounds, UI elements) using Gemini 3 Pro Preview model. Supports multi-resolution output for Flutter, iOS, Android, and Web platforms.
---

# Gemini Image Generator

Gemini 3 Pro Preview 모델을 사용하여 앱 에셋(아이콘, 배경, UI 요소)을 생성하는 스킬입니다.

## 핵심 원칙

### 1. 사용자 프롬프트 원문 전달

Claude는 사용자의 이미지 생성 프롬프트를 정제하지 않고 그대로 Gemini에게 전달합니다.
사용자가 원하는 스타일, 색상, 분위기를 최대한 보존합니다.

### 2. 포맷 가이드

- **기본값**: SVG (벡터, 확장성 좋음, 아이콘에 적합)
- **복잡한 이미지**: PNG 또는 WebP (그라데이션, 사진같은 효과)
- 사용자가 포맷을 명시하지 않으면 이미지 특성에 따라 가이드 제공

### 3. 멀티 플랫폼 지원

다양한 플랫폼의 해상도 규격을 지원합니다:

- **Flutter**: 1.0x, 1.5x, 2.0x, 3.0x, 4.0x
- **iOS**: @1x, @2x, @3x
- **Android**: mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi
- **Web**: 1x, 2x

### 4. 사용자 지정 경로

생성된 이미지는 사용자가 지정한 경로에 저장됩니다.
경로를 명시하지 않으면 확인 후 진행합니다.

---

## 워크플로우

### Phase 1: 요청 분석 및 명확화

사용자 요청에서 다음 정보를 파악하고, **불분명한 항목이 있으면 반드시 질의하여 명확히 합니다.**

> ⚠️ **중요**: 필수 정보(이미지 유형, 저장 경로)가 불분명하면 진행하지 않고 반드시 질문합니다.

1. **이미지 유형** _(필수)_

   - `icon`: 앱 아이콘, 버튼 아이콘, 메뉴 아이콘 등
   - `background`: 배경 이미지, 패턴, 텍스처
   - `ui-element`: UI 요소, 일러스트, 장식 요소
   - `logo`: 앱 로고, 브랜드 로고
   - 🔍 **불분명 시 질의**: "어떤 유형의 이미지가 필요하신가요? (아이콘/배경/UI요소/로고)"

2. **저장 경로** _(필수)_

   - 사용자가 명시한 경로 사용
   - 🔍 **불분명 시 질의**: "이미지를 저장할 경로를 알려주세요. (예: ./assets/icons/)"

3. **출력 포맷**

   - SVG: 아이콘, 로고, 단순한 그래픽
   - PNG: 복잡한 이미지, 투명도 필요
   - WebP: 파일 크기 최적화 필요
   - 🔍 **불분명 시**: 이미지 유형에 따라 추천 포맷 제안 후 확인

4. **플랫폼 및 크기**

   - 멀티 해상도 필요 여부
   - 대상 플랫폼 (Flutter/iOS/Android/Web)
   - 🔍 **멀티 해상도 언급 시 플랫폼 불분명**: "어떤 플랫폼용으로 생성할까요? (Flutter/iOS/Android/Web)"

5. **이미지 스타일/상세 설명**

   - 색상, 스타일, 분위기 등
   - 🔍 **너무 추상적인 경우**: "원하시는 스타일을 더 구체적으로 설명해주세요. (예: 색상, 분위기, 참고 스타일)"

6. **참조 이미지** _(선택사항)_

   - 기존 이미지를 참조하여 변형하는 경우
   - `@경로` 형식으로 참조

---

### Phase 2: 포맷 및 경로 확인

사용자가 명시하지 않은 정보가 있으면 다음과 같이 확인합니다:

```
이미지 생성을 위해 몇 가지 확인이 필요합니다:

📁 저장 경로: [사용자가 지정한 경로 또는 "지정되지 않음"]
📐 출력 포맷: [추천 포맷 및 이유]
📱 멀티 해상도: [필요 여부]

진행하시겠습니까? 변경이 필요하면 말씀해주세요.
```

---

### Phase 3: 이미지 생성

Gemini 3 Pro Preview 모델을 호출합니다.

**프롬프트 구성:**

```
[이미지 생성 요청]
- 유형: {icon|background|ui-element|logo}
- 포맷: {svg|png|webp}
- 스타일: {사용자 지정 스타일}

[사용자 요청 (원문)]
{user_prompt_verbatim}

[주의사항]
- 깔끔하고 선명한 이미지 생성
- 앱 에셋으로 사용하기 적합한 품질
- 지정된 포맷에 맞는 출력
```

**Gemini 실행 명령어:**

```bash
gemini -y -m gemini-3-pro-preview "<프롬프트>"
```

---

### Phase 4: 크기 변환 (선택사항)

멀티 해상도가 필요한 경우, 생성된 이미지를 플랫폼별 크기로 변환합니다.

**플랫폼별 크기 변환 스크립트 사용:**

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/resize-image.sh <input_image> <output_dir> <platform>
```

**플랫폼별 출력 구조:**

| 플랫폼  | 폴더 구조                 | 파일명 예시                  |
| ------- | ------------------------- | ---------------------------- |
| Flutter | `assets/images/{scale}x/` | `icon.png`                   |
| iOS     | `{name}.imageset/`        | `icon@2x.png`, `icon@3x.png` |
| Android | `res/drawable-{dpi}/`     | `icon.png`                   |
| Web     | `assets/`                 | `icon.png`, `icon@2x.png`    |

---

### Phase 5: 이미지 변형 (선택사항)

기존 이미지를 참조하여 변형하는 경우:

1. 참조 이미지 경로 확인 (예: `@assets/icon.png`)
2. 이미지 내용을 Gemini에게 전달
3. 사용자 요청에 따라 스타일 변형

**변형 프롬프트 구성:**

```
[이미지 변형 요청]
- 참조 이미지: {reference_image_path}
- 변형 내용: {user_request}

[주의사항]
- 원본 이미지의 핵심 특징 유지
- 요청된 스타일 변경만 적용
```

---

### Phase 6: 저장 및 완료

생성된 이미지를 지정된 경로에 저장하고 결과를 보고합니다.

**결과 보고 형식:**

```
## 이미지 생성 완료

✅ 생성된 파일:
- {output_path}/{filename}.{format}
- {output_path}/{filename}@2x.{format} (멀티 해상도인 경우)
- ...

📝 이미지 정보:
- 유형: {image_type}
- 포맷: {format}
- 크기: {dimensions}

💡 팁: 생성된 이미지가 만족스럽지 않으면 스타일이나 색상을 더 구체적으로 지정해서 다시 요청해보세요.
```

---

## 사용 예시

### 기본 이미지 생성

```
"로그인 버튼 아이콘 생성해줘, 저장 경로는 ./assets/icons/"
```

### 멀티 해상도 생성

```
"앱 로고 생성하고 Flutter 프로젝트에 맞게 1x, 2x, 3x 크기로 저장해줘"
```

### 스타일 지정

```
"미니멀한 스타일의 설정 아이콘 만들어줘, 흰색 배경에 파란색 라인"
```

### 기존 이미지 변형

```
"@assets/icon.png 이 아이콘을 참조해서 더 둥근 스타일로 변형해줘"
```

### 포맷 지정

```
"그라데이션 배경 이미지 PNG로 생성해줘, 크기는 1920x1080"
```

---

## 지원 포맷 가이드

| 포맷 | 적합한 용도                | 특징                                 |
| ---- | -------------------------- | ------------------------------------ |
| SVG  | 아이콘, 로고, 단순 그래픽  | 벡터, 무한 확대 가능, 파일 크기 작음 |
| PNG  | 복잡한 이미지, 투명도 필요 | 무손실 압축, 투명 배경 지원          |
| WebP | 웹 최적화, 파일 크기 중요  | PNG보다 25-34% 작은 파일 크기        |

---

## 에러 처리

| 상황             | 대응                             |
| ---------------- | -------------------------------- |
| Gemini 응답 없음 | 재시도 또는 프롬프트 단순화 제안 |
| 저장 경로 없음   | 경로 생성 여부 확인              |
| 크기 변환 실패   | ImageMagick 설치 확인 안내       |
| 참조 이미지 없음 | 경로 확인 요청                   |

---

## 관련 파일

- `${CLAUDE_PLUGIN_ROOT}/scripts/resize-image.sh`: 멀티 해상도 변환 스크립트
- `${CLAUDE_PLUGIN_ROOT}/examples/prompt-examples.md`: 프롬프트 예시 모음
