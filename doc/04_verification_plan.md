# 04 — 검증 계획

## 목표

- 프로토콜: AXI4 핸드셰이크, `xVALID`·`xREADY` 규칙.
- 기능: period 모드, Even/Odd 전환, FIFO overflow 플래그, 스로틀 갭, 주소 필터.
- CSR: `complete_prompt.md` / `08_register_map.md`와 주소 일치.

## 계층

1. **단위**: `axi_perf_monitor_pkg` 함수(바이스트·범위).
2. **블록**: core + APB 읽기/쓰기, FIFO pop 시퀀스.
3. **시스템**: top + (선택) AXI BFM 마스터/슬레이브.

## 자동 체크

- `AXI_PERF_MONITOR_ASSERT` 정의 시 코어 내부 assert.
- `AXI_PERF_MONITOR_SVA` 정의 시 `axi_perf_monitor_sva.sv` 바인딩(선택).

## 직접 시험(향후)

- 대역폭: 알려진 SIZE/LEN으로 기대 바이트와 FIFO 샘플 비교.
- 지연: 고정 지연 슬레이브로 평균 비교.
- 스로틀: 상한 이하/이상에서 ready 패턴 관측.

## 현재 TB

`verification/tb/tb_axi_perf_monitor.sv`는 **타이-오프만** 있으며, 시뮬레이터 설치 후 BFM을 연결해 확장한다.
