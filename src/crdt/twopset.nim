## 추가 집합과 제거 집합을 함께 두는 집합. 한 번 제거한 원소는 되돌아오지 않는다.

import ./gset

type
  TwoPSet*[T] = ref object
    adds: GSet[T]
    tombstones: GSet[T]

proc newTwoPSet*[T](): TwoPSet[T] =
  result = TwoPSet[T](adds: newGSet[T](), tombstones: newGSet[T]())

proc add*[T](s: TwoPSet[T], e: T) =
  s.adds.add(e)

proc remove*[T](s: TwoPSet[T], e: T): bool =
  ## 아직 추가되지 않은 원소라도 제거 집합에 넣는다. 새로 넣었으면 true.
  if s.tombstones.contains(e):
    return false
  s.tombstones.add(e)
  result = true

proc contains*[T](s: TwoPSet[T], e: T): bool =
  result = s.adds.contains(e) and not s.tombstones.contains(e)

proc merge*[T](a, b: TwoPSet[T]): TwoPSet[T] =
  result = TwoPSet[T](
    adds: merge(a.adds, b.adds),
    tombstones: merge(a.tombstones, b.tombstones)
  )

proc mergeInto*[T](dst: TwoPSet[T], src: TwoPSet[T]) =
  dst.adds.mergeInto(src.adds)
  dst.tombstones.mergeInto(src.tombstones)

proc card*[T](s: TwoPSet[T]): int =
  result = 0
  for e in s.adds.eachItem():
    if not s.tombstones.contains(e):
      inc result

proc `==`*[T](a, b: TwoPSet[T]): bool =
  result = a.adds == b.adds and a.tombstones == b.tombstones
