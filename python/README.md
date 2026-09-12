# clic — Python host API

Run a clic GPU kernel from Python in a few lines. The module compiles the
kernel, runs it on the GPU via the Swift runtime, and returns results as plain
Python lists.

```python
import clic

out = clic.run(
    "examples/saxpy.clic", "saxpy",     # source file, kernel name
    grid=[8, 1, 1],                     # total threads
    values={                            # keyed by parameter name, any order
        "n": 8, "a": 3.0,               #   scalars
        "x": [0, 1, 2, 3, 4, 5, 6, 7],  #   buffer: initial data
        "y": [10] * 8,                  #   buffer: initial data
    },
    read=["y"],                         # buffers to read back
)
print(out["y"])   # [10.0, 13.0, 16.0, 19.0, 22.0, 25.0, 28.0, 31.0]
```

- **Scalar vs buffer is inferred** from the kernel signature — you just pass
  values by name.
- A buffer value is either a **list** (initial data) or an **int** (that many
  zeros, for output buffers).
- `read=[...]` names the buffers returned in the result dict.

Run the demo:

```bash
python3 python/example.py
```

Requires the same toolchain as the rest of the repo (Swift + Metal, macOS). The
first call builds the runtime automatically.
