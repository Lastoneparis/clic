# Fundraising playbook

The operational companion to [PITCH.md](../PITCH.md). What to prove, in what
order, for which money. All figures are planning estimates, not commitments;
verify current program terms before applying.

## What investors actually bet on (deep-tech chip startups)

| # | Signal | Where we stand | Action |
|---|--------|----------------|--------|
| 1 | **Team** with silicon credibility | ⚠️ gap — solo technical founder | **Recruit a silicon co-founder (top priority)** |
| 2 | **Technical wedge is real** | ✅ clic works, verified, open | Keep shipping; add FPGA perf/watt |
| 3 | **Believable silicon path** | 🟡 FPGA next → tiny tapeout | Build FPGA accel; tape out a block |
| 4 | **Market pull** | ❌ none yet | Land 1–2 design-partner LOIs |

The honest gatekeeper is **#1**. No European deep-tech VC funds a solo founder
building an AI accelerator, however good the demo. The `clic` repo is the
recruiting magnet for the co-founder.

## First steps (sequenced)
1. Reframe everything → "European fabless AI accelerator" (done: deck, PITCH).
2. Commit to one wedge: **sovereign / edge AI inference**.
3. Finish MVP evidence: FPGA accelerator + a **performance-per-watt** sheet.
4. **Recruit a chip-credible co-founder / advisor** (start now — long lead time).
5. Line up 1–2 design-partner conversations → a soft LOI.
6. Incorporate as a **French SAS** (clean cap table; unlocks EU/FR grants).
7. Build a data room: repo + benchmarks + deck + staged roadmap + cap table.

## Proof → money milestones

| Round | Size (illustrative) | Must show |
|-------|---------------------|-----------|
| **Pre-seed** | €500k–€1M | thesis + team-forming + working clic + FPGA demo + perf/watt + partner interest |
| **Seed** | €2M–€6M | taped-out block, 1–2 design partners/LOIs, key silicon hires |
| **Series A** | €15M–€40M | first accelerator silicon sampling, committed customers |

Never ask "€50M for a GPU." Always: "€X to prove milestone Y."

## The money map (Europe — non-dilutive first)

**Non-dilutive / soft money (do these first — they validate and de-risk):**
- 🇫🇷 **Bpifrance** — Bourse French Tech (~€30–90k, easy first step), i-Lab,
  Deeptech grants, **France 2030**.
- 🇪🇺 **EIC Accelerator** — grant up to ~€2.5M + equity up to ~€15M; funds
  strategic deep tech including EU chips. (See outline below.)
- 🇪🇺 **Chips Joint Undertaking / Chips Act**, **EuroHPC**, **Horizon Europe** —
  the exact "AI chips for EU compute" narrative.

**Accelerators (money + credibility + network):**
- **Silicon Catalyst** (semiconductor-specific — ideal), **HAX**, **Hardware Club**.

**Dilutive (once team + LOI + FPGA demo exist):**
- EU deep-tech VCs: Sofinnova, Elaia, Partech, XAnge, EQT Ventures, Lakestar;
  plus semiconductor-industry angels.

## EIC Accelerator — application outline (mapped to our assets)

- **Innovation** — open, vendor-neutral compute stack + efficient EU inference
  accelerator; breaks CUDA lock-in. *Evidence: the clic repo + verified benchmarks.*
- **Excellence / feasibility** — working compiler, GPU backend, FPGA path,
  shuttle-tapeout plan. *Evidence: CI, benchmarks, roadmap.*
- **Market & impact** — EU compute sovereignty; sovereign cloud / HPC / telco /
  defense buyers; energy efficiency of inference.
- **Team & implementation** — founder + planned silicon co-founder + advisors;
  staged, milestone-gated plan.
- **Why EU money** — strategic autonomy in AI compute; a fabless design house is
  a named Chips Act priority.
- **The ask** — grant for the FPGA→first-silicon phase; optional equity for scale-up.

## Honesty (keep this in every conversation)
clic is **not** "faster than CUDA" — speed comes from silicon. It competes on
being open, portable, clean, sovereign, and efficient-per-watt in a chosen
niche. Overclaiming loses credibility with exactly the technical investors and
reviewers we need.
