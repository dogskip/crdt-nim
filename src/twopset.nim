## Two-Phase Set (2P-Set)
##
## 추가 집합(adds)과 제거 집합(tombstones) 두 개의 GSet 으로 구성된다.
## 한 번 tombstone 에 들어간 원소는 다시 추가해도 복구되지 않는다.
##
## 수학적 정의:
##   - 상태: (A, R)  둘 다 GSet
##   - add(e):    A' = A ∪ {e}
##   - remove(e): R' = R ∪ {e}   (단, e ∈ A 여야 함)
##   - lookup(e): e ∈ A ∧ e ∉ R
##   - merge((A1,R1), (A2,R2)): (A1 ∪ A2, R1 ∪ R2)
##
## 한계:
##   - 삭제 후 재추가 불가 (tombstone 이 영구적)
##   - tombstone 이 계속 쌓여 메모리가 단조 증가
##
## 보안 고려:
##   - remove 는 사전에 lookup 으로 존재 확인을 강제해 무효 연산을 차단한다.
##   - 외부 입력 원소는 add 전 크기/타입 검증이 필요하다.

import std/sets
import ./crdt
import ./gset

type
  TwoPSet*[T] = ref object
    ## 추가 집합과 제거 집합을 함께 관리하는 2P-Set.
    adds: GSet[T]
    tombstones: GSet[T]

proc newTwoPSet*[T](): TwoPSet[T] =
  ## 빈 2P-Set 을 생성한다.
  result = TwoPSet[T](
    adds: newGSet[T](),
    tombstones: newGSet[T]()
  )

proc add*[T](s: TwoPSet[T], e: T) =
  ## 원소 e 를 추가 집합에 넣는다.
  ## tombstone 에 있더라도 add 자체는 성공하지만, lookup 은 여전히 false 다.
  s.adds.add(e)

proc remove*[T](s: TwoPSet[T], e: T): bool =
  ## 원소 e 를 제거한다. e 가 현재 집합에 속해 있어야만 성공한다.
  ## 반환값: 실제로 제거가 수행되었으면 true, 아니면 false.
  ## 이 검사는 잘못된 순서의 동시 삭제로 인한 의도치 않은 tombstone
  ## 확장을 방지한다.
  if not s.adds.contains(e):
    return false
  if s.tombstones.contains(e):
    return false
  s.tombstones.add(e)
  result = true

proc contains*[T](s: TwoPSet[T], e: T): bool =
  ## 원소 e 가 현재 집합에 속해 있는지 확인한다.
  ## 추가되었고, tombstone 에 없어야 한다.
  result = s.adds.contains(e) and not s.tombstones.contains(e)

proc merge*[T](a: TwoPSet[T], b: TwoPSet[T]): TwoPSet[T] =
  ## 두 2P-Set 을 병합한다. adds 와 tombstones 각각을 합집합한다.
  result = newTwoPSet[T]()
  result.adds = merge(a.adds, b.adds)
  result.tombstones = merge(a.tombstones, b.tombstones)

proc mergeInto*[T](dst: TwoPSet[T], src: TwoPSet[T]) =
  ## src 를 dst 에 흡수한다. in-place 병합.
  dst.adds.mergeInto(src.adds)
  dst.tombstones.mergeInto(src.tombstones)

proc card*[T](s: TwoPSet[T]): int =
  ## 현재 활성 원소 수를 반환한다.
  var n = 0
  for e in s.adds.eachItem():
    if not s.tombstones.contains(e):
      inc n
  result = n

proc `==`*[T](a, b: TwoPSet[T]): bool =
  result = a.adds == b.adds and a.tombstones == b.tombstones
