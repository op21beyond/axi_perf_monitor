# AXI Performance Monitor — 사용자 요구사항

## 1. 설계 목표

상용 양산 가능한 수준의 완성도로 Verilog/SystemVerilog로 AXI 성능 모니터 IP를 설계한다.

## 2. 인터페이스

1. **AXI Master Up / Master Down**
   - Up과 Down은 **동일한 데이터 폭**, **동일한 클럭**을 사용한다.
   - 기본 AXI 데이터 폭은 **256bit**이다.

2. **제어/상태 레지스터**
   - Slave 인터페이스로 읽기/쓰기하여 제어·상태 레지스터에 접근한다.

3. **기능별 Enable/Disable**
   - Control 레지스터에 **기능별 enable/disable 필드**가 있어야 한다.

## 3. Performance Logging

### 3.1 Bandwidth Logging

1. **Period**
   - **Cycle** 또는 **Transaction 수** 중 하나를 레지스터로 선택 가능.
   - Enable 시 **반복** 동작.

2. **측정**
   - `AXI size × burst length`로 전송 바이트 수 산출.
   - Write / Read 바이트를 각각 누적하고, **Period timeout**마다 **FIFO**에 저장.

3. **FIFO**
   - Depth는 **parameter**로 정의.
   - **Even / Odd** 두 뱅크가 있으며, **N번 Period**마다 저장 위치가 Even ↔ Odd로 전환.
   - **N**은 FIFO depth보다 작은 값이며 **Control register**로 설정.

4. **인터럽트**
   - N번 Period마다 **레벨 인터럽트** 출력 가능.
   - Control register의 **interrupt enable**로 활성화.

5. **상태**
   - 현재 저장 FIFO 위치(Even/Odd).
   - 마지막 인터럽트가 **어느 FIFO(Even/Odd) 저장 이후**에 발생했는지.

6. **주소 필터**
   - Control register의 **시작 주소 + 크기** 범위 내 트랜잭션만 추적하거나, **전체** 추적을 선택.

### 3.2 Latency Logging

1. **Period**
   - Bandwidth logging과 **동일한 Period 레지스터** 사용.

2. **Write Latency**
   - AXI **AW 수락 이후 B 수락까지** 카운터.

3. **Read Latency**
   - **AR 이후 첫 RVALID**까지.
   - **AR 이후 마지막 RLAST & RVALID**까지 (두 값 각각 로그).

4. **저장 방식**
   - 트랜잭션 단위 저장이 아니라 **Period마다 평균** 저장.
   - Latency **누적합**과 **트랜잭션 수**를 카운트하여 Period timeout 시 저장.

5. **FIFO**
   - Bandwidth와 동일한 Even/Odd 구성 및 **동일한 N**에 따른 타이밍.

6. **주소 필터**
   - Bandwidth logging과 동일.

## 4. Bandwidth Throttling

1. **Period**
   - Logging의 Period와 **별도**로 `period_throttle`을 Control register에 설정.

2. **동작**
   - 동일한 방식으로 Bandwidth를 카운트.
   - `period_throttle` 주기마다 설정값보다 크면 **AW/AR 채널**의 `awready`, `arready`에 **지연**을 삽입하여 대역폭을 낮춘다.

3. **지연**
   - AW / AR 각각 **다른 delay** 값을 Control register로 설정 가능.

4. **적용 범위**
   - Logging에서 사용하는 **base/size 주소 영역에 대해서만** 적용.

## 5. 타이밍·구조

1. 고주파수 동작을 고려한 설계.
2. Up / Down에 **Optional Register Slice** (parameter로 선택).

## 6. 레지스터 버스

1. Control / Status는 **APB 32bit**.
2. `pstrb`는 **0xF 고정** 가정.
3. Master AXI와 **동일 클럭**.

## 7. 인터럽트

- **인터럽트 1개**.

## 8. 검증

- 충분한 **assert** (SVA 등) 추가.

## 9. 프로젝트 구조

첨부한 **RANK_INTERLEAVING** 스타일과 일관되게:

- `design/rtl/`, `design/README.md`
- `doc/` (번호 붙은 개요 문서)
- `prompt/` (`user_prompt.md`, `complete_prompt.md`)
- `scripts/`
- `verification/` (`dpi/`, `model/`, `scripts/`, `tb/`, `README.md`)
