## Last-Write-Wins Set (LWW-Set)
##
## 각 원소마다 (값, 타임스탬프) 쌍을 유지하며, 병합 시 더 큰 타임스탬프가 이긴다.
## 2P-Set 과 달리 삭제 후 재추가가 가능하다. 삭제는 타임스탬프가 찍힌
## "tombstone" 으로 표현된다.
##
## 수학적 정의:
##   - 상태: M: T -> (Bool, Timestamp)
##     Bool 이 true 면 활성, false 면 삭제됨
##   - add(e, t):    M[e] = (true, t)   단, t > M[e].ts 인 경우만
##   - remove(e, t): M[e] = (false, t)  단, t > M[e].ts 인 경우만
##   - lookup(e): M[e].alive
##   - merge(A, B): 각 e 에 대해 ts 가 더 큰 쪽을 채택
##
## 동시성:
##   - 동일 타임스탬프의 충돌은 결정적 tie-break 가 필요하다.
##   - 여기서는 (alive=false 가 alive=true 보다 우선) 규칙을 사용해
##     삭제 우선 정책을 취한다. 이는 보수적 일관성을 제공한다.
##
## 보안 고려:
##   - 타임스탬프는 외부 노드가 임의로 조작할 수 없도록 신뢰된 출처에서 발급.
##   - 미래 타임스탬프 공격 방지를 위해 상한 검사를 호출자가 수행해야 한다.

import std/tables
import std/options
import ./crdt

type
  EntryState* = enum
    stAlive, stTombstone

  Entry* = object
    state*: EntryState
    ts*: Timestamp

  LWWSet*[T] = ref object
    ## 원소 타입 T 에 대한 LWW-Set.
    ## 내부적으로 Table[T, Entry] 를 사용한다.
    entries: Table[T, Entry]

proc newLWWSet*[T](): LWWSet[T] =
  ## 빈 LWW-Set 을 생성한다.
  result = LWWSet[T](entries: initTable[T, Entry]())

proc apply*[T](s: LWWSet[T], e: T, state: EntryState, ts: Timestamp) =
  ## 주어진 상태와 타임스탬프로 원소 e 를 갱신한다.
  ## 기존 타임스탬프보다 큰 경우에만 반영한다 (LWW 핵심 규칙).
  ## 동일 타임스탬프인 경우 삭제(tombstone)를 우선한다.
  let existing = s.entries.getOrDefault(e)
  if ts > existing.ts:
    s.entries[e] = Entry(state: state, ts: ts)
  elif ts == existing.ts:
    # 동시 갱신 충돌: 삭제 우선 정책으로 일관성을 보장한다.
    if state == stTombstone:
      s.entries[e] = Entry(state: stTombstone, ts: ts)

proc add*[T](s: LWWSet[T], e: T, ts: Timestamp) =
  ## 타임스탬프 ts 로 원소 e 를 활성 상태로 추가한다.
  s.apply(e, stAlive, ts)

proc remove*[T](s: LWWSet[T], e: T, ts: Timestamp) =
  ## 타임스탬프 ts 로 원소 e 를 삭제 상태로 표시한다.
  s.apply(e, stTombstone, ts)

proc contains*[T](s: LWWSet[T], e: T): bool =
  ## 원소 e 가 현재 활성 상태인지 확인한다.
  let entry = s.entries.getOrDefault(e)
  result = entry.state == stAlive

proc getEntry*[T](s: LWWSet[T], e: T): Option[Entry] =
  ## 원소 e 의 현재 Entry 를 반환한다. 없으면 None.
  if e in s.entries:
    result = some(s.entries[e])

proc merge*[T](a: LWWSet[T], b: LWWSet[T]): LWWSet[T] =
  ## 두 LWW-Set 을 병합한다. 각 원소마다 더 큰 타임스탬프를 가진 쪽을 채택한다.
  result = newLWWSet[T]()
  for e, entry in tables.pairs(a.entries):
    result.apply(e, entry.state, entry.ts)
  for e, entry in tables.pairs(b.entries):
    result.apply(e, entry.state, entry.ts)

proc mergeInto*[T](dst: LWWSet[T], src: LWWSet[T]) =
  ## src 를 dst 에 흡수한다. in-place 병합.
  for e, entry in tables.pairs(src.entries):
    dst.apply(e, entry.state, entry.ts)

proc card*[T](s: LWWSet[T]): int =
  ## 현재 활성 원소 수를 반환한다.
  result = 0
  for _, entry in tables.pairs(s.entries):
    if entry.state == stAlive:
      inc result

proc `==`*[T](a, b: LWWSet[T]): bool =
  ## 두 LWW-Set 이 동일한 상태인지 비교한다.
  ## Table 의 == 가 내부적으로 pairs 를 사용해 충돌하므로 직접 비교한다.
  if a.entries.len != b.entries.len: return false
  for k, v in tables.pairs(a.entries):
    if k notin b.entries: return false
    if b.entries[k] != v: return false
  result = true
