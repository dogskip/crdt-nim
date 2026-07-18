## GSet (Grow-Only Set) 테스트.
## 병합의 교환/결합/멱등 법칙을 검증한다.

import unittest
import ../src/gset

suite "GSet 기본 연산":
  test "빈 집합의 크기는 0":
    let s = newGSet[int]()
    check s.card == 0

  test "원소 추가 후 크기 증가":
    let s = newGSet[string]()
    s.add("apple")
    s.add("banana")
    check s.card == 2
    check "apple" in s
    check "banana" in s

  test "중복 추가는 멱등":
    let s = newGSet[int]()
    s.add(1)
    s.add(1)
    s.add(1)
    check s.card == 1

suite "GSet 병합 법칙":
  test "교환법칙: merge(A,B) == merge(B,A)":
    let a = newGSet[int]()
    let b = newGSet[int]()
    a.add(1); a.add(2)
    b.add(2); b.add(3)
    check merge(a, b) == merge(b, a)

  test "결합법칙: merge(merge(A,B),C) == merge(A,merge(B,C))":
    let a = newGSet[int](); a.add(1)
    let b = newGSet[int](); b.add(2)
    let c = newGSet[int](); c.add(3)
    let left = merge(merge(a, b), c)
    let right = merge(a, merge(b, c))
    check left == right

  test "멱등법칙: merge(A,A) == A":
    let a = newGSet[int](); a.add(1); a.add(2)
    check merge(a, a) == a

  test "mergeInto 도 동일한 결과":
    let a = newGSet[int](); a.add(1); a.add(2)
    let b = newGSet[int](); b.add(2); b.add(3)
    let expected = merge(a, b)
    a.mergeInto(b)
    check a == expected

suite "GSet 분산 시나리오":
  test "세 노드 병합 후 일관성":
    # 노드 A, B, C 가 각자 원소를 추가한 뒤 병합
    let nodeA = newGSet[string]()
    let nodeB = newGSet[string]()
    let nodeC = newGSet[string]()
    nodeA.add("x")
    nodeB.add("y")
    nodeC.add("z")
    # 각 노드가 다른 노드들의 상태를 모두 흡수
    nodeA.mergeInto(nodeB)
    nodeA.mergeInto(nodeC)
    nodeB.mergeInto(nodeA)
    nodeB.mergeInto(nodeC)
    nodeC.mergeInto(nodeA)
    nodeC.mergeInto(nodeB)
    # 모든 노드가 동일한 상태로 수렴해야 함
    check nodeA.card == 3
    check nodeB.card == 3
    check nodeC.card == 3
    check "x" in nodeA and "y" in nodeA and "z" in nodeA
    check "x" in nodeB and "y" in nodeB and "z" in nodeB
    check "x" in nodeC and "y" in nodeC and "z" in nodeC
