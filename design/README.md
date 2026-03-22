# design/

RTL for the AXI performance monitor IP.

## Files

| File | Role |
|------|------|
| `rtl/axi_perf_monitor_pkg.sv` | Shared functions (burst bytes, address range) |
| `rtl/axi_perf_monitor_core.sv` | APB CSR, AXI pass-through, logging, throttle |
| `rtl/axi_perf_monitor_slice.sv` | Combinational AXI pass-through (replace with vendor slice if needed) |
| `rtl/axi_perf_monitor_top.sv` | Top with `USE_SLICE_UP` / `USE_SLICE_DN` |
| `rtl/axi_perf_monitor_sva.sv` | Optional SVA (enable with `AXI_PERF_MONITOR_SVA`) |

## Topology

- **up_***: AXI slave toward upstream masters (interconnect).
- **dn_***: AXI master toward downstream slaves (e.g. memory controller).
- **APB**: 32-bit control/status, same clock as AXI; assume `pstrb = 4'b1111`.

## Simulation

Include all `rtl/*.sv` in compilation order: package first, then core/top. For assertions in core, define `AXI_PERF_MONITOR_ASSERT`.

## Documentation

Numbered guides under `doc/` (`00_overview.md` … `09_software_guide.md`). APB map: `doc/08_register_map.md`. Software flow: `doc/09_software_guide.md`.
