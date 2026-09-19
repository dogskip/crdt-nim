## 노드마다 사건 번호를 두고 두 시계의 인과 관계를 판별하는 자료구조.

import std/sequtils
import std/tables
import ./common

type
  VectorClock* = ref object
    clocks: Table[NodeId, uint64]

  ClockOrder* = enum
    coBefore     ## a 가 b 보다 먼저 일어남
    coAfter      ## a 가 b 보다 나중
    coEqual      ## 두 시계가 같음
    coConcurrent ## 어느 쪽도 먼저가 아님

proc newVectorClock*(): VectorClock =
  result = VectorClock(clocks: initTable[NodeId, uint64]())

proc tick*(vc: VectorClock, node: NodeId) =
  vc.clocks[node] = vc.clocks.getOrDefault(node) + 1

proc get*(vc: VectorClock, node: NodeId): uint64 =
  result = vc.clocks.getOrDefault(node)

proc mergeInto*(dst, src: VectorClock) =
  for n, c in tables.pairs(src.clocks):
    dst.clocks[n] = max(c, dst.clocks.getOrDefault(n))

proc merge*(a, b: VectorClock): VectorClock =
  result = newVectorClock()
  result.mergeInto(a)
  result.mergeInto(b)

proc compare*(a, b: VectorClock): ClockOrder =
  var
    aLess = false
    bLess = false
  for n, av in tables.pairs(a.clocks):
    let bv = b.clocks.getOrDefault(n)
    if av < bv: aLess = true
    elif av > bv: bLess = true
  for n, bv in tables.pairs(b.clocks):
    let av = a.clocks.getOrDefault(n)
    if av < bv: aLess = true
    elif av > bv: bLess = true
  if aLess and bLess: result = coConcurrent
  elif aLess: result = coBefore
  elif bLess: result = coAfter
  else: result = coEqual

proc `==`*(a, b: VectorClock): bool =
  result = compare(a, b) == coEqual

proc happensBefore*(a, b: VectorClock): bool =
  result = compare(a, b) == coBefore

proc isConcurrentWith*(a, b: VectorClock): bool =
  result = compare(a, b) == coConcurrent

proc nodes*(vc: VectorClock): seq[NodeId] =
  result = toSeq(tables.keys(vc.clocks))

proc copy*(vc: VectorClock): VectorClock =
  result = newVectorClock()
  result.mergeInto(vc)
