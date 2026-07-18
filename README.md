# crdt-nim

Nim 으로 구현한 Conflict-free Replicated Data Type (CRDT) 라이브러리.

분산 시스템에서 네트워크 분리나 지연이 있어도 최종적 일관성(eventual consistency)을
보장하는 자료구조 모음이다. 모든 병합 연산은 결합법칙, 교환법칙, 멱등법칙을 만족해
순서와 횟수에 무관하게 동일한 결과로 수렴한다.

## 지원하는 CRDT

| 모듈            | 설명                                              | 삭제 후 재추가 |
|-----------------|---------------------------------------------------|----------------|
| `gset`          | Grow-Only Set. 합집합으로만 병합                    | 불가           |
| `twopset`       | Two-Phase Set. 추가 집합 + 제거 집합                | 불가           |
| `lwwset`        | Last-Write-Wins Set. 타임스탬프 기반               | 가능           |
| `ormap`         | Observed-Remove Map. 항목 ID 로 키 관리           | 가능           |
| `vectorclock`   | 벡터 클럭. 인과 관계 추적, 동시성 감지             | -              |

## CRDT 이론

CRDT 는 Shapiro 등이 2007 년 제안한 자료구조로, 분산 환경에서 조정(coordination)
없이 충돌 없는 병합을 보장한다. 핵심 아이디어는 상태 공간이 반격자(join-semilattice)를
이루도록 설계해, 병합 연산이 최소 상한(least upper bound)을 계산하게 하는 것이다.

### 수학적 속성

모든 CRDT 의 병합 연산 `⊕` 은 다음 세 가지를 만족해야 한다.

1. **교환법칙 (Commutativity)**: `a ⊕ b = b ⊕ a`
   - 병합 순서가 결과에 영향을 주지 않는다.

2. **결합법칙 (Associativity)**: `(a ⊕ b) ⊕ c = a ⊕ (b ⊕ c)`
   - 병합을 묶어서 수행해도 결과가 동일하다.

3. **멱등법칙 (Idempotency)**: `a ⊕ a = a`
   - 같은 상태를 여러 번 병합해도 변하지 않는다.

이 세 가지가 성립하면, 네트워크 지연/재전송/순서 뒤바뀜에 무관하게
모든 복제본이 동일한 상태로 수렴한다.

### 각 CRDT 의 병합 정의

**GSet**: `merge(A, B) = A ∪ B`
- 합집합은 자명하게 세 법칙을 만족한다.

**2P-Set**: `merge((A1,R1), (A2,R2)) = (A1 ∪ A2, R1 ∪ R2)`
- 추가 집합과 제거 집합 각각이 GSet 이므로 동일하게 성립.

**LWW-Set**: 각 원소마다 타임스탬프가 더 큰 쪽을 채택.
- `M[e] = argmax_{entry ∈ {A[e], B[e]}} entry.ts`
- 동일 타임스탬프 충돌 시 삭제 우선 정책으로 결정적 결과 보장.

**OR-Map**: entries 와 tombstones 각각을 합집합.
- 항목 ID 가 고유하므로 동시 추가가 안전하게 병합된다.

**Vector Clock**: `merge(A, B)[n] = max(A[n], B[n])`
- max 연산은 교환/결합/멱등 법칙을 만족한다.

## 사용법

### GSet

```nim
import src/gset

let a = newGSet[int]()
let b = newGSet[int]()
a.add(1); a.add(2)
b.add(2); b.add(3)

let merged = merge(a, b)
echo merged.card  # 3
```

### LWW-Set

```nim
import src/lwwset

let s = newLWWSet[string]()
s.add("apple", 10)
s.remove("apple", 15)
s.add("apple", 20)  # 삭제 후 재추가 가능
echo "apple" in s   # true
```

### OR-Map

```nim
import src/crdt
import src/ormap

let m = newORMap[string, int](newNodeId("node-1"))
discard m.put("k", 1)
m.remove("k")
discard m.put("k", 2)  # 재추가 가능
echo m.lookup("k")  # @[2]
```

### Vector Clock

```nim
import src/crdt
import src/vectorclock

let a = newVectorClock()
let b = newVectorClock()
let nA = newNodeId("A")
let nB = newNodeId("B")
a.tick(nA)
b.tick(nB)
echo a.isConcurrentWith(b)  # true (동시)
```

## 설치 및 테스트

```bash
nimble test
# 또는
nim c -r tests/test_all.nim
```

Nim 2.0 이상이 필요하다.

## 보안 고려

- **입력 검증**: 외부 입력은 CRDT 연산 전 크기/타입/인코딩을 검증해야 한다.
- **타임스탬프**: LWW 계열의 타임스탬프는 신뢰된 출처에서 발급해야 하며,
  미래 타임스탬프 공격을 방지하기 위한 상한 검사가 필요하다.
- **NodeId**: 벡터 클럭과 OR-Map 의 NodeId 는 인증된 노드만 등록해야 한다.
- **메모리**: tombstone 은 단조 증가하므로, 장기 운영 시 가비지 컬렉션
  정책이 필요하다.

## 라이선스

MIT
