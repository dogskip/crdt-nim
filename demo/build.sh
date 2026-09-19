#!/bin/sh
## 데모 화면이 쓰는 JS 를 만든다.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/.." && pwd)

nim js -d:release --hints:off --path:"$root/src" -o:"$here/demo.js" "$here/demo.nim"
echo "[demo] $here/demo.js 생성"
