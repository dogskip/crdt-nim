## 원소마다 마지막 갱신 시각을 함께 두고, 병합할 때 더 나중 것을 채택하는 집합.

import std/options
import std/tables
import ./common

type
  EntryState* = enum
    stAlive, stTombstone
  Entry* = object
    state*: EntryState
    ts*: Timestamp
  LWWSet*[T] = ref object
    entries: Table[T, Entry]

proc newLWWSet*[T](): LWWSet[T] =
  result = LWWSet[T](entries: initTable[T, Entry]())

proc apply*[T](s: LWWSet[T], e: T, state: EntryState, ts: Timestamp) =
  ## 기존 시각보다 나중일 때만 반영한다. 같은 시각이면 제거가 이긴다.
  let existing = s.entries.getOrDefault(e)
  if ts > existing.ts:
    s.entries[e] = Entry(state: state, ts: ts)
  elif ts == existing.ts and state == stTombstone:
    s.entries[e] = Entry(state: state, ts: ts)

proc add*[T](s: LWWSet[T], e: T, ts: Timestamp) =
  s.apply(e, stAlive, ts)

proc remove*[T](s: LWWSet[T], e: T, ts: Timestamp) =
  s.apply(e, stTombstone, ts)

proc contains*[T](s: LWWSet[T], e: T): bool =
  result = e in s.entries and s.entries[e].state == stAlive

proc getEntry*[T](s: LWWSet[T], e: T): Option[Entry] =
  if e in s.entries:
    result = some(s.entries[e])

proc merge*[T](a, b: LWWSet[T]): LWWSet[T] =
  result = newLWWSet[T]()
  result.mergeInto(a)
  result.mergeInto(b)

proc mergeInto*[T](dst, src: LWWSet[T]) =
  for e, entry in tables.pairs(src.entries):
    dst.apply(e, entry.state, entry.ts)

proc card*[T](s: LWWSet[T]): int =
  result = 0
  for _, entry in tables.pairs(s.entries):
    if entry.state == stAlive:
      inc result

proc `==`*[T](a, b: LWWSet[T]): bool =
  ## Table 의 == 는 소비 모듈에서 인스턴스화되지 않으므로 직접 견준다.
  if a.entries.len != b.entries.len: return false
  for k, v in tables.pairs(a.entries):
    if k notin b.entries: return false
    if b.entries[k] != v: return false
  result = true
