# AXI Performance Monitor — 코딩 AI용 완전 프롬프트

역할: 당신은 **SoC interconnect / memory subsystem** 경험이 있는 **RTL 설계 엔지니어**다. 아래 제약을 **모두** 만족하는 **합성 가능(synthesizable)** SystemVerilog RTL을 작성하라. (Assertions는 `ifdef`로 시뮬 전용 처리 가능.)

---

## A. 최상위 토폴로지

1. **데이터 경로**
   - **Upstream-facing AXI Slave** 포트 `s_axi_*` (CPU/IC 측 마스터가 붙음).
   - **Downstream-facing AXI Master** 포트 `m_axi_*` (DRAM 컨트롤러 등 슬레이브로 향함).
   - 사용자 표현의 “master up / master down”은 문서에서 **s_axi(상류) / m_axi(하류)** 로 매핑한다.

2. **투명 패스스루**
   - 기능상 **프로토콜 준수** 범위에서 주소/데이터/응답을 전달한다.
   - Throttle 활성 시에만 **Slave 측 `awready`/`arready`** 를 인위적으로 지연한다 (Downstream ready는 그대로 전달하되, Slave가 주소를 받는 시점을 늦춤).

3. **Register Slice**
   - Parameter `USE_SLICE_UP`, `USE_SLICE_DN` (또는 동일 의미)로 **Up/Down 경로 각각** 1사이클(또는 파이프라인 단계) 삽입 여부 선택.
   - Slice는 **5채널(AW,W,B,AR,R)** 모두에 대해 일관되게 적용하거나, 최소한 **경로 길이 불일치**가 없도록 구현.

---

## B. 파라미터 (기본값 명시)

| Parameter | 권장 기본 | 설명 |
|-----------|-----------|------|
| `AXI_ADDR_WIDTH` | 64 | 주소 폭 |
| `AXI_DATA_WIDTH` | 256 | 데이터 폭 |
| `AXI_ID_WIDTH` | 8 | ID 폭 |
| `AXI_USER_WIDTH` | 1 | User 신호 폭 (0이면 타이드) |
| `FIFO_DEPTH` | 32 | 로그 샘플 FIFO 깊이 (Even/Odd 각각 동일 깊이) |
| `MAX_AW_PENDING` | 16 | ID당 AW pending 깊이 (latency용) |
| `MAX_AR_PENDING` | 16 | ID당 AR pending 깊이 |
| `TIME_WIDTH` | 32 | 사이클 카운터 폭 |

**주소 정렬**: `ADDR_START`는 **AXI_DATA_WIDTH/8** 또는 시스템 정책에 맞게 **정렬** 요구사항을 문서화하고, 레지스터 쓰기 시 **하위 비트 마스크** 처리.

---

## C. APB CSR (32-bit, `pstrb == 4'b1111` 고정 가정)

- **동일 클럭** `aclk`, **동일 리셋** 극성.
- **Word-aligned** 주소 맵. 읽기/쓰기 동작 명확히 정의.
- 다음 **최소** 레지스터 집합:

### Control

- `GLOBAL_CTRL`: 소프트 리셋, 모듈 마스터 enable.
- `BW_EN`, `LAT_EN`, `THR_EN`: 각 기능 enable.
- `PERIOD_MODE`: 0 = cycle 기반, 1 = transaction 기반.
- `PERIOD_VAL`: cycle 모드일 때 목표 사이클 수; txn 모드일 때 목표 트랜잭션 수 (AW+AR 핸드셰이크 각각 1 카운트로 정의하고 문서화).
- `ADDR_FILTER_EN`: 0 = 전체 추적, 1 = `[START, START+SIZE)` 필터.
- `ADDR_START`, `ADDR_SIZE` (64-bit는 상·하 워드 2레지스터).
- `N_SWITCH`: Even/Odd 뱅크 전환 주기(**Period 단위**). **반드시 `N_SWITCH < FIFO_DEPTH`** 를 하드웨어에서 클립 또는 에러 플래그.
- `INT_EN`, `INT_CLEAR` 또는 W1C: 레벨 인터럽트 클리어 방식 명시.
- Throttle 전용: `THR_PERIOD`, `THR_MAX_BYTES`, `THR_AW_DELAY`, `THR_AR_DELAY`.

### Status (읽기)

