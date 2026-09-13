# Run manifests

A run manifest is the small JSON file that tells the runtime (`clicrun`) how to
run a kernel: which `.metal` to load, the launch dimensions, and how to fill and
check each buffer. One lives in `runs/<name>.json` per example. (The Python API,
[`python/clic.py`](../python/clic.py), builds these for you.)

## Top-level fields

| Field | Type | Meaning |
|-------|------|---------|
| `kernel` | string | the kernel function name inside the `.metal` |
| `metal` | string | path to the compiled `.metal` (relative to the manifest, or absolute) |
| `grid` | `[x,y,z]` | total threads launched |
| `threadgroup` | `[x,y,z]` | threads per threadgroup |
| `iters` | int | timing iterations (averaged) |
| `flops` | number | *(optional)* total FLOPs → prints GFLOP/s |
| `verify` | string | *(optional)* selects a built-in CPU/reference check |
| `image` | object | *(optional)* `{buffer, width, height, path}` → save the buffer as a PNG |
| `bindings` | array | kernel arguments, **in parameter order** |

## Bindings

Each entry binds one kernel parameter. Order must match the kernel signature.

| Field | Applies to | Meaning |
|-------|-----------|---------|
| `name` | all | parameter name (for readability + verify lookup) |
| `kind` | all | `"scalar"` or `"buffer"` |
| `type` | all | `"i32"`, `"u32"`, or `"f32"` |
| `value` | scalar | the scalar value |
| `len` | buffer | element count |
| `init` | buffer | how to fill it (see below) |
| `data` | buffer | *(optional)* inline array of numbers — overrides `init` |
| `dump` | buffer | *(optional)* file path; the buffer's raw bytes are written here after the run (used by the Python API to read results back) |

### `init` modes

| Mode | Fill |
|------|------|
| `random` | uniform `[0, 1)` floats |
| `wide` | uniform `[-1, 2)` — exercises clamps / sign branches |
| `int8` | uniform `[-8, 8)` — integer-valued inputs for INT8 kernels |
| `zero` | all zeros (typical for outputs) |
| `sha256_k` / `sha256_h` | the SHA-256 round / init constants |

## Example

```json
{
  "kernel": "saxpy",
  "metal": "../build/saxpy.metal",
  "grid": [1048576, 1, 1],
  "threadgroup": [256, 1, 1],
  "iters": 200,
  "flops": 2097152,
  "verify": "saxpy",
  "bindings": [
    { "name": "n", "kind": "scalar", "type": "i32", "value": 1048576 },
    { "name": "a", "kind": "scalar", "type": "f32", "value": 2.0 },
    { "name": "x", "kind": "buffer", "type": "f32", "len": 1048576, "init": "random" },
    { "name": "y", "kind": "buffer", "type": "f32", "len": 1048576, "init": "random" }
  ]
}
```

Run it:

```bash
bin/clic run runs/saxpy.json     # builds the .metal if needed, then runs
```

## Adding a `verify`

Built-in reference checks live in `host/clicrun.swift` (search for
`verify ==`). To check a new kernel, add a branch computing the expected result
on the CPU and comparing it to the output buffer — see the existing `saxpy` or
`gemm` branch as a template. See also [TUTORIAL.md](TUTORIAL.md).
