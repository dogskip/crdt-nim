## 데모 화면이 호출하는 함수들. 이 모듈만 JS 로 컴파일한다.

import std/strutils
import crdt

const Values = ["1", "2", "3", "4", "5"]

var
  replicas: array[2, TwoPSet[string]]
  merged: TwoPSet[string]

proc stateOf(s: TwoPSet[string]): string =
  ## 화면에 보여 줄 값만 골라 잇는다. 값이 없으면 "-".
  var alive: seq[string]
  for v in Values:
    if s.contains(v):
      alive.add v
  result = if alive.len == 0: "-" else: alive.join(",")

proc demoReset() {.exportc.} =
  ## 두 복제본과 병합 결과를 비운다.
  for i in 0 .. replicas.high:
    replicas[i] = newTwoPSet[string]()
  merged = newTwoPSet[string]()

proc demoAdd(replica: int, value: cstring) {.exportc.} =
  if replica in 0 .. replicas.high:
    replicas[replica].add $value

proc demoRemove(replica: int, value: cstring) {.exportc.} =
  if replica in 0 .. replicas.high:
    discard replicas[replica].remove $value

proc demoMerge() {.exportc.} =
  ## 서로 흡수시킨 뒤 결과를 보여 준다. 병합 뒤에는 세 패널이 같아진다.
  replicas[0].mergeInto(replicas[1])
  replicas[1].mergeInto(replicas[0])
  merged = merge(replicas[0], replicas[1])

proc demoState(replica: int): cstring {.exportc.} =
  ## 0 과 1 은 복제본, 그 밖의 값은 병합 결과.
  ## 경계를 넘는 값은 cstring 이다. Nim 의 string 은 JS 에서 문자 코드 배열이 된다.
  case replica
  of 0, 1: result = cstring(stateOf(replicas[replica]))
  else: result = cstring(stateOf(merged))

demoReset()
