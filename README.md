# AXI Performance Monitor

AXI4 트래픽을 **투명하게 통과**시키면서, 동일 클럭의 **APB(32bit)** 로 대역폭·지연 통계를 수집하고, 선택적으로 **대역폭 스로틀**을 걸 수 있는 SoC용 RTL IP입니다.

## 주요 기능

- **대역폭 로깅**: 주기(사이클 수 또는 AW+AR 트랜잭션 수)마다 read/write 바이트 합을 샘플로 기록합니다.
- **지연 로깅**: AW→B, AR→첫 R, AR→마지막 R에 대해 **지연 사이클 합**과 **표본 수**를 주기마다 기록합니다(하드웨어에서 평균 나눗셈 없음).
- **Even/Odd 더블 버퍼**: 로깅 샘플은 두 뱅크에 번갈아 쌓이며, `N` 주기마다 뱅크가 바뀌고(설정 가능) 이때 **레벨 IRQ**를 올릴 수 있습니다.
- **주소 필터**: 시작 주소·크기로 범위를 정하거나 전체를 추적할 수 있습니다.
- **스로틀(기본 OFF)**: 필터와 동일한 주소 영역에서, 별도 주기로 바이트 합을 보고 **다음 주기**에만 AW/AR 수락 뒤 갭을 넣어 대역폭을 제한합니다.
- **FIFO 비우기**: CSR로 Even/Odd FIFO를 empty로 만들 수 있습니다(포인터만 조정, RAM 내용은 유지).

## 인터페이스 요약

| 포트 | 설명 |
|------|------|
| `up_*` (top) | 상류 마스터가 붙는 **AXI slave** |
| `dn_*` (top) | 하류 슬레이브(예: 메모리)로 향하는 **AXI master** |
| APB | CSR·동일 클럭, `pstrb=4'b1111` 가정 |
| `irq` | 인터럽트 1개(레벨) |

기본 데이터 폭은 **256bit**이며, 파라미터로 조정할 수 있습니다.

## 디렉터리 구조

```
axi_perf_monitor/
├── design/
│   ├── rtl/          # SystemVerilog RTL (pkg, core, top, slice, optional SVA)
│   └── README.md     # RTL 파일 역할 요약
├── doc/              # 번호 매긴 설계·레지스터·SW 가이드 (00 … 09)
├── prompt/           # 사용자 요구 정리 및 코딩 AI용 프롬프트
├── scripts/          # 유틸 스크립트(플레이스홀더)
└── verification/
    ├── tb/           # 최소 탑 연결 TB
    ├── model/, dpi/, scripts/  # 확장용 자리
    └── README.md
```

## 문서

- **개요·아키텍처**: `doc/00_overview.md`, `doc/02_microarchitecture.md`
- **레지스터 맵**: `doc/08_register_map.md`
- **소프트웨어 사용**: `doc/09_software_guide.md`
- **프롬프트**: `prompt/user_prompt.md`, `prompt/complete_prompt.md`

## 시뮬레이션

시뮬레이터는 환경에 따라 다릅니다. 파일 컴파일 순서는 **패키지 → 코어/탑**이며, 자세한 힌트는 `design/README.md`를 참고하세요.

## 라이선스 / 상태

저장소에 라이선스가 명시되어 있지 않으면, 사용 전 조직 정책에 맞게 확인하세요. RTL은 SoC 통합 전 타이밍·검증이 필요합니다.
