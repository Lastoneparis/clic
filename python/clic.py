"""
clic — Python host API.

Run a clic GPU kernel from Python in a few lines. Compiles the kernel with the
clic compiler, executes it on this Mac's GPU via the Swift runtime, and reads
results back as plain Python lists — no manual manifests, no Metal boilerplate.

    import clic
    out = clic.run(
        "examples/saxpy.clic", "saxpy",
        grid=[8, 1, 1],
        values={"n": 8, "a": 3.0, "x": [0,1,2,3,4,5,6,7], "y": [10]*8},
        read=["y"],
    )
    print(out["y"])          # -> [10.0, 13.0, 16.0, ...]  (a*x + y)

Scalar vs buffer is inferred from the kernel signature, so `values` is keyed by
parameter name in any order. A buffer value may be a list (initial data) or an
int (that many zeros, for outputs).
"""
import os
import sys
import json
import struct
import tempfile
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)
import clicc  # noqa: E402

BUILD = os.path.join(ROOT, "build")
CLICRUN = os.path.join(BUILD, "clicrun")
_FMT = {"f32": "f", "u32": "I", "i32": "i"}


def _ensure_runtime():
    os.makedirs(BUILD, exist_ok=True)
    if not os.path.exists(CLICRUN):
        subprocess.run(
            ["swiftc", "-O", os.path.join(ROOT, "host", "clicrun.swift"), "-o", CLICRUN],
            check=True)


def _kernel_params(src_path, kernel):
    decls = clicc.Parser(clicc.lex(clicc.preprocess(src_path))).parse_program()
    for d in decls:
        if d[0] == "kernel" and d[1] == kernel:
            return d[2]                      # [(name, type), ...] in signature order
    raise ValueError("kernel %r not found in %s" % (kernel, src_path))


def run(src, kernel, grid, values, read=(), threadgroup=None, iters=1):
    """Compile + run a clic kernel on the GPU; return {name: [values]} for `read`."""
    _ensure_runtime()
    src_path = src if os.path.isabs(src) else os.path.join(ROOT, src)
    metal = os.path.join(BUILD, kernel + ".metal")
    with open(metal, "w") as f:
        f.write(clicc.compile_src(clicc.preprocess(src_path)))

    params = _kernel_params(src_path, kernel)
    if threadgroup is None:
        threadgroup = [max(1, min(256, grid[0])), 1, 1]
    tmp = tempfile.mkdtemp(prefix="clic_")
    bindings, dumps = [], {}

    for name, ty in params:
        if name not in values:
            raise ValueError("missing value for parameter %r" % name)
        val = values[name]
        if ty[0] == "scalar":
            bindings.append({"name": name, "kind": "scalar", "type": ty[1], "value": val})
        else:                                # buffer<elem>
            elem = ty[1][1]
            b = {"name": name, "kind": "buffer", "type": elem}
            if isinstance(val, int):         # an int length -> that many zeros
                b["len"], b["init"] = val, "zero"
            else:                            # a sequence -> initial data
                data = [float(v) for v in val]
                b["len"], b["data"] = len(data), data
            if name in read:
                p = os.path.join(tmp, name + ".bin")
                b["dump"] = p
                dumps[name] = (p, elem, b["len"])
            bindings.append(b)

    manifest = {"kernel": kernel, "metal": metal, "grid": grid,
                "threadgroup": threadgroup, "iters": iters, "bindings": bindings}
    mpath = os.path.join(tmp, "run.json")
    with open(mpath, "w") as f:
        json.dump(manifest, f)
    subprocess.run([CLICRUN, mpath], check=True, stdout=subprocess.DEVNULL)

    out = {}
    for name, (p, elem, ln) in dumps.items():
        with open(p, "rb") as f:
            raw = f.read()
        out[name] = list(struct.unpack("<%d%s" % (ln, _FMT[elem]), raw))
    return out
