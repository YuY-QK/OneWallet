#!/usr/bin/env bash
# 合并前的全部自动检查。在仓库根目录运行：tools/check.sh
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== 依赖 ==";        flutter pub get >/dev/null
echo "== 格式 ==";        dart format --output=none --set-exit-if-changed .
echo "== 静态检查 ==";    flutter analyze
echo "== 依赖边界 ==";    dart run tools/ci/check_deps.dart

for dir in packages/*/; do
  [ -d "${dir}test" ] && [ -n "$(ls -A "${dir}test" 2>/dev/null)" ] || continue
  echo "== 测试 ${dir} =="
  if grep -q "sdk: flutter" "${dir}pubspec.yaml"; then
    (cd "$dir" && flutter test)
  else
    (cd "$dir" && dart test)
  fi
done
echo "== 测试 app/ =="; (cd app && flutter test)
echo "全部通过"
