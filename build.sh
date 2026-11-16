#!/usr/bin/env bash
# 打包 Magisk / KernelSU / APatch 可刷入模块 zip
# 依赖：zip 或 python3（二选一）
set -euo pipefail
cd "$(dirname "$0")"

VER=$(grep -E '^version=' module.prop | cut -d= -f2)
OUT="dist/tapwake-${VER}.zip"
FILES="module.prop config.sh service.sh post-fs-data.sh uninstall.sh daemon.sh"

mkdir -p dist
rm -f "$OUT"

if command -v zip >/dev/null 2>&1; then
  # module.prop 必须在 zip 根目录
  zip -r -X -9 "$OUT" $FILES >/dev/null
else
  python3 - "$OUT" $FILES <<'PY'
import os, sys, zipfile
out, files = sys.argv[1], sys.argv[2:]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for f in files:
        zi = zipfile.ZipInfo(f, date_time=(2025, 1, 1, 0, 0, 0))
        zi.compress_type = zipfile.ZIP_DEFLATED
        zi.external_attr = (0o755 if f.endswith(".sh") else 0o644) << 16
        with open(f, "rb") as fh:
            z.writestr(zi, fh.read())
PY
fi

echo "built: $OUT"
unzip -l "$OUT" 2>/dev/null || python3 -c "import zipfile,sys;print(zipfile.ZipFile(sys.argv[1]).namelist())" "$OUT"
