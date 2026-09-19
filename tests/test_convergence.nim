## 수렴 규칙을 무작위 순서로 반복 검사한다. 이 파일이 곧 명세다.
##
## 각 검사는 무작위 연산을 복제본 여럿에 흩어 적용한 뒤, 병합 순서를 무작위로
## 섞어 서로 흡수시킨다. 씨앗이 고정되어 있어 실패하면 같은 순서로 재현된다.

import std/random
import std/sequtils
import std/sets
import std/tables
import unittest
import ../src/crdt

const
  Seed = 20260920
  Rounds = 50
  ReplicaCount = 3

proc joinAll[T: Crdt](replicas: var seq[T], r: var Rand) =
  ## 모든 복제본이 서로의 상태를 무작위 순서로 흡수하게 한다.
  ## 절반은 제자리 병합, 절반은 merge 로 새로 받는다.
  var order = toSeq(0 ..< replicas.len)
  r.shuffle(order)
  if r.rand(0 .. 1) == 1:
    for i in order:
      for j in order:
        if i != j:
          replicas[i].mergeInto(replicas[j])
  else:
    for i in order:
      for j in order:
        if i != j:
          replicas[i] = merge(replicas[i], replicas[j])

proc checkAllEqual[T: Crdt](replicas: seq[T]) =
  ## 병합이 끝나면 모든 복제본의 상태가 같아야 한다.
  for k in 1 ..< replicas.len:
    check replicas[k] == replicas[0]

proc lwwWinner(winner: var Table[int, Entry], v: int, state: EntryState, ts: Timestamp) =
  ## 명세: 더 나중 타임스탬프가 이기고, 같으면 제거가 이긴다.
  let cur = winner.getOrDefault(v)
  if ts > cur.ts:
    winner[v] = Entry(state: state, ts: ts)
  elif ts == cur.ts and state == stTombstone:
    winner[v] = Entry(state: state, ts: ts)

suite "GSet 무작위 수렴":
  test "무작위 추가는 순서와 무관하게 합집합으로 모인다":
    var r = initRand(Seed)
    for round in 0 ..< Rounds:
      var replicas = newSeqWith(ReplicaCount, newGSet[int]())
      var expected: HashSet[int]
      for rep in replicas.mitems:
        for _ in 0 ..< r.rand(0 .. 4):
          let v = r.rand(0 .. 20)
          rep.add v
          expected.incl v
      joinAll(replicas, r)
      checkAllEqual(replicas)
      check replicas[0].card == expected.len
      for v in expected:
        check v in replicas[0]

suite "2P-Set 무작위 수렴":
  test "누가 제거한 원소는 병합 뒤에도 없다":
    var r = initRand(Seed + 1)
    for round in 0 ..< Rounds:
      var replicas = newSeqWith(ReplicaCount, newTwoPSet[int]())
      var
        added: HashSet[int]
        removed: HashSet[int]
      for rep in replicas.mitems:
        for _ in 0 ..< r.rand(0 .. 5):
          let v = r.rand(0 .. 10)
          if r.rand(0 .. 1) == 1:
            rep.add v
            added.incl v
          else:
            discard rep.remove(v)
            removed.incl v
      joinAll(replicas, r)
      checkAllEqual(replicas)
      # 제거는 영구적이다. 추가를 받기 전에 제거한 복제본이 있어도 살아나지 않는다.
      for v in removed:
        check v notin replicas[0]
      for v in added:
        if v notin removed:
          check v in replicas[0]

suite "LWW-Set 무작위 수렴":
  test "가장 나중 타임스탬프가 이기고, 같으면 제거가 이긴다":
    var r = initRand(Seed + 2)
    for round in 0 ..< Rounds:
      var replicas = newSeqWith(ReplicaCount, newLWWSet[int]())
      var winner: Table[int, Entry]
      for rep in replicas.mitems:
        for _ in 0 ..< r.rand(0 .. 5):
          let
            v = r.rand(0 .. 8)
            ts = Timestamp(r.rand(0 .. 5))
          if r.rand(0 .. 1) == 1:
            rep.add(v, ts)
            lwwWinner(winner, v, stAlive, ts)
          else:
            rep.remove(v, ts)
            lwwWinner(winner, v, stTombstone, ts)
      joinAll(replicas, r)
      checkAllEqual(replicas)
      for v, entry in tables.pairs(winner):
        check replicas[0].contains(v) == (entry.state == stAlive)
      # 연산이 한 번도 없던 원소는 포함되지 않는다.
      for v in 9 .. 11:
        check v notin replicas[0]

suite "OR-Map 무작위 수렴":
  test "병합 뒤에 넣은 값은 사라지지 않는다":
    var r = initRand(Seed + 3)
    for round in 0 ..< Rounds:
      var maps: seq[ORMap[string, int]]
      for i in 0 ..< ReplicaCount:
        maps.add newORMap[string, int](newNodeId("n" & $i))
      for cycle in 0 ..< 4:
        joinAll(maps, r)
        let
          idx = r.rand(0 .. maps.high)
          k = "k" & $r.rand(0 .. 3)
        discard maps[idx].put(k, cycle)
        # 발급 순번이 재사용되면 병합 뒤에 넣은 값이 조용히 사라진다.
        check maps[idx].lookup(k).len > 0
        if r.rand(0 .. 1) == 1:
          maps[idx].remove(k)
          check maps[idx].lookup(k).len == 0
      joinAll(maps, r)
      checkAllEqual(maps)

suite "Vector Clock 무작위 수렴":
  test "노드별 사건 수는 복제본 가운데 최댓값으로 모인다":
    var r = initRand(Seed + 4)
    let nodes = @[newNodeId("a"), newNodeId("b"), newNodeId("c")]
    for round in 0 ..< Rounds:
      var clocks = newSeqWith(ReplicaCount, newVectorClock())
      var counts: seq[Table[NodeId, uint64]]
      for i in 0 ..< ReplicaCount:
        counts.add initTable[NodeId, uint64]()
      for idx in 0 ..< ReplicaCount:
        for _ in 0 ..< r.rand(0 .. 4):
          let n = nodes[r.rand(0 .. nodes.high)]
          clocks[idx].tick(n)
          counts[idx][n] = counts[idx].getOrDefault(n) + 1
      joinAll(clocks, r)
      checkAllEqual(clocks)
      for n in nodes:
        var expected: uint64 = 0
        for idx in 0 ..< ReplicaCount:
          expected = max(expected, counts[idx].getOrDefault(n))
        check clocks[0].get(n) == expected

suite "반복 수렴":
  test "수렴한 상태에서 다시 연산해도 다시 수렴한다":
    var r = initRand(Seed + 5)
    var replicas = newSeqWith(ReplicaCount, newTwoPSet[int]())
    for cycle in 0 ..< Rounds:
      for rep in replicas.mitems:
        for _ in 0 ..< r.rand(0 .. 3):
          let v = r.rand(0 .. 8)
          if r.rand(0 .. 1) == 1:
            rep.add v
          else:
            discard rep.remove(v)
      joinAll(replicas, r)
      checkAllEqual(replicas)
