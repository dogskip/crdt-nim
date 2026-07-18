## Vector Clock (벡터 클럭)
##
## 분산 시스템에서 이벤트 간의 인과 관계(causality)를 추적하는 자료구조.
## 각 노드마다 카운터를 유지하며, 메시지 수신 시 송신자의 벡터와 병합한다.
##
## 수학적 정의:
##   - 상태: VC: NodeId -> uint64
##   - tick(n): VC[n] += 1
##   - merge(A, B): 각 n 에 대해 max(A[n], B[n])
##   - compare(A, B):
##       A < B  iff ∀n. A[n] ≤ B[n] ∧ ∃n. A[n] < B[n]
##       A = B  iff ∀n. A[n] = B[n]
##       A || B (동시) iff ¬(A ≤ B) ∧ ¬(B ≤ A)
##
## 활용:
##   - CRDT 병합 순서 검증
##   - 동시 갱신 감지
##   - 인과적 순서 보장 메시징
##
## 보안 고려:
##   - NodeId 는 신뢰할 수 있는 노드만 등록되어야 한다.
##   - 카운터는 단조 증가해야 하며, 외부에서 임의 값 주입을 막아야 한다.

import std/tables
import std/sets
import std/algorithm
import std/sequtils
import ./crdt

type
  VectorClock* = ref object
    ## 노드별 카운터 테이블을 유지하는 벡터 클럭.
    clocks: Table[NodeId, uint64]

proc newVectorClock*(): VectorClock =
  ## 빈 벡터 클럭을 생성한다.
  result = VectorClock(clocks: initTable[NodeId, uint64]())

proc tick*(vc: VectorClock, node: NodeId) =
  ## 노드 node 의 카운터를 1 증가시킨다.
  ## 이 노드가 이벤트를 발생시켰음을 기록한다.
  vc.clocks[node] = vc.clocks.getOrDefault(node) + 1

proc get*(vc: VectorClock, node: NodeId): uint64 =
  ## 노드 node 의 현재 카운터 값을 반환한다. 없으면 0.
  result = vc.clocks.getOrDefault(node)

proc merge*(a: VectorClock, b: VectorClock): VectorClock =
  ## 두 벡터 클럭을 병합한다. 각 노드마다 더 큰 값을 취한다.
  result = newVectorClock()
  for n, c in tables.pairs(a.clocks):
    result.clocks[n] = c
  for n, c in tables.pairs(b.clocks):
    result.clocks[n] = max(c, result.clocks.getOrDefault(n))

proc mergeInto*(dst: VectorClock, src: VectorClock) =
  ## src 를 dst 에 흡수한다. in-place 병합.
  for n, c in tables.pairs(src.clocks):
    dst.clocks[n] = max(c, dst.clocks.getOrDefault(n))

type
  ClockOrder* = enum
    coBefore      ## a 가 b 보다 선행
    coAfter       ## a 가 b 보다 후행
    coEqual       ## a 와 b 가 동일
    coConcurrent  ## a 와 b 가 동시 (인과 관계 없음)

proc compare*(a: VectorClock, b: VectorClock): ClockOrder =
  ## 두 벡터 클럭의 인과 관계를 판별한다.
  var
    aLess = false
    bLess = false
  # 모든 노드에 대해 비교하며 한쪽이라도 작은 게 있는지 확인
  let nodesA = toSeq(tables.keys(a.clocks))
  let nodesB = toSeq(tables.keys(b.clocks))
  var nodeSet = initHashSet[NodeId]()
  for n in nodesA: nodeSet.incl(n)
  for n in nodesB: nodeSet.incl(n)
  for n in sets.items(nodeSet):
    let av = a.clocks.getOrDefault(n)
    let bv = b.clocks.getOrDefault(n)
    if av < bv: aLess = true
    elif av > bv: bLess = true
  if aLess and bLess: result = coConcurrent
  elif aLess: result = coBefore
  elif bLess: result = coAfter
  else: result = coEqual

proc `==`*(a, b: VectorClock): bool =
  result = compare(a, b) == coEqual

proc happensBefore*(a: VectorClock, b: VectorClock): bool =
  ## a 가 b 보다 먼저 발생했는지 (인과적으로 선행하는지) 확인한다.
  result = compare(a, b) == coBefore

proc isConcurrentWith*(a: VectorClock, b: VectorClock): bool =
  ## a 와 b 가 동시에 발생했는지 (인과 관계가 없는지) 확인한다.
  result = compare(a, b) == coConcurrent

proc nodes*(vc: VectorClock): seq[NodeId] =
  ## 벡터 클럭에 등록된 모든 노드를 반환한다.
  result = toSeq(tables.keys(vc.clocks))

proc copy*(vc: VectorClock): VectorClock =
  ## 벡터 클럭의 복사본을 만든다.
  result = newVectorClock()
  for n, c in tables.pairs(vc.clocks):
    result.clocks[n] = c
