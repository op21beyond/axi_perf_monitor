# 03 — 파라미터 및 제약

## Top / Core 파라미터

| 파라미터 | 기본(예) | 설명 |
|----------|-----------|------|
| `AXI_ADDR_WIDTH` | 64 | 주소 폭 |
| `AXI_DATA_WIDTH` | 256 | 데이터 폭 |
| `AXI_ID_WIDTH` | 8 (top 예: 4) | ID 폭; 내부 pending RAM 크기는 `2**ID_WIDTH` |
| `AXI_USER_WIDTH` | 1 | User 폭 |
| `FIFO_DEPTH` | 32 | Even/Odd 각각 동일 깊이 |
| `TIME_WIDTH` | 32 | 지연 시간 카운터 폭 |
| `MAX_PENDING_PER_ID` | 8 | ID당 AW/AR 대기 깊이 |
| `USE_SLICE_UP` / `USE_SLICE_DN` | 0 | top에서만; slice는 현재 조합 패스스루 |

## CSR 제약

- `PERIOD_VAL`, `N_SWITCH`가 0이면 하드웨어에서 1로 클램프되는 값이 있음(주기·N이 0으로 나누기/무동작 방지).
- `N_SWITCH < FIFO_DEPTH` 권장(정의 `AXI_PERF_MONITOR_ASSERT` 시 assert).

## 주소

- `ADDR_START`/`ADDR_SIZE`는 64비트; `SIZE==0`이면 필터 ON일 때 추적 없음, 스로틀 합산도 없음.

## AXI 가정

- 동일 ID에 대한 **B 응답 순서**가 AW 순서와 일치한다고 가정(순서 어긋나면 지연 통계가 틀어질 수 있음).
- Read는 동일 ID에서 **AR 순서대로 R**이 온다고 가정(AXI4 read reordering 규칙).
