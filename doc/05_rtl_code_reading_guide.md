# 05 — RTL 읽는 순서

1. **`axi_perf_monitor_pkg.sv`**  
   `burst_bytes`, `addr_in_range`.

2. **`axi_perf_monitor_core.sv`**  
   - CSR 주소: `OFF_*` localparam  
   - 패스스루: `m_axi_* = s_axi_*` (payload), ready는 스로틀·`csr_module_en`  
   - `time_ctr`, 로깅/스로틀 블록, `always_ff`의 APB 읽기/쓰기

3. **`axi_perf_monitor_top.sv`**  
   `cs_*` = 코어 슬레이브 측, `cm_*` = 코어 마스터 측; slice generate.

4. **`axi_perf_monitor_slice.sv`**  
   조합 연결. 타이밍 마감용으로는 벤더 slice로 교체.

5. **`axi_perf_monitor_sva.sv`**  
   (옵션) 유효→레디 안정성 등.

## 디버깅 팁

- `STATUS`: `last_int_bank`, `write_bank`, overflow 비트.
- IRQ: `INT_EN` + `INT_CLR` (0x20 쓰기 bit0).
- `FIFO_FLUSH`(0x0090): Even/Odd FIFO empty(포인터만 동기). RAM 내용은 유지.
