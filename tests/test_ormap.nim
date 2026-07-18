## OR-Map (Observed-Remove Map) 테스트.
## 삭제 후 재추가와 동시 갱신 안전성을 검증한다.

import unittest
import ../src/crdt
import ../src/ormap

suite "OR-Map 기본 연산":
  test "put 후 lookup":
    let m = newORMap[string, int](newNodeId("A"))
    discard m.put("k", 1)
    check m.lookup("k") == @[1]

  test "동일 키 여러 값 병존":
    let m = newORMap[string, int](newNodeId("A"))
    discard m.put("k", 1)
    discard m.put("k", 2)
    let vals = m.lookup("k")
    check vals.len == 2
    check 1 in vals
    check 2 in vals

  test "remove 후 키 비활성":
    let m = newORMap[string, int](newNodeId("A"))
    discard m.put("k", 1)
    m.remove("k")
    check m.lookup("k").len == 0
    check "k" notin m

  test "remove 후 재추가 가능":
    let m = newORMap[string, int](newNodeId("A"))
    discard m.put("k", 1)
    m.remove("k")
    discard m.put("k", 2)
    check m.lookup("k") == @[2]

suite "OR-Map 동시성":
  test "관찰된 항목만 삭제 (OR 핵심 속성)":
    # 노드 A 가 k=v1 추가. 노드 B 는 k=v1 을 관찰하지 못한 채 remove.
    # 이후 A 의 v1 이 병합되면 살아남아야 한다.
    let a = newORMap[string, string](newNodeId("A"))
    let b = newORMap[string, string](newNodeId("B"))
    # A 가 k=v1 추가
    discard a.put("k", "v1")
    # B 는 k 를 remove 하지만 B 는 v1 을 본 적이 없다
    b.remove("k")
    # 병합
    let merged = merge(a, b)
    # B 의 remove 는 B 가 관찰한 ID 만 tombstone 으로 marking.
    # A 의 v1 은 B 가 관찰하지 못했으므로 살아남는다.
    check "v1" in merged.lookup("k")

  test "관찰 후 삭제는 항목 제거":
    # 단일 노드에서 put 후 remove 하면 항목이 사라진다.
    let m = newORMap[string, int](newNodeId("A"))
    discard m.put("k", 1)
    m.remove("k")
    check m.lookup("k").len == 0

suite "OR-Map 병합":
  test "교환법칙":
    let a = newORMap[string, int](newNodeId("A"))
    let b = newORMap[string, int](newNodeId("B"))
    discard a.put("k", 1)
    discard b.put("k", 2)
    let left = merge(a, b)
    let right = merge(b, a)
    check left.lookup("k").len == right.lookup("k").len

  test "결합법칙":
    let a = newORMap[string, int](newNodeId("A")); discard a.put("k", 1)
    let b = newORMap[string, int](newNodeId("B")); discard b.put("k", 2)
    let c = newORMap[string, int](newNodeId("C")); discard c.put("k", 3)
    let left = merge(merge(a, b), c)
    let right = merge(a, merge(b, c))
    check left.lookup("k").len == 3
    check right.lookup("k").len == 3

  test "멱등법칙":
    let a = newORMap[string, int](newNodeId("A")); discard a.put("k", 1)
    let merged = merge(a, a)
    check merged.lookup("k").len == 1

  test "mergeInto 동작":
    let a = newORMap[string, int](newNodeId("A")); discard a.put("k", 1)
    let b = newORMap[string, int](newNodeId("B")); discard b.put("k", 2)
    a.mergeInto(b)
    check a.lookup("k").len == 2
