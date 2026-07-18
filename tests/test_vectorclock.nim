## Vector Clock 테스트.
## 인과 관계 추적과 동시성 감지를 검증한다.

import unittest
import ../src/crdt
import ../src/vectorclock

suite "Vector Clock 기본 연산":
  test "tick 으로 카운터 증가":
    let vc = newVectorClock()
    let n = newNodeId("A")
    vc.tick(n)
    vc.tick(n)
    check vc.get(n) == 2

  test "등록 안 된 노드는 0":
    let vc = newVectorClock()
    check vc.get(newNodeId("unknown")) == 0

suite "Vector Clock 인과 관계":
  test "선행 관계 감지":
    let a = newVectorClock()
    let b = newVectorClock()
    let nodeA = newNodeId("A")
    a.tick(nodeA)
    # b 는 a 를 흡수 후 추가 tick
    b.mergeInto(a)
    b.tick(nodeA)
    check a.happensBefore(b)
    check compare(a, b) == coBefore

  test "동시 관계 감지":
    let a = newVectorClock()
    let b = newVectorClock()
    let nodeA = newNodeId("A")
    let nodeB = newNodeId("B")
    a.tick(nodeA)
    b.tick(nodeB)
    # a 와 b 는 서로 다른 노드에서 독립 발생
    check a.isConcurrentWith(b)
    check compare(a, b) == coConcurrent

  test "동일 벡터는 equal":
    let a = newVectorClock()
    let b = newVectorClock()
    let n = newNodeId("A")
    a.tick(n)
    b.tick(n)
    check compare(a, b) == coEqual

suite "Vector Clock 병합":
  test "교환법칙":
    let a = newVectorClock()
    let b = newVectorClock()
    let nA = newNodeId("A")
    let nB = newNodeId("B")
    a.tick(nA)
    b.tick(nB)
    check merge(a, b) == merge(b, a)

  test "결합법칙":
    let a = newVectorClock(); a.tick(newNodeId("A"))
    let b = newVectorClock(); b.tick(newNodeId("B"))
    let c = newVectorClock(); c.tick(newNodeId("C"))
    let left = merge(merge(a, b), c)
    let right = merge(a, merge(b, c))
    check left == right

  test "멱등법칙":
    let a = newVectorClock(); a.tick(newNodeId("A"))
    check merge(a, a) == a

suite "Vector Clock 분산 시나리오":
  test "메시지 송수신 인과 추적":
    # A 가 이벤트 발생 후 B 에게 전파
    let a = newVectorClock()
    let b = newVectorClock()
    let nA = newNodeId("A")
    let nB = newNodeId("B")
    a.tick(nA)              # A 에서 이벤트 1
    b.mergeInto(a)          # B 가 A 의 상태 수신
    b.tick(nB)              # B 에서 이벤트 2
    # A 의 원래 상태는 B 의 현재 상태보다 선행해야 함
    let aOriginal = newVectorClock()
    aOriginal.tick(nA)
    check aOriginal.happensBefore(b)
    check not b.happensBefore(aOriginal)
