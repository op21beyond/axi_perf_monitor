# 07 — SoC 통합 (APB / 인터럽트)

## APB

- 32비트 워드 정렬 주소; `pstrb = 4'b1111` 가정.
- `pready`: `psel & penable` (단일 사이클 접근 모델).
- 리셋: `aresetn` 비동기 저활성; `CTRL[1]` 소프트 리셋은 카운터/누적만 클리어.

## 인터럽트

- **한 줄** `irq`: `irq_pending & INT_EN`.  
- 클리어: `INT_CLR` (0x20)에 `pwdata[0]=1`로 pending 클리어.

## 연결 예

- 상류: 인터커넥트 마스터 → `up_*` (이 IP 슬레이브).
- 하류: 이 IP 마스터 `dn_*` → DRAM 컨트롤러 등.
- CPU: APB 버스 + `irq`를 인터럽트 컨트롤러에 연결.

## 레지스터 맵

상세 비트는 `08_register_map.md` 참고.
