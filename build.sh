#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SCHEME="LLM"
CONFIGURATION="Release"
OUTPUT_DIR="$SCRIPT_DIR/build-artifacts"
SKIP_UNAVAILABLE=0

usage() {
  cat <<EOF
Usage: ./build.sh [options]

Options:
  --scheme <name>          Xcode scheme to build (default: LLM)
  --output <path>          Output directory (default: ./build-artifacts)
  --skip-unavailable       Skip unavailable destinations (e.g. missing tvOS SDK)
  -h, --help               Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scheme)
      SCHEME="${2:?missing value for --scheme}"
      shift 2
      ;;
    --output)
      OUTPUT_DIR="${2:?missing value for --output}"
      shift 2
      ;;
    --skip-unavailable)
      SKIP_UNAVAILABLE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

TMP_DIR="$SCRIPT_DIR/.build-xcframework"
DERIVED_BASE="$TMP_DIR/derived"
SLICES_DIR="$TMP_DIR/slices"
LOGS_DIR="$TMP_DIR/logs"
XCFRAMEWORK_PATH="$OUTPUT_DIR/LLM.xcframework"
LLAMA_SOURCE="$SCRIPT_DIR/llama.cpp/llama.xcframework"
LLAMA_OUTPUT="$OUTPUT_DIR/llama.xcframework"

rm -rf "$TMP_DIR" "$XCFRAMEWORK_PATH" "$LLAMA_OUTPUT"
mkdir -p "$DERIVED_BASE" "$SLICES_DIR" "$LOGS_DIR" "$OUTPUT_DIR"

declare -a TARGETS=(
  "ios|generic/platform=iOS|Release-iphoneos"
  "ios-simulator|generic/platform=iOS Simulator|Release-iphonesimulator"
  "maccatalyst|generic/platform=macOS,variant=Mac Catalyst|Release-maccatalyst"
  "macos|generic/platform=macOS|Release"
  "visionos|generic/platform=visionOS|Release-xros"
  "visionos-simulator|generic/platform=visionOS Simulator|Release-xrsimulator"
  "tvos|generic/platform=tvOS|Release-appletvos"
  "tvos-simulator|generic/platform=tvOS Simulator|Release-appletvsimulator"
)

declare -a CREATE_ARGS=()
declare -a BUILT_SLICES=()

build_slice() {
  local name="$1"
  local destination="$2"
  local release_dir="$3"

  local dd="$DERIVED_BASE/$name"
  local log="$LOGS_DIR/$name.log"
  rm -rf "$dd"

  echo "==> Building $name ($destination)"
  if ! xcodebuild build \
      -scheme "$SCHEME" \
      -destination "$destination" \
      -configuration "$CONFIGURATION" \
      -derivedDataPath "$dd" \
      SKIP_INSTALL=NO \
      BUILD_LIBRARY_FOR_DISTRIBUTION=NO \
      ONLY_ACTIVE_ARCH=NO \
      >"$log" 2>&1; then
    if [[ "$SKIP_UNAVAILABLE" -eq 1 ]] && grep -Eq "Unable to find a destination matching|Ineligible destinations" "$log"; then
      echo "    Skipping unavailable destination: $destination"
      return 0
    fi
    echo "Build failed for $name. Log: $log" >&2
    tail -n 80 "$log" >&2 || true
    exit 1
  fi

  local products="$dd/Build/Products/$release_dir"
  local object_file="$products/LLM.o"
  local module_dir="$products/LLM.swiftmodule"
  local slice_dir="$SLICES_DIR/$name"
  local lib_path="$slice_dir/libLLM.a"

  if [[ ! -f "$object_file" ]]; then
    echo "Expected object file missing: $object_file" >&2
    exit 1
  fi
  if [[ ! -d "$module_dir" ]]; then
    echo "Expected swiftmodule directory missing: $module_dir" >&2
    exit 1
  fi

  mkdir -p "$slice_dir"
  rm -f "$lib_path"
  libtool -static -o "$lib_path" "$object_file"
  cp -R "$module_dir" "$slice_dir/LLM.swiftmodule"

  CREATE_ARGS+=(-library "$lib_path")
  BUILT_SLICES+=("$name")
}

for target in "${TARGETS[@]}"; do
  IFS="|" read -r name destination release_dir <<< "$target"
  build_slice "$name" "$destination" "$release_dir"
done

if [[ "${#BUILT_SLICES[@]}" -eq 0 ]]; then
  echo "No slices were built. Nothing to package." >&2
  exit 1
fi

echo "==> Creating $XCFRAMEWORK_PATH"
xcodebuild -create-xcframework "${CREATE_ARGS[@]}" -output "$XCFRAMEWORK_PATH" >/dev/null

if [[ -d "$LLAMA_SOURCE" ]]; then
  echo "==> Copying dependency xcframework to $LLAMA_OUTPUT"
  cp -R "$LLAMA_SOURCE" "$LLAMA_OUTPUT"
fi

echo "Done."
echo "Built slices: ${BUILT_SLICES[*]}"
echo "LLM xcframework: $XCFRAMEWORK_PATH"
if [[ -d "$LLAMA_OUTPUT" ]]; then
  echo "llama dependency: $LLAMA_OUTPUT"
fi
