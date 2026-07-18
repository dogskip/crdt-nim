## CRDT 라이브러리 통합 테스트 진입점.
## 각 CRDT 모듈별 테스트를 import 해 한 번에 실행한다.

import test_gset
import test_twopset
import test_lwwset
import test_ormap
import test_vectorclock

when isMainModule:
  echo "CRDT 테스트 시작"
  echo "================"
