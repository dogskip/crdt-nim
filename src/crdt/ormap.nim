## 키마다 고유 ID 를 가진 항목을 두는 맵. 제거는 관찰한 ID 에만 적용된다.

import std/hashes
import std/options
import std/sets
import std/tables
import ./common

type
  EntryId* = object
    ## 항목 하나를 가리키는 이름. 발급한 노드와 그 노드의 발급 순번으로 이루어진다.
    node*: NodeId
    counter*: uint64

  ORMap*[K, V] = ref object
    entries: Table[K, Table[EntryId, V]]
    tombstones: HashSet[EntryId]
    counter: uint64
    owner: NodeId

proc newORMap*[K, V](owner: NodeId): ORMap[K, V] =
  result = ORMap[K, V](
    entries: initTable[K, Table[EntryId, V]](),
    tombstones: initHashSet[EntryId](),
    owner: owner
  )

proc `==`*(a, b: EntryId): bool =
  result = a.node == b.node and a.counter == b.counter

proc hash*(id: EntryId): Hash =
  var h: Hash = 0
  h = h !& hash(id.node)
  h = h !& hash(id.counter)
  result = !$h

proc nextId*[K, V](m: ORMap[K, V]): EntryId =
  inc m.counter
  result = EntryId(node: m.owner, counter: m.counter)

proc put*[K, V](m: ORMap[K, V], k: K, v: V): EntryId =
  let id = m.nextId()
  if k notin m.entries:
    m.entries[k] = initTable[EntryId, V]()
  m.entries[k][id] = v
  result = id

proc remove*[K, V](m: ORMap[K, V], k: K) =
  if k in m.entries:
    for id in tables.keys(m.entries[k]):
      m.tombstones.incl(id)
    m.entries[k].clear()

proc removeEntry*[K, V](m: ORMap[K, V], k: K, id: EntryId) =
  if k in m.entries and id in m.entries[k]:
    m.tombstones.incl(id)
    m.entries[k].del(id)

proc lookup*[K, V](m: ORMap[K, V], k: K): seq[V] =
  result = @[]
  if k in m.entries:
    for id, v in tables.pairs(m.entries[k]):
      if id notin m.tombstones:
        result.add(v)

proc lookupOne*[K, V](m: ORMap[K, V], k: K): Option[V] =
  let vals = m.lookup(k)
  if vals.len > 0:
    result = some(vals[0])

proc contains*[K, V](m: ORMap[K, V], k: K): bool =
  result = m.lookup(k).len > 0

proc merge*[K, V](a, b: ORMap[K, V]): ORMap[K, V] =
  ## 발급 순번을 이어받아야 병합 뒤에 발급하는 ID 가 이미 버려진 ID 와 겹치지 않는다.
  result = newORMap[K, V](a.owner)
  result.counter = max(a.counter, b.counter)
  for id in sets.items(a.tombstones): result.tombstones.incl(id)
  for id in sets.items(b.tombstones): result.tombstones.incl(id)
  for k, tbl in tables.pairs(a.entries):
    result.entries[k] = tbl
  for k, tbl in tables.pairs(b.entries):
    if k notin result.entries:
      result.entries[k] = initTable[EntryId, V]()
    for id, v in tables.pairs(tbl):
      if id notin result.entries[k]:
        result.entries[k][id] = v

proc mergeInto*[K, V](dst, src: ORMap[K, V]) =
  dst.counter = max(dst.counter, src.counter)
  for id in sets.items(src.tombstones):
    dst.tombstones.incl(id)
  for k, tbl in tables.pairs(src.entries):
    if k notin dst.entries:
      dst.entries[k] = initTable[EntryId, V]()
    for id, v in tables.pairs(tbl):
      if id notin dst.entries[k]:
        dst.entries[k][id] = v

proc keys*[K, V](m: ORMap[K, V]): seq[K] =
  result = @[]
  for k in tables.keys(m.entries):
    if m.lookup(k).len > 0:
      result.add(k)

proc `==`*[K, V](a, b: ORMap[K, V]): bool =
  ## Table 의 == 는 소비 모듈에서 인스턴스화되지 않으므로 직접 견준다.
  ## owner 와 counter 는 복제본마다 다른 값이므로 견주지 않는다.
  if a.tombstones.len != b.tombstones.len: return false
  for id in sets.items(a.tombstones):
    if id notin b.tombstones: return false
  if a.entries.len != b.entries.len: return false
  for k, tbl in tables.pairs(a.entries):
    if k notin b.entries: return false
    if tbl.len != b.entries[k].len: return false
    for id, v in tables.pairs(tbl):
      if id notin b.entries[k]: return false
      if b.entries[k][id] != v: return false
  result = true
