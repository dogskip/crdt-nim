## 공통 병합 인터페이스(Crdt)를 일반 절차에서 사용할 수 있는지 검증한다.

import unittest
import ../src/crdt

proc sync[T: Crdt](a, b: T): T =
  ## 두 복제본을 병합해 하나로 모은다.
  result = merge(a, b)

suite "Crdt 개념":
  test "GSet 이 개념을 만족":
    let a = newGSet[int]()
    let b = newGSet[int]()
    a.add(1)
    b.add(2)
    check sync(a, b) == merge(a, b)
    check sync(a, b).card == 2

  test "2P-Set 이 개념을 만족":
    let a = newTwoPSet[int]()
    let b = newTwoPSet[int]()
    a.add(1)
    b.add(2)
    check sync(a, b) == merge(a, b)
    check sync(a, b).card == 2

  test "LWW-Set 이 개념을 만족":
    let a = newLWWSet[string]()
    let b = newLWWSet[string]()
    a.add("x", 10)
    b.add("y", 10)
    check sync(a, b) == merge(a, b)
    check sync(a, b).card == 2

  test "OR-Map 이 개념을 만족":
    let a = newORMap[string, int](newNodeId("A"))
    let b = newORMap[string, int](newNodeId("B"))
    discard a.put("k", 1)
    discard b.put("k", 2)
    check sync(a, b) == merge(a, b)
    check sync(a, b).lookup("k").len == 2

  test "Vector Clock 이 개념을 만족":
    let a = newVectorClock()
    let b = newVectorClock()
    a.tick(newNodeId("A"))
    b.tick(newNodeId("B"))
    check sync(a, b) == merge(a, b)
    check sync(a, b).nodes.len == 2
