## 소비자 관점 검사. 설치된 패키지를 바깥에서 가져다 사용한다.
##
## 저장소 안의 상대 경로가 아니라 패키지 이름으로 import 하므로, 배포된 형태가
## 실제로 쓸 수 있는지까지 확인한다.

import crdt

proc converge[T: Crdt](replicas: var seq[T]) =
  ## 모든 복제본이 서로를 흡수하게 한다.
  for i in 0 ..< replicas.len:
    for j in 0 ..< replicas.len:
      if i != j:
        replicas[i].mergeInto(replicas[j])

proc expect(ok: bool, what: string) =
  if not ok:
    echo "실패: ", what
    quit(1)

var sets = @[newGSet[string](), newGSet[string](), newGSet[string]()]
sets[0].add "a"
sets[1].add "b"
sets[2].add "c"
converge(sets)
expect(sets[0] == sets[1] and sets[1] == sets[2], "GSet 이 수렴해야 한다")
expect(sets[0].card == 3, "GSet 은 합집합이어야 한다")

var twops = @[newTwoPSet[string](), newTwoPSet[string]()]
twops[0].add "x"
discard twops[1].remove "x"
converge(twops)
expect("x" notin twops[0], "추가를 받기 전에 제거한 원소는 병합 뒤에도 없어야 한다")

let map0 = newORMap[string, int](newNodeId("n0"))
discard map0.put("k", 1)
map0.remove("k")
let map1 = merge(map0, newORMap[string, int](newNodeId("n1")))
discard map1.put("k", 2)
expect(map1.lookup("k") == @[2], "병합 뒤에 넣은 값이 살아 있어야 한다")

let clock = newVectorClock()
clock.tick(newNodeId("n0"))
expect(clock.get(newNodeId("n0")) == 1, "벡터 클럭이 증가해야 한다")

echo "소비자 검사 통과"
