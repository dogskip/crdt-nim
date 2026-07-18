## Grow-Only Set (GSet)
##
## 가장 단순한 형태의 CRDT. 한 번 추가한 원소는 제거할 수 없으며,
## 병합은 두 집합의 합집합으로 정의된다.
##
## 수학적 정의:
##   - 상태: S ⊆ T (원소 전체 집합 T 의 부분집합)
##   - add(e): S' = S ∪ {e}
##   - merge(A, B): A ∪ B
##
## 성질 검증:
##   - 교환법칙: A ∪ B = B ∪ A                  ✓
##   - 결합법칙: (A ∪ B) ∪ C = A ∪ (B ∪ C)      ✓
##   - 멱등법칙: A ∪ A = A                        ✓
##
## 보안 고려:
##   - 원소 타입 T 는 해시 가능해야 하며, 신뢰할 수 없는 입력은
##     add 전에 검증해야 한다 (예: 크기 제한, 인코딩 검사).

import std/sets
export sets

type
  GSet*[T] = ref object
    ## 원소 타입 T 에 대한 Grow-Only Set.
    ## 내부적으로 HashSet 을 사용해 평균 O(1) 조회/삽입을 제공한다.
    data: HashSet[T]

proc newGSet*[T](): GSet[T] =
  ## 빈 GSet 을 생성한다.
  result = GSet[T](data: initHashSet[T]())

proc contains*[T](s: GSet[T], e: T): bool =
  ## 원소 e 가 집합에 존재하는지 확인한다.
  result = s.data.contains(e)

proc add*[T](s: GSet[T], e: T) =
  ## 원소 e 를 집합에 추가한다. 이미 존재하면 아무 일도 일어나지 않는다 (멱등).
  s.data.incl(e)

proc card*[T](s: GSet[T]): int =
  ## 집합의 크기(원소 수)를 반환한다.
  result = s.data.len

iterator eachItem*[T](s: GSet[T]): T =
  ## 집합의 원소를 순회한다.
  for e in items(s.data):
    yield e

proc merge*[T](a: GSet[T], b: GSet[T]): GSet[T] =
  ## 두 GSet 을 병합해 새로운 GSet 을 반환한다.
  ## 원본 a, b 는 변경되지 않는다 (순수 함수).
  result = newGSet[T]()
  for e in items(a.data): result.data.incl(e)
  for e in items(b.data): result.data.incl(e)

proc mergeInto*[T](dst: GSet[T], src: GSet[T]) =
  ## src 의 원소를 dst 에 흡수한다. in-place 병합으로, 새 객체를 만들지 않는다.
  ## 멱등성: 동일 src 를 여러 번 흡수해도 결과는 동일하다.
  for e in items(src.data):
    dst.data.incl(e)

proc `==`*[T](a, b: GSet[T]): bool =
  ## 두 GSet 이 동일한 원소를 가지는지 비교한다.
  ## HashSet 의 == 가 내부적으로 items 를 사용해 충돌하므로 직접 비교한다.
  if a.data.len != b.data.len: return false
  for e in sets.items(a.data):
    if e notin b.data: return false
  result = true

proc toSeq*[T](s: GSet[T]): seq[T] =
  ## 집합의 원소를 시퀀스로 반환한다. 순서는 보장되지 않는다.
  result = toSeq(s.data)
