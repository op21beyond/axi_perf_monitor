# 02 — 마이크로아키텍처

## 데이터 경로

- **슬레이브** `s_axi_*`는 상류 마스터와 핸드셰이크; **마스터** `m_axi_*`는 하류를 구동.
- 페이로드는 **조합 연결**; 스로틀은 `s_axi_awready` / `s_axi_arready`만 게이트(모듈 enable 및 `aw_gap`/`ar_gap`).

## 시간 기준

- 전역 `time_ctr` 카운터(사이클)로 지연 누적.
- Write: ID별 FIFO로 AW 시각 저장, B에서 앞에서부터 매칭(동일 ID 내 순서 가정).
- Read: ID별 AR 큐에 `{t_ar, beats_total, beats_rem}`; R 비트마다 `beats_rem` 감소, 첫 R/마지막 R에서 평균 합산.

## 로깅 주기

- **Cycle 모드**: `period_cycle_ctr`가 `PERIOD_VAL-1`에 도달하면 종료.
- **Txn 모드**: 필터 통과 AW+AR 각각 1씩 `txn_inc`로 합산, `period_txn_ctr + txn_inc >= PERIOD_VAL`이면 종료.

## Even/Odd

- `write_bank`에 대해 period 종료 시 **통합 샘플(480bit)** FIFO push. `n_period_ctr`가 `N_SWITCH-1`까지 도달한 뒤 다음 period에서 뱅크 토글 및(옵션) IRQ pulse.

## 스로틀

- 각 스로틀 주기 말에 `thr_bytes`와 `THR_MAX_BYTES`를 비교하고, **그 결과는 다음 스로틀 주기 전체**에 적용된다(`thr_apply_reg`). 초과 시 그 주기 동안만 AW/AR 수락 후 갭 삽입, 아니면 패스스루. 반복.
- 스로틀 기본 비활성(`THR_EN` 리셋 0).

## FIFO 읽기

- `SAMPLE_EVEN_POP` / `SAMPLE_ODD_POP`으로 pop 후 `0x50`~`0x8C` shadow 15워드로 원시 합·카운터·주기 메트릭을 읽는다(나눗셈 없음).
- push(주기 끝)와 pop(APB)은 **동시에 발생 가능**하도록 설계(서로 다른 포인터일 때).
