## 모든 CRDT 모듈이 공유하는 타입과 공통 인터페이스.

import std/hashes

type
  NodeId* = distinct string
    ## 복제본 하나를 가리키는 이름.
  Timestamp* = uint64
    ## 값의 최신성을 견주는 논리 시각. 실제 시각일 필요는 없다.
  CrdtError* = object of CatchableError
    ## CRDT 연산이 실패했을 때 발생하는 오류.

  Crdt* = concept a, b, type T
    ## 다른 복제본과 병합할 수 있는 자료구조.
    merge(a, b) is T
    mergeInto(a, b)
    a == b is bool

proc `$`*(id: NodeId): string {.borrow.}
proc `==`*(a, b: NodeId): bool {.borrow.}
proc hash*(id: NodeId): Hash {.borrow.}

proc newNodeId*(raw: string): NodeId =
  ## 빈 문자열은 노드 이름이 될 수 없으므로 거부한다.
  if raw.len == 0:
    raise newException(CrdtError, "NodeId 는 빈 문자열일 수 없다")
  result = NodeId(raw)
