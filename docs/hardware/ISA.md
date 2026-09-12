# clic-A1 ISA v0.1 — the accelerator instruction set

The narrow waist between the **clic compiler** and the **silicon**. The compiler
lowers clic kernels to this ISA; the hardware executes it. Keeping the ISA small
and explicit is what lets one language target GPU today and clic-A1 later.

**Status:** draft v0.1 — the contract to iterate with a silicon partner.

## Model

clic-A1 is a **tiled dataflow** accelerator, not a general CPU. The host loads
weights/activations into on-chip SRAM, then issues a short program of macro-ops
that stream tiles through the MAC array. A **RISC-V** core (gen-2) or an FSM
sequencer (gen-1) runs this program.

## Register / memory state

- `SRAM_W` — weight buffer (on-chip)
- `SRAM_A` — activation buffer (on-chip)
- `ACC`    — accumulator bank (wide, INT32/FP)
- scalar config registers: tile dims (M, N, K), dtype, strides, base addresses

## Instruction classes (v0.1)

| Class | Op | Meaning |
|-------|----|---------|
| **Config** | `SET.MODE dtype` | INT8 / INT4 / (gen-2) FP16 / BF16 |
| | `SET.TILE m,n,k` | tile dimensions for the next op |
| **Data move** | `LD.W addr,len` | host/DRAM → `SRAM_W` |
| | `LD.A addr,len` | host/DRAM → `SRAM_A` |
| | `ST.O addr,len` | `ACC`/SRAM → host/DRAM |
| **Compute** | `MMA` | matrix-multiply-accumulate: `ACC += SRAM_W · SRAM_A` (one tile) |
| | `MMA.RELU`, `MMA.GELU` | fused MAC + activation (clic `linear_relu` pattern) |
| **Vector** | `VEC.ACT fn` | apply activation over a buffer (relu/gelu/sigmoid) |
| | `VEC.RED op` | row reduction (sum/max) — softmax/layernorm building block |
| **Control** | `LOOP n { ... }` | hardware loop over tiles |
| | `SYNC` | barrier: wait for compute/DMA to drain |
| | `HALT` | end of program |

## Example: a tiled GEMM (what `gemm_tiled.clic` lowers to)

```
SET.MODE INT8
SET.TILE 16,16,16
LOOP kt {                 ; over K-tiles
    LD.W  w_base + kt*..   ; stage weight tile -> SRAM_W
    LD.A  a_base + kt*..   ; stage activation tile -> SRAM_A
    MMA                    ; ACC += W·A  (systolic array)
}
VEC.ACT relu              ; optional fused activation
ST.O  c_base              ; write result
HALT
```

## Datatype encoding

`SET.MODE` selects the MAC datapath: **INT8** (baseline), **INT4** (two ops
packed per MAC — the efficiency mode), and reserved encodings for **FP16 /
BF16** (gen-2 hardware; the opcodes exist now so software is forward-compatible).

## Why an explicit macro-ISA (not a GPU ISA)

- **MMA as a first-class op** matches the systolic array and keeps control
  overhead near zero — the opposite of a scalar-thread GPU ISA.
- **Explicit `LD`/`ST`** make data movement (the real energy cost) visible to the
  compiler, so it can schedule reuse — exactly what the tiled clic kernel does.
- **Small and stable** → easy to implement in RTL, easy to verify, and a clean
  target for the clic backend.

## Compiler path

```
clic kernel ──► clic IR ──► clic-A1 backend ──► clic-A1 ISA program (binary)
                     └─────► Metal backend (today)
```

The clic IR (roadmap item) is the shared middle; the clic-A1 backend is the new
code generator that emits the ISA above.
