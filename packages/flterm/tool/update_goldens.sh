#!/usr/bin/env bash
#
# Regenerate flterm golden test images in a pinned Linux environment. Flutter
# comes from the container image, while Zig is installed into a reusable Docker
# volume the first time the script runs.
#
# Why a container: Skia text rasterization on Linux depends on the system
# libfreetype/libpng build, which differs across distros, security updates,
# and macOS hosts. Running `flutter test --update-goldens` directly on
# macOS or vanilla Linux produces slightly different anti-aliasing and
# breaks CI.
#
# Usage:
#   packages/flterm/tool/update_goldens.sh             # update all goldens
#   packages/flterm/tool/update_goldens.sh path/...    # update a subset
#
# Requires Docker. The image, Zig installation, and Pub cache are reused across
# runs. Run from anywhere inside the repo; the script resolves the workspace
# root from its own location.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../../.." && pwd)"
readonly flutter_version='3.47.5'
readonly flutter_image="ghcr.io/gmeligio/flutter-linux:${flutter_version}"
readonly flutter_image_digest='sha256:4c07ea2b6ea99aa87d90c26541f20d3a8cc13c2e523a253560932795da909f60'
readonly platform='linux/amd64'
readonly pub_cache='flterm-pub-cache'
readonly zig_cache='flterm-zig-cache'
readonly zig_version='0.16.0'
readonly zig_image="kassany/alpine-ziglang:${zig_version}@sha256:fe91ff23f39ba362e6d37b50dc951f5e1e7f79154af9db3f6547e34378fc195b"

if ! docker image inspect "$flutter_image" >/dev/null 2>&1; then
  docker pull --platform "$platform" "$flutter_image"
fi

if ! docker image inspect \
  --format '{{range .RepoDigests}}{{println .}}{{end}}' \
  "$flutter_image" \
  | grep -Fx "ghcr.io/gmeligio/flutter-linux@${flutter_image_digest}" \
    >/dev/null; then
  echo "Unexpected digest for $flutter_image" >&2
  exit 1
fi

if ! docker run --rm \
  --platform "$platform" \
  --entrypoint test \
  -v "$zig_cache:/zig" \
  "$flutter_image" \
  -x "/zig/zig-${zig_version}/zig"; then
  docker run --rm \
    --platform "$platform" \
    --user root \
    --entrypoint sh \
    -v "$zig_cache:/cache" \
    "$zig_image" \
    -euc '
      test "$(zig version)" = "$1"
      destination="/cache/zig-$1"
      mkdir -p "$destination"
      cp -a "/zig/$1/files/." "$destination"
      chown -R 1001:1001 "$destination"
    ' sh "$zig_version"
fi

docker run --rm -i \
  --platform "$platform" \
  -v "$repo_root:/repo" \
  -v "$pub_cache:/home/flutter/.pub-cache" \
  -v "$zig_cache:/zig:ro" \
  -w /repo \
  "$flutter_image" \
  bash -c '
    set -euo pipefail
    export PATH="/zig/zig-$1:$PATH"
    shift
    flutter pub get
    cd packages/flterm
    flutter test --update-goldens --tags golden "$@"
  ' bash "$zig_version" "$@"
