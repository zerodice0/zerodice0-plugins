#!/bin/bash
set -euo pipefail

# =============================================================================
# resize-image.sh
# 이미지를 플랫폼별 멀티 해상도로 변환
#
# 사용법:
#   ./resize-image.sh <input_image> <output_dir> <platform> [base_size]
#
# 플랫폼:
#   flutter  - 1.0x, 1.5x, 2.0x, 3.0x, 4.0x
#   ios      - @1x, @2x, @3x
#   android  - mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi
#   web      - 1x, 2x
#   all      - 모든 플랫폼
# =============================================================================

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 사용법 출력
usage() {
    echo -e "${BLUE}=== Gemini Image Generator - Resize Script ===${NC}"
    echo ""
    echo "사용법: $0 <input_image> <output_dir> <platform> [base_size]"
    echo ""
    echo "플랫폼:"
    echo "  flutter  - 1.0x, 1.5x, 2.0x, 3.0x, 4.0x"
    echo "  ios      - @1x, @2x, @3x"
    echo "  android  - mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi"
    echo "  web      - 1x, 2x"
    echo "  all      - 모든 플랫폼"
    echo ""
    echo "예시:"
    echo "  $0 icon.png ./assets flutter"
    echo "  $0 logo.png ./res android 48"
    exit 1
}

