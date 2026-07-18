## LWW-Set (Last-Write-Wins Set) 테스트.
## 타임스탬프 기반 병합과 삭제 후 재추가를 검증한다.

import unittest
import std/options
import ../src/lwwset

suite "LWW-Set 기본 연산":
  test "추가 후 조회":
    let s = newLWWSet[string]()
    s.add("a", 10)
    check "a" in s

  test "오래된 타임스탬프로 갱신 무시":
    let s = newLWWSet[string]()
    s.add("a", 10)
    s.add("a", 5)  # 더 오래된 타임스탬프
    check "a" in s
    let entry = s.getEntry("a")
    check entry.isSome
    check entry.get().ts == 10

  test "최신 타임스탬프로 갱신":
    let s = newLWWSet[string]()
    s.add("a", 5)
    s.add("a", 20)
    let entry = s.getEntry("a")
    check entry.get().ts == 20

suite "LWW-Set 삭제/재추가":
  test "삭제 후 재추가 가능":
    let s = newLWWSet[string]()
    s.add("a", 10)
    s.remove("a", 15)
    check "a" notin s
    s.add("a", 20)
    check "a" in s

  test "오래된 삭제는 무시":
    let s = newLWWSet[string]()
    s.add("a", 20)
    s.remove("a", 10)  # 더 오래된 삭제
    check "a" in s

  test "동일 타임스탬프 충돌 시 삭제 우선":
    let s = newLWWSet[string]()
    s.add("a", 10)
    s.remove("a", 10)  # 동일 ts, 삭제 우선 정책
    check "a" notin s

suite "LWW-Set 병합":
  test "교환법칙":
    let a = newLWWSet[string]()
    let b = newLWWSet[string]()
    a.add("x", 10)
    b.add("x", 20)
    check merge(a, b) == merge(b, a)

  test "결합법칙":
    let a = newLWWSet[string](); a.add("k", 5)
    let b = newLWWSet[string](); b.add("k", 10)
    let c = newLWWSet[string](); c.add("k", 7)
    let left = merge(merge(a, b), c)
    let right = merge(a, merge(b, c))
    check left == right

  test "멱등법칙":
    let a = newLWWSet[string](); a.add("k", 5)
    check merge(a, a) == a

  test "병합 시 더 큰 타임스탬프가 승리":
    let a = newLWWSet[string](); a.add("k", 100)
    let b = newLWWSet[string](); b.remove("k", 50)
    let merged = merge(a, b)
    check "k" in merged  # a 의 ts 100 이 b 의 ts 50 보다 큼

  test "분산 삭제 시나리오":
    # 노드 A 가 ts=10 에 추가, 노드 B 가 ts=20 에 삭제
    let a = newLWWSet[string](); a.add("k", 10)
    let b = newLWWSet[string](); b.remove("k", 20)
    let merged = merge(a, b)
    check "k" notin merged
