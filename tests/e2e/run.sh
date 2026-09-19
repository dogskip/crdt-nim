#!/bin/sh
## 소비자 관점 검사: 이 저장소를 패키지로 설치한 뒤 별도 프로젝트에서 사용한다.
## nimble 디렉터리를 임시로 잡아 전역 설치를 건드리지 않는다.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

NIMBLE_DIR="$work/nimbledir"
export NIMBLE_DIR
mkdir -p "$NIMBLE_DIR"

# 패키지 목록을 미리 받아 둔다. 없으면 nimble 이 물어보는데, 물어볼 상대가 없는
# 환경에서는 그 자리에서 EOF 로 실패한다.
nimble refresh >/dev/null 2>&1 || echo "[e2e] 패키지 목록을 받지 못했습니다"

echo "[e2e] 패키지 설치: $root"
cd "$root" && nimble install -y

echo "[e2e] 소비자 프로젝트 컴파일·실행"
cd "$here" && nimble c -y -r --hints:off consumer.nim
