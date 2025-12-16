# Gemini Image Generator

[English](#english) | [한국어](#한국어)

---

## English

A Claude Code plugin that generates app assets (icons, backgrounds, UI elements) using Gemini 3 Pro Preview model.

### Features

- **Multi-format support**: SVG (default), PNG, WebP
- **Multi-platform resolution**:
  - Flutter: 1.0x, 1.5x, 2.0x, 3.0x, 4.0x
  - iOS: @1x, @2x, @3x
  - Android: mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi
  - Web: 1x, 2x
- **Image transformation**: Modify existing images while maintaining style
- **User-specified paths**: Save to any location you choose

### Prerequisites

- [Gemini CLI](https://github.com/google/generative-ai-cli) installed and configured
- For image resizing: ImageMagick or macOS built-in `sips`

### Usage

#### Basic Image Generation
```
"Create a login button icon, save to ./assets/icons/"
```

#### Multi-resolution Generation
```
"Create an app logo and save in 1x, 2x, 3x sizes for Flutter project"
```

#### Style Specification
```
"Create a minimal settings icon, white background with blue lines"
```

#### Image Transformation
```
"@assets/icon.png Transform this icon to a more rounded style"
```

### Supported Formats

| Format | Best For | Features |
|--------|----------|----------|
| SVG | Icons, logos, simple graphics | Vector, scalable, small file size |
| PNG | Complex images, transparency | Lossless, transparent background |
| WebP | Web optimization | 25-34% smaller than PNG |

### Workflow

1. **Request Analysis** - Parse user prompt and identify image type
2. **Format Confirmation** - Confirm format and save path if not specified
3. **Image Generation** - Call Gemini 3 Pro Preview model
4. **Size Conversion** - Generate multi-resolution versions (optional)
5. **Save & Complete** - Save to specified path and report results

### Scripts

- `scripts/resize-image.sh` - Multi-resolution conversion script

### Examples

See [examples/prompt-examples.md](examples/prompt-examples.md) for more prompt examples.

---

## 한국어

Gemini 3 Pro Preview 모델을 사용하여 앱 에셋(아이콘, 배경, UI 요소)을 생성하는 Claude Code 플러그인입니다.

### 기능

- **다중 포맷 지원**: SVG (기본값), PNG, WebP
- **멀티 플랫폼 해상도**:
  - Flutter: 1.0x, 1.5x, 2.0x, 3.0x, 4.0x
  - iOS: @1x, @2x, @3x
  - Android: mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi
  - Web: 1x, 2x
- **이미지 변형**: 기존 이미지를 참조하여 스타일 유지하며 수정
- **사용자 지정 경로**: 원하는 위치에 저장

### 사전 요구사항

- [Gemini CLI](https://github.com/google/generative-ai-cli) 설치 및 설정
- 이미지 크기 변환: ImageMagick 또는 macOS 내장 `sips`

### 사용법

#### 기본 이미지 생성
```
"로그인 버튼 아이콘 생성해줘, 저장 경로는 ./assets/icons/"
```

#### 멀티 해상도 생성
```
"앱 로고 생성하고 Flutter 프로젝트에 맞게 1x, 2x, 3x 크기로 저장해줘"
```

#### 스타일 지정
```
"미니멀한 스타일의 설정 아이콘 만들어줘, 흰색 배경에 파란색 라인"
```

#### 이미지 변형
```
"@assets/icon.png 이 아이콘을 참조해서 더 둥근 스타일로 변형해줘"
```

### 지원 포맷

| 포맷 | 적합한 용도 | 특징 |
|------|-------------|------|
| SVG | 아이콘, 로고, 단순 그래픽 | 벡터, 무한 확대 가능, 파일 크기 작음 |
| PNG | 복잡한 이미지, 투명도 필요 | 무손실 압축, 투명 배경 지원 |
| WebP | 웹 최적화, 파일 크기 중요 | PNG보다 25-34% 작은 파일 크기 |

### 워크플로우

1. **요청 분석** - 사용자 프롬프트 파싱 및 이미지 유형 식별
2. **포맷 확인** - 포맷 및 저장 경로가 지정되지 않은 경우 확인
3. **이미지 생성** - Gemini 3 Pro Preview 모델 호출
4. **크기 변환** - 멀티 해상도 버전 생성 (선택사항)
5. **저장 및 완료** - 지정된 경로에 저장 및 결과 보고

### 스크립트

- `scripts/resize-image.sh` - 멀티 해상도 변환 스크립트

### 예시

더 많은 프롬프트 예시는 [examples/prompt-examples.md](examples/prompt-examples.md)를 참조하세요.

---

## License

MIT License

## Author

zerodice0
