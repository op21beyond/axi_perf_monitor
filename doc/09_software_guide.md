# 소프트웨어 사용 가이드

## 1. 초기화

1. 리셋 해제 후 `CTRL[0]=1`(module_en)으로 AXI 경로를 살린다.
2. 주소 필터를 쓰려면 `CTRL[2]=1` 후 `ADDR_START_*`, `ADDR_SIZE_*`를 설정한다. `SIZE=0`이면 필터 ON일 때 추적·스로틀 대상이 없다.
3. **스로틀은 기본 비활성**(`THR_EN=0`). 필요 시에만 `THR_EN=1`과 `THR_PERIOD`, `THR_MAX_BYTES`, `THR_AW_DELAY`, `THR_AR_DELAY`를 설정한다.

## 2. 로깅 주기

- `PERIOD_MODE`: `0`이면 `PERIOD_VAL` 사이클마다 한 샘플, `1`이면 필터 통과 AW+AR 핸드셰이트 합이 `PERIOD_VAL`에 도달할 때 한 샘플.
- `BW_EN` / `LAT_EN`으로 대역폭·지연 통계 수집을 각각 켠다. 둘 다 끄면 로깅 주기 엔진은 동작하지 않는다(`log_en`).

## 3. Even / Odd FIFO

- 샘플은 **Even 또는 Odd** 뱅크에 쌓이며, `N_SWITCH`개의 로깅 주기마다 쓰기 뱅크가 바뀐다(`STATUS[0]`).
- **읽기 순서 (권장):**
  1. `SAMPLE_EVEN_POP`(0x48) 또는 `SAMPLE_ODD_POP`(0x4C)를 **한 번** 읽어 pop을 수행한다. `prdata`는 워드0 하위이다.
  2. 같은 APB 사이클 또는 **그 직후** `SHADOW_0`(0x50) ~ `SHADOW_14`(0x8C)를 순서대로 읽어 15워드 샘플을 모은다. (POP 블로킹으로 shadow가 같은 사이클에 채워진다.)

**동시 접근:** 하드웨어는 한 뱅크에서 **샘플 push(주기 끝)**과 **APB pop**이 같은 사이클에 올 수 있다고 가정한다. 소프트웨어는 운영 정책상 “읽기 중에는 해당 뱅크에 쓰지 않는다” 또는 “인터럽트 후 반대 뱅크만 읽는다”처럼 버퍼링 정책을 두는 것이 안전하다.

## 4. 샘플 해석 (나눗셈 없음)

- `wr_bytes`, `rd_bytes`: 해당 주기 동안 필터를 통과한 쓰기/읽기 바이트 합.
- `lat_sum_*` / `lat_cnt_*`: 각각 AW→B, AR→첫 R, AR→마지막 R에 대한 **지연 사이클 합**과 **표본 개수**. 평균이 필요하면 소프트웨어에서 나눈다. 주기 길이가 고정이면 **합만으로 임계 비교**해도 된다.
- `period_cycles_field`, `period_txns_field`: 해당 주기의 경과 사이클 수·AW+AR 이벤트 수.

## 5. 인터럽트

- `INT_EN=1`일 때 `N_SWITCH` 주기마다 레벨 IRQ. `INT_CLR`(0x20)에 `pwdata[0]=1`로 pending 클리어.
- `STATUS[1]`은 마지막 IRQ가 어떤 쓰기 뱅크 기준 전환에서 올렸는지에 대한 힌트로 쓴다.

## 6. 스로틀

- 각 `THR_PERIOD` **끝**에 바이트 합을 `THR_MAX_BYTES`와 비교한다.
- **결과는 다음 `THR_PERIOD` 구간 전체**에 적용된다: 초과면 그 구간에서 AW/AR 수락 뒤 갭(`THR_AW_DELAY` / `THR_AR_DELAY`), 아니면 패스스루.
- 스로틀은 **주소 필터와 동일한 start/size 영역**에만 적용된다.

## 7. 오버플로

- `STATUS[2] sample_ovf`가 1이면 FIFO가 가득 찬 상태에서 push가 발생했다. 소프트웨어는 pop을 빠르게 하거나 `N_SWITCH`/주기를 조정한다.

## 8. FIFO 강제 비우기

- `FIFO_FLUSH`(0x0090)에 쓴다: `pwdata[0]=1`이면 Even 뱅크, `pwdata[1]=1`이면 Odd 뱅크 샘플 FIFO를 **empty**로 만든다(쓰기 포인터를 읽기 포인터와 같게 함). **저장 배열 비트는 지우지 않는다.**
- 읽기는 항상 0이다.