- `CUR_BANK`: 현재 **쓰기** 중인 로그 뱅크 (even=0, odd=1).
- `LAST_INT_BANK`: 마지막 인터럽트가 **어느 뱅크에 샘플 푸시 직후**에 세트되었는지.
- `FIFO_LEVEL`, `FIFO_OVERFLOW` (뱅크별 또는 합산 — 문서에 명시).
- Bandwidth/Latency **샘플 읽기** 포트: 팝 읽기 또는 인덱스 읽기 중 하나로 일관되게.

### 인터럽트

- **단일** `irq` 출력: `INT_EN` 및 N-switch 이벤트 시 **레벨**로 assert; 소프트웨어가 status/clear로 해제.

---

## D. Bandwidth Logging

1. **바이트 계산**
   - 각 트랜잭션: `bytes = (1<<size) * (len+1)`.
   - Write: AW 핸드셰이크 시 W 데이터와 일치한다고 가정하고 **AW 기준**으로 카운트 (또는 W 완료 기준 — **한 가지로 고정**하고 문서화).
   - Read: AR 핸드셰이크 기준.

2. **필터**
   - `ADDR_FILTER_EN`일 때 **AW/AR의 주소**가 범위에 들어올 때만 카운트.

3. **Period**
   - Cycle 모드: 내부 사이클 카운터.
   - Txn 모드: **필터를 통과한** AW+AR 핸드셰이크 횟수 합.

4. **FIFO**
   - Period 종료 시 `(wr_bytes, rd_bytes)` 샘플을 **현재 활성 뱅크**에 push.
   - **N_SWITCH** period마다 활성 뱅크 토글 (even↔odd).
   - FIFO full 시 **overflow** 플래그, 오래된 샘플 드롭 또는 정지 중 정책 **하나를 선택**하고 구현.

5. **인터럽트**
   - 뱅크 전환 경계(즉 N period마다)에 **레벨 IRQ** (enable 시).

---

## E. Latency Logging (평균)

1. **동일 Period** 레지스터 사용.

2. **Write (AW→B)**
   - AW 수락 시각 기록, 동일 ID의 B 수락 시 지연 = `B_time - AW_time` (사이클).
   - **ID별 pending FIFO** (파라미터 깊이). 초과 시 **overflow 플래그** 및 샘플 스킵.

3. **Read**
   - **AR→첫 RVALID** (해당 burst의 첫 데이터 비트 유효).
   - **AR→마지막 RVALID & RLAST**.
   - ID별 outstanding read FIFO 필요.

4. **Period 종료 시**
   - 각 메트릭별 `sum`, `cnt`로부터 평균 = `cnt ? sum/cnt : 0` 저장 (나눗셈: **파이프라인 나눗셈 유닛** 또는 시계열 누적 후 주기마다 한 번).

5. **Even/Odd FIFO**
   - Bandwidth와 **동일한 뱅크 전환 타이밍**에 latency 평균 샘플 레지스터/FIFO 엔트리에 커밋.

---

## F. Throttling

1. **독립** `THR_PERIOD` 사이클 카운터.

2. **카운트**
   - **필터 ON인 동일 주소 범위**에서만 write+read 바이트 합산 (bandwidth와 동일 산식).

3. **조건**
   - Period 종료 시 `bytes > THR_MAX_BYTES` 이면 다음 period 동안 (또는 지정된 hold 정책) **throttle active**.

4. **구현**
   - Slave `awready`/`arready`를 내부적으로 **AND** with delay FSM; **AW/AR 각각** 지연 사이클 수 적용.
   - **다운스트림** `m_axi` ready는 **변조하지 않음** (요청을 늦게 받을 뿐).

---

## G. Assertions (최소)

- AXI4 **핸드셰이크 규칙** (valid/ready).
- `N_SWITCH < FIFO_DEPTH`.
- Throttle delay **상한** (레지스터 값 클립).
- FIFO overflow **감지** assert.
- 리셋 중 출력 X 전파 방지 관련 기본 체크.

---

## H. 산출물

1. `design/rtl/`에 패키지, CSR, 코어, 슬라이스, 탑.
2. `doc/`에 개요·레지스터 맵·제약.
3. `verification/tb/`에 기본 스모크 벤치.
4. `design/README.md`, `verification/README.md`에 빌드/시뮬 가이드 한 단락.

---

## I. 코딩 스타일

- `snake_case` 파일/신호명.
- 합성 가능한 always_ff / always_comb 사용.
- 주석은 **인터페이스/레지스터 맵/비명확한 정책**에만.
