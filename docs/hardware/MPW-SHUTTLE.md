# European MPW shuttle & process selection

A **multi-project wafer (MPW)** puts many designs on one shared wafer so a
startup pays a fraction of a full mask set. This is how clic-A1 gen-1 gets to
silicon affordably. *(Verify current nodes, pricing, and dates with each broker
before committing — offerings rotate.)*

## The European options

| Broker | 🇪🇺 | Strength | Best for |
|--------|:--:|----------|----------|
| **Europractice** | yes | THE European MPW + **subsidized EDA licenses** for startups/academia; broad access incl. FD-SOI | the FD-SOI prototype |
| **CMP** (Circuits Multi-Projets, Grenoble) | 🇫🇷 | STMicro **FD-SOI (28/22 nm)**; Grenoble = CEA-Leti / Minalogic ecosystem | first FD-SOI run + CEA-Leti pairing |
| **IHP** (Germany) | 🇩🇪 | **open-source PDK** (SG13G2, 130 nm SiGe) + MPW | cheap open first block |
| ChipFoundry / TinyTapeout | 🇺🇸 | very cheap SkyWater 130 nm shuttles | "hello silicon" learning tile only |

## Process selection — FD-SOI

**FD-SOI is the recommendation** for an inference accelerator: low dynamic and
leakage power, and **body biasing** (forward for speed, reverse to kill idle
leakage) — a direct knob on the TOPS/W target. It's also a **European** process
(STMicro Crolles 🇫🇷, GlobalFoundries Dresden 🇩🇪), which strengthens the
sovereignty narrative and the CEA-Leti fit.

| Node | Via | Notes |
|------|-----|-------|
| **28 nm FD-SOI (STMicro)** | CMP | mature, affordable, French — the natural first FD-SOI prototype |
| **22 nm FD-SOI (GF 22FDX)** | Europractice | denser/lower-power, German fab, a bit pricier |
| 130 nm (IHP SG13G2, open PDK) | IHP | open-source flow; too coarse for real AI density — flow/first-block only |
| 130 nm (SkyWater) | ChipFoundry / TinyTapeout | cheapest; learning tile only |

## Recommended sequence

1. **Pre-prototype (optional, cheap):** a tiny MAC core + ISA decoder on a
   **130 nm open-PDK** shuttle (IHP or SkyWater) using the fully open EDA flow —
   proves RTL, flow, and bring-up for a few hundred to low-thousands of euros,
   and gives an open-silicon story.
2. **gen-1 prototype:** the [MVP silicon](MVP-SILICON.md) (one cluster + SRAM +
   SPI) on **28 nm FD-SOI via CMP** (or 22FDX via Europractice), using
   **Europractice-subsidized EDA** and, ideally, **CEA-Leti** for physical
   design + sign-off.
3. **gen-2:** a dedicated (non-MPW) run once the architecture and customers are
   proven.

## Why this reads as a serious startup

You are naming the exact vehicle (Europractice/CMP), the exact node family
(FD-SOI), the exact first-run scope (one cluster, SPI, on-chip SRAM), and the
exact partner (CEA-Leti) — with a working software stack already behind it. That
is a fundable plan, not an idea.
