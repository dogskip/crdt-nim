## CRDT (Conflict-free Replicated Data Type) 공통 타입 정의
##
## 이 모듈은 모든 CRDT 구현체가 공유하는 기본 타입과 인터페이스를 정의한다.
## CRDT 는 분산 환경에서 최종적 일관성(eventual consistency)을 보장하면서도
## 충돌 해결을 자동으로 수행하는 자료구조이다.
##
## 수학적 기반:
##   - 결합법칙: (a ⊕ b) ⊕ c = a ⊕ (b ⊕ c)
##   - 교환법칙: a ⊕ b = b ⊕ a
##   - 멱등법칙: a ⊕ a = a
## 위 세 가지가 성립하면 병합 연산은 순서/횟수에 무관하게 동일한 결과를 낸다.

import std/hashes

type
  NodeId* = distinct string
    ## 분산 노드를 식별하기 위한 고유 식별자. 동일한 클러스터 내에서는
    ## 서로 다른 노드가 같은 NodeId 를 가질 수 없다.

  Timestamp* = uint64
    ## 단조 증가 타임스탬프. LWW 계열 CRDT 에서 항목의 최신성을 판단한다.
    ## 실제 시각이 아닌 논리적 순서만 보장하면 충분하다.

  CrdtError* = object of CatchableError
    ## CRDT 연산 과정에서 발생하는 일반적 예외의 기본 타입.

proc `$`*(id: NodeId): string {.borrow.}
proc `==`*(a, b: NodeId): bool {.borrow.}
proc hash*(id: NodeId): Hash {.borrow.}

proc newNodeId*(raw: string): NodeId =
  ## 주어진 문자열로부터 NodeId 를 생성한다.
  ## 빈 문자열은 노드 식별자로 의미가 없으므로 거부한다.
  if raw.len == 0:
    raise newException(CrdtError, "NodeId 는 빈 문자열일 수 없다")
  result = NodeId(raw)

proc compareTimestamp*(a, b: Timestamp): int =
  ## 두 타임스탬프를 비교해 a<b 이면 -1, a==b 이면 0, a>b 이면 1 을 반환한다.
  ## 타이브레이크는 호출자 책임이며, 여기서는 순수한 크기 비교만 수행한다.
  if a < b: -1 elif a > b: 1 else: 0

proc maxTimestamp*(a, b: Timestamp): Timestamp =
  ## 두 타임스탬프 중 더 큰 값을 반환한다. LWW 병합의 핵심 연산이다.
  if a >= b: a else: b
