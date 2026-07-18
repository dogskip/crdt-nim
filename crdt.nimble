# Package definition for crdt-nim
# Nim 으로 구현한 CRDT (Conflict-free Replicated Data Type) 라이브러리.
# 분산 시스템에서 최종적 일관성을 보장하는 자료구조 모음.

version       = "0.1.0"
author        = "dogskip"
description   = "Conflict-free Replicated Data Types for Nim"
license       = "MIT"
srcDir        = "src"

# Nim 2.0 이상을 요구한다. distinct string, borrow pragma 등 최신 기능 사용.
requires "nim >= 2.0.0"

# 테스트 실행 진입점. nimble test 가 이 task 를 호출한다.
task test, "CRDT 단위 테스트 실행":
  # tests 디렉토리의 통합 테스트를 컴파일/실행한다.
  exec "nim c -r tests/test_all.nim"