# 인자 확인
if [[ $# -lt 3 ]]; then
    usage
fi

INPUT_IMAGE="$1"
OUTPUT_DIR="$2"
PLATFORM="$3"
BASE_SIZE="${4:-}"

# 입력 파일 확인
if [[ ! -f "$INPUT_IMAGE" ]]; then
    echo -e "${RED}Error: 입력 파일을 찾을 수 없습니다: $INPUT_IMAGE${NC}"
    exit 1
fi

# 파일명 추출
FILENAME=$(basename "$INPUT_IMAGE")
NAME="${FILENAME%.*}"
EXT="${FILENAME##*.}"

# SVG는 변환 불필요 안내
if [[ "$EXT" == "svg" ]]; then
    echo -e "${YELLOW}Info: SVG 파일은 벡터 포맷이므로 크기 변환이 필요 없습니다.${NC}"
    echo -e "${YELLOW}      각 플랫폼 폴더에 원본 파일을 복사합니다.${NC}"
fi

# 이미지 변환 도구 확인
if command -v convert &> /dev/null; then
    RESIZE_TOOL="imagemagick"
elif command -v sips &> /dev/null; then
    RESIZE_TOOL="sips"
else
    echo -e "${RED}Error: ImageMagick 또는 sips가 필요합니다.${NC}"
    echo -e "${YELLOW}macOS: sips는 기본 설치되어 있습니다.${NC}"
    echo -e "${YELLOW}다른 OS: brew install imagemagick 또는 apt install imagemagick${NC}"
    exit 1
fi

echo -e "${BLUE}=== 이미지 크기 변환 ===${NC}"
echo -e "입력: $INPUT_IMAGE"
echo -e "출력: $OUTPUT_DIR"
echo -e "플랫폼: $PLATFORM"
echo -e "도구: $RESIZE_TOOL"
echo ""

# 이미지 크기 가져오기
get_image_size() {
    local img="$1"
    if [[ "$RESIZE_TOOL" == "imagemagick" ]]; then
        identify -format "%wx%h" "$img" 2>/dev/null
    else
        local w=$(sips -g pixelWidth "$img" 2>/dev/null | tail -1 | awk '{print $2}')
        local h=$(sips -g pixelHeight "$img" 2>/dev/null | tail -1 | awk '{print $2}')
        echo "${w}x${h}"
    fi
}

# 이미지 리사이즈
resize_image() {
    local input="$1"
    local output="$2"
    local scale="$3"

    # 원본 크기 가져오기
    local size=$(get_image_size "$input")
    local orig_w="${size%x*}"
    local orig_h="${size#*x}"

    # 새 크기 계산
    local new_w=$(echo "$orig_w * $scale" | bc | cut -d. -f1)
    local new_h=$(echo "$orig_h * $scale" | bc | cut -d. -f1)

    # 출력 디렉토리 생성
    mkdir -p "$(dirname "$output")"

    if [[ "$EXT" == "svg" ]]; then
        # SVG는 그대로 복사
        cp "$input" "$output"
    elif [[ "$RESIZE_TOOL" == "imagemagick" ]]; then
        convert "$input" -resize "${new_w}x${new_h}" "$output"
    else
        cp "$input" "$output"
        sips -z "$new_h" "$new_w" "$output" > /dev/null 2>&1
    fi

    echo -e "  ${GREEN}✓${NC} $output (${new_w}x${new_h})"
}

# 스케일 다운 (1x 기준으로)
resize_with_base() {
    local input="$1"
    local output="$2"
    local scale="$3"
    local base="$4"

    local new_size=$(echo "$base * $scale" | bc | cut -d. -f1)

    mkdir -p "$(dirname "$output")"

    if [[ "$EXT" == "svg" ]]; then
        cp "$input" "$output"
    elif [[ "$RESIZE_TOOL" == "imagemagick" ]]; then
        convert "$input" -resize "${new_size}x${new_size}" "$output"
    else
        cp "$input" "$output"
        sips -z "$new_size" "$new_size" "$output" > /dev/null 2>&1
    fi

    echo -e "  ${GREEN}✓${NC} $output (${new_size}x${new_size})"
}

# Flutter 변환
resize_flutter() {
    echo -e "${BLUE}[Flutter] 변환 중...${NC}"
    local scales=("1.0" "1.5" "2.0" "3.0" "4.0")

    for scale in "${scales[@]}"; do
        local dir="${OUTPUT_DIR}/images/${scale}x"
        resize_image "$INPUT_IMAGE" "${dir}/${FILENAME}" "$scale"
    done
}

# iOS 변환
resize_ios() {
    echo -e "${BLUE}[iOS] 변환 중...${NC}"
    local imageset_dir="${OUTPUT_DIR}/${NAME}.imageset"
    mkdir -p "$imageset_dir"

    # @1x
    resize_image "$INPUT_IMAGE" "${imageset_dir}/${NAME}.${EXT}" "1"
    # @2x
    resize_image "$INPUT_IMAGE" "${imageset_dir}/${NAME}@2x.${EXT}" "2"
    # @3x
    resize_image "$INPUT_IMAGE" "${imageset_dir}/${NAME}@3x.${EXT}" "3"

    # Contents.json 생성
    cat > "${imageset_dir}/Contents.json" << EOF
{
  "images": [
    {
      "filename": "${NAME}.${EXT}",
      "idiom": "universal",
      "scale": "1x"
    },
    {
      "filename": "${NAME}@2x.${EXT}",
      "idiom": "universal",
      "scale": "2x"
    },
    {
      "filename": "${NAME}@3x.${EXT}",
      "idiom": "universal",
      "scale": "3x"
    }
  ],
  "info": {
    "author": "gemini-image-generator",
    "version": 1
  }
}
EOF
    echo -e "  ${GREEN}✓${NC} ${imageset_dir}/Contents.json"
}

# Android 변환
resize_android() {
    echo -e "${BLUE}[Android] 변환 중...${NC}"

    # Android DPI 스케일 (mdpi = 1x 기준)
    # mdpi: 1x, hdpi: 1.5x, xhdpi: 2x, xxhdpi: 3x, xxxhdpi: 4x

    local base="${BASE_SIZE:-48}"

    resize_with_base "$INPUT_IMAGE" "${OUTPUT_DIR}/drawable-mdpi/${NAME}.${EXT}" "1" "$base"
    resize_with_base "$INPUT_IMAGE" "${OUTPUT_DIR}/drawable-hdpi/${NAME}.${EXT}" "1.5" "$base"
    resize_with_base "$INPUT_IMAGE" "${OUTPUT_DIR}/drawable-xhdpi/${NAME}.${EXT}" "2" "$base"
    resize_with_base "$INPUT_IMAGE" "${OUTPUT_DIR}/drawable-xxhdpi/${NAME}.${EXT}" "3" "$base"
    resize_with_base "$INPUT_IMAGE" "${OUTPUT_DIR}/drawable-xxxhdpi/${NAME}.${EXT}" "4" "$base"
}

# Web 변환
resize_web() {
    echo -e "${BLUE}[Web] 변환 중...${NC}"

    resize_image "$INPUT_IMAGE" "${OUTPUT_DIR}/${NAME}.${EXT}" "1"
    resize_image "$INPUT_IMAGE" "${OUTPUT_DIR}/${NAME}@2x.${EXT}" "2"
}

# 플랫폼별 실행
case "$PLATFORM" in
    flutter)
        resize_flutter
        ;;
    ios)
        resize_ios
        ;;
    android)
        resize_android
        ;;
    web)
        resize_web
        ;;
    all)
        resize_flutter
        echo ""
        resize_ios
        echo ""
        resize_android
        echo ""
        resize_web
        ;;
    *)
        echo -e "${RED}Error: 알 수 없는 플랫폼: $PLATFORM${NC}"
        usage
        ;;
esac

echo ""
echo -e "${GREEN}=== 변환 완료 ===${NC}"
echo -e "출력 디렉토리: $OUTPUT_DIR"
