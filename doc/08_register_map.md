# APB 레지스터 맵 (RTL 기준)

바이트 오프셋, 32비트 워드 접근. `pstrb = 4'b1111` 가정.

## 제어 / 상태

| 오프셋 | 이름 | R/W | 설명 |
|--------|------|-----|------|
| 0x0000 | CTRL | RW | `[0]` module_en, `[1]` sw_rst, `[2]` addr_filter_en |
| 0x0004 | BW_EN | RW | `[0]` bandwidth logging enable |
| 0x0008 | LAT_EN | RW | `[0]` latency logging enable |
| 0x000C | THR_EN | RW | `[0]` throttle enable (**리셋 기본 0**) |
| 0x0010 | PERIOD_MODE | RW | `[0]` 0=cycle, 1=transaction count |
| 0x0014 | PERIOD_VAL | RW | 주기 목표 |
| 0x0018 | N_SWITCH | RW | N period마다 Even/Odd 전환·IRQ (0→1 클램프) |
| 0x001C | INT_EN | RW | `[0]` interrupt enable |
| 0x0020 | INT_CLR | WO | `pwdata[0]=1`이면 IRQ pending 클리어 |
| 0x0024 | ADDR_START_LO | RW | 시작 주소 [31:0] |
| 0x0028 | ADDR_START_HI | RW | 시작 주소 [63:32] |
| 0x002C | ADDR_SIZE_LO | RW | 크기 [31:0] |
| 0x0030 | ADDR_SIZE_HI | RW | 크기 [63:32] |
| 0x0034 | THR_PERIOD | RW | 스로틀 평가 주기(사이클) |
| 0x0038 | THR_MAX_BYTES | RW | 스로틀 주기당 바이트 상한 |
| 0x003C | THR_AW_DELAY | RW | 스로틀 **활성 주기**에서 AW 갭 사이클 |
| 0x0040 | THR_AR_DELAY | RW | 스로틀 **활성 주기**에서 AR 갭 사이클 |
| 0x0044 | STATUS | RO | `[0]` write_bank, `[1]` last_int_bank, `[2]` sample_ovf |

## FIFO 비우기 (포인터만 맞춤, 메모리 내용은 그대로)

| 오프셋 | 이름 | R/W | 설명 |
|--------|------|-----|------|
| 0x0090 | FIFO_FLUSH | WO | `[0]=1`이면 **Even** 뱅크 FIFO를 empty로 (`wptr<=rptr`). `[1]=1`이면 **Odd** 뱅크. 데이터 RAM은 초기화하지 않음. 읽기는 0 |

## 샘플 FIFO (Even/Odd 각각 동일 깊이)

한 샘플 = **480비트 = 15×32비트 워드**. **평균 나눗셈 없음** — 원시 합·카운터·주기 메트릭만 저장.

| 오프셋 | 이름 | R/W | 설명 |
|--------|------|-----|------|
| 0x0048 | SAMPLE_EVEN_POP | RO | Even 뱅크에서 pop, `prdata[31:0]` = 워드0 (wr_bytes[31:0]), shadow 채움 |
| 0x004C | SAMPLE_ODD_POP | RO | Odd 뱅크에서 pop |
| 0x0050 | SHADOW_0 | RO | 샘플 워드 0 = `wr_bytes[31:0]` (POP 직후 동일 사이클에 유효) |
| 0x0054 … 0x008C | SHADOW_1 … SHADOW_14 | RO | 아래 워드 순서 |

### 샘플 워드 순서 (리틀엔드 워드 인덱스)

| 인덱스 | 필드 |
|--------|------|
| 0 | wr_bytes[31:0] |
| 1 | wr_bytes[63:32] |
| 2 | rd_bytes[31:0] |
| 3 | rd_bytes[63:32] |
| 4 | lat_sum_wr[31:0] |
| 5 | lat_sum_wr[63:32] |
| 6 | lat_cnt_wr |
| 7 | lat_sum_rf[31:0] |
| 8 | lat_sum_rf[63:32] |
| 9 | lat_cnt_rf |
| 10 | lat_sum_rl[31:0] |
| 11 | lat_sum_rl[63:32] |
| 12 | lat_cnt_rl |
| 13 | period_cycles_field — **txn 모드**(`PERIOD_MODE=1`): 그 주기에서 실제로 경과한 사이클 수. **cycle 모드**(`PERIOD_MODE=0`): `PERIOD_VAL`과 동일한 목표 길이(고정)로 기록 |
| 14 | period_txns_field — 그 주기 동안의 AW+AR(필터 통과) 이벤트 수 |

**스로틀 동작:** 각 `THR_PERIOD` 말에 바이트 합과 상한을 비교하고, **그 결과는 다음 스로틀 주기 전체**에 적용된다. 초과 시 그 주기는 갭 삽입(throttle), 미만/같으면 패스스루. 이를 반복한다.

**동시 push/pop:** 하드웨어는 한 뱅크에서 push(로깅 주기 끝)와 pop(APB)이 같은 사이클에 일어날 수 있다고 가정한다(서로 다른 포인터일 때).
