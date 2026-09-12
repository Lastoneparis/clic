#!/usr/bin/env python3
"""
Compile every example kernel to Metal and assert it produces a kernel.
Runs on plain Python (no GPU) — this is the CI gate.

    python3 tests/test_compile.py
"""
import glob
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)
import clicc  # noqa: E402

fails = 0
for path in sorted(glob.glob(os.path.join(ROOT, "examples", "*.clic"))):
    name = os.path.relpath(path, ROOT)
    try:
        out = clicc.compile_src(clicc.preprocess(path))
        assert "kernel void" in out, "no kernel emitted"
        assert "using namespace metal" in out, "missing header"
        print("ok    %s" % name)
    except Exception as exc:
        print("FAIL  %s  -> %s" % (name, exc))
        fails += 1

print("\n%d passed, %d failed" % (len(glob.glob(os.path.join(ROOT, 'examples', '*.clic'))) - fails, fails))
sys.exit(1 if fails else 0)
