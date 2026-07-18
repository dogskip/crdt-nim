## 2P-Set (Two-Phase Set) 테스트.
## 삭제 후 복구 불가 속성과 병합 멱등성을 검증한다.

import unittest
import ../src/twopset

suite "2P-Set 기본 연산":
  test "추가 후 조회":
    let s = newTwoPSet[string]()
    s.add("a")
    check "a" in s
    check s.card == 1

  test "삭제 후 미조회":
    let s = newTwoPSet[string]()
    s.add("a")
    discard s.remove("a")
    check "a" notin s
    check s.card == 0

  test "삭제 후 재추가 불가":
    let s = newTwoPSet[string]()
    s.add("a")
    discard s.remove("a")
    s.add("a")  # tombstone 때문에 여전히 조회 안 됨
    check "a" notin s

  test "존재하지 않는 원소 삭제 시 false":
    let s = newTwoPSet[int]()
    check s.remove(42) == false

suite "2P-Set 병합":
  test "교환법칙":
    let a = newTwoPSet[int]()
    let b = newTwoPSet[int]()
    a.add(1); a.add(2)
    b.add(2); b.add(3)
    check merge(a, b) == merge(b, a)

  test "결합법칙":
    let a = newTwoPSet[int](); a.add(1)
    let b = newTwoPSet[int](); b.add(2)
    let c = newTwoPSet[int](); c.add(3)
    let left = merge(merge(a, b), c)
    let right = merge(a, merge(b, c))
    check left == right

  test "멱등법칙":
    let a = newTwoPSet[int](); a.add(1); a.add(2)
    check merge(a, a) == a

  test "한 노드의 삭제가 병합 후에도 유지":
    let a = newTwoPSet[string]()
    let b = newTwoPSet[string]()
    a.add("x")
    b.add("x")
    discard a.remove("x")
    let merged = merge(a, b)
    # b 가 x 를 추가했지만 a 가 삭제했으므로 병합 후엔 x 가 없어야 함
    check "x" notin merged

  test "동시 삭제는 안전":
    let a = newTwoPSet[string](); a.add("k")
    let b = newTwoPSet[string](); b.add("k")
    discard a.remove("k")
    discard b.remove("k")
    let merged = merge(a, b)
    check "k" notin merged
