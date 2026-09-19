## 추가만 가능한 집합. 병합은 합집합이다.

import std/sets

type
  GSet*[T] = ref object
    data: HashSet[T]

proc newGSet*[T](): GSet[T] =
  result = GSet[T](data: initHashSet[T]())

proc contains*[T](s: GSet[T], e: T): bool =
  result = s.data.contains(e)

proc add*[T](s: GSet[T], e: T) =
  s.data.incl(e)

proc card*[T](s: GSet[T]): int =
  result = s.data.len

iterator eachItem*[T](s: GSet[T]): T =
  for e in items(s.data):
    yield e

proc mergeInto*[T](dst: GSet[T], src: GSet[T]) =
  for e in items(src.data):
    dst.data.incl(e)

proc merge*[T](a, b: GSet[T]): GSet[T] =
  result = newGSet[T]()
  result.mergeInto(a)
  result.mergeInto(b)

proc `==`*[T](a, b: GSet[T]): bool =
  result = a.data == b.data
