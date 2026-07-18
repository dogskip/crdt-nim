## Observed-Remove Map (OR-Map)
##
## 키마다 고유 ID 를 가진 항목들을 유지하는 CRDT Map.
## 삭제 시 관찰된 항목 ID 만 tombstone 으로 marking 하므로, 삭제 후 재추가가 가능하다.
## 2P-Set 기반 Map 과 달리 동시 추가/삭제 충돌이 안전하게 해결된다.
##
## 수학적 정의:
##   - 상태: (entries: K -> {ID -> V}, tombstones: {ID})
##   - put(k, v): 새 ID 를 발급해 entries[k][ID] = v
##   - remove(k): 현재 entries[k] 의 모든 ID 를 tombstones 에 추가
##   - lookup(k): entries[k] 에서 tombstone 이 아닌 값들
##   - merge: entries 와 tombstones 각각을 합집합
##
## 동시성:
##   - 노드 A 가 k=v1 을 put 하고 노드 B 가 k 를 remove 할 때,
##     B 의 remove 는 B 가 관찰한 ID 만 지우므로 v1 은 살아남는다.
##   - 이것이 "Observed-Remove" 의 핵심이다.
##
## 보안 고려:
##   - ID 발급은 단조 증가해야 하며, 충돌을 피하기 위해 NodeId 와 카운터를
##     조합한 형태를 사용한다.
##   - 외부에서 들어온 값은 put 전 검증이 필요하다.

import std/tables
import std/sets
import std/options
import std/hashes
import ./crdt

type
  EntryId* = object
    ## 항목을 고유하게 식별하기 위한 ID. NodeId 와 로컬 카운터로 구성된다.
    node*: NodeId
    counter*: uint64

  ORMap*[K, V] = ref object
    ## 키 K, 값 V 에 대한 OR-Map.
    ## 각 키마다 (EntryId -> V) 테이블을 가진다.
    entries: Table[K, Table[EntryId, V]]
    tombstones: HashSet[EntryId]
    counter: uint64
    owner: NodeId

proc newORMap*[K, V](owner: NodeId): ORMap[K, V] =
  ## owner 노드용 OR-Map 을 생성한다. ID 발급에 owner 식별자가 사용된다.
  result = ORMap[K, V](
    entries: initTable[K, Table[EntryId, V]](),
    tombstones: initHashSet[EntryId](),
    counter: 0,
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
  ## 로컬 카운터를 증가시켜 새 EntryId 를 발급한다.
  ## 단조 증가하므로 동일 노드 내에서는 충돌이 없다.
  inc m.counter
  result = EntryId(node: m.owner, counter: m.counter)

proc put*[K, V](m: ORMap[K, V], k: K, v: V): EntryId =
  ## 키 k 에 값 v 를 추가한다. 새 EntryId 를 발급해 반환한다.
  ## 기존 항목은 자동으로 삭제되지 않는다 (멀티 값 허용).
  let id = m.nextId()
  if k notin m.entries:
    m.entries[k] = initTable[EntryId, V]()
  m.entries[k][id] = v
  result = id

proc remove*[K, V](m: ORMap[K, V], k: K) =
  ## 키 k 의 모든 관찰된 항목을 tombstone 으로 marking 한다.
  ## 관찰되지 않은 동시 추가는 살아남는다 (OR-Set 의 핵심).
  if k in m.entries:
    for id in tables.keys(m.entries[k]):
      m.tombstones.incl(id)
    m.entries[k].clear()

proc removeEntry*[K, V](m: ORMap[K, V], k: K, id: EntryId) =
  ## 특정 EntryId 만 tombstone 으로 marking 한다.
  ## 세밀한 삭제가 필요한 경우 사용한다.
  if k in m.entries and id in m.entries[k]:
    m.tombstones.incl(id)
    m.entries[k].del(id)

proc lookup*[K, V](m: ORMap[K, V], k: K): seq[V] =
  ## 키 k 의 모든 활성 값을 반환한다. tombstone 은 제외된다.
  result = @[]
  if k in m.entries:
    for id, v in tables.pairs(m.entries[k]):
      if id notin m.tombstones:
        result.add(v)

proc lookupOne*[K, V](m: ORMap[K, V], k: K): Option[V] =
  ## 키 k 의 활성 값 중 하나를 반환한다. 없으면 None.
  let vals = m.lookup(k)
  if vals.len > 0:
    result = some(vals[0])

proc contains*[K, V](m: ORMap[K, V], k: K): bool =
  ## 키 k 에 활성 값이 하나라도 있는지 확인한다.
  result = m.lookup(k).len > 0

proc merge*[K, V](a: ORMap[K, V], b: ORMap[K, V]): ORMap[K, V] =
  ## 두 OR-Map 을 병합한다. entries 와 tombstones 각각을 합집합한다.
  ## owner 는 a 의 owner 를 계승한다 (호출자가 새 OR-Map 을 만들어도 무방).
  result = newORMap[K, V](a.owner)
  # tombstone 합집합
  for id in sets.items(a.tombstones): result.tombstones.incl(id)
  for id in sets.items(b.tombstones): result.tombstones.incl(id)
  # entries 합집합
  for k, tbl in tables.pairs(a.entries):
    result.entries[k] = initTable[EntryId, V]()
    for id, v in tables.pairs(tbl): result.entries[k][id] = v
  for k, tbl in tables.pairs(b.entries):
    if k notin result.entries:
      result.entries[k] = initTable[EntryId, V]()
    for id, v in tables.pairs(tbl):
      if id notin result.entries[k]:
        result.entries[k][id] = v

proc mergeInto*[K, V](dst: ORMap[K, V], src: ORMap[K, V]) =
  ## src 를 dst 에 흡수한다. in-place 병합.
  for id in sets.items(src.tombstones):
    dst.tombstones.incl(id)
  for k, tbl in tables.pairs(src.entries):
    if k notin dst.entries:
      dst.entries[k] = initTable[EntryId, V]()
    for id, v in tables.pairs(tbl):
      if id notin dst.entries[k]:
        dst.entries[k][id] = v

proc keys*[K, V](m: ORMap[K, V]): seq[K] =
  ## 활성 값을 가진 모든 키를 반환한다.
  result = @[]
  for k in tables.keys(m.entries):
    if m.lookup(k).len > 0:
      result.add(k)
