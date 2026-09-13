#!/usr/bin/env python3
"""
clicc — the clic compiler.  clic source -> Metal Shading Language (MSL).

clic is a small, CUDA-like compute language. A `kernel` is launched over a
grid of threads; `tid.x/.y/.z` is the global thread id (like CUDA's
blockIdx*blockDim+threadIdx, but with no block bookkeeping to get wrong).

v0.1 backend: Apple Metal (this Mac's GPU). Same language will later target
the FPGA soft-GPU over USB, and eventually real silicon.

Usage:
    python3 clicc.py examples/gemm.clic -o build/gemm.metal
    python3 clicc.py examples/gemm.clic          # prints MSL to stdout
    python3 clicc.py examples/gemm.clic --emit-clic-ast   # debug
"""
import sys
import os
import re
import argparse

# --------------------------------------------------------------------------
# Lexer
# --------------------------------------------------------------------------
KEYWORDS = {'kernel', 'fn', 'let', 'var', 'if', 'else', 'for', 'while',
            'break', 'continue', 'array', 'threadgroup',
            'buffer', 'return', 'i32', 'f32', 'f16', 'u32', 'i8', 'u8', 'f32x4',
            'bool', 'true', 'false'}

# Order matters: comments/whitespace before operators, floats before ints.
TOKEN_SPEC = [
    ('COMMENT', r'//[^\n]*'),
    ('WS',      r'[ \t\r\n]+'),
    ('FLOAT',   r'\d+\.\d+([eE][+-]?\d+)?|\d+[eE][+-]?\d+'),
    ('INT',     r'\d+'),
    ('ID',      r'[A-Za-z_][A-Za-z0-9_]*'),
    ('OP',      r'<<=|>>=|<<|>>|->|<=|>=|==|!=|&&|\|\||\+=|-=|\*=|/=|%=|&=|\^=|\|=|[-+*/%<>=!.,;:?()\[\]{}&|^~]'),
]
_MASTER = re.compile('|'.join('(?P<%s>%s)' % (n, p) for n, p in TOKEN_SPEC))


class Tok:
    __slots__ = ('kind', 'val', 'pos')

    def __init__(self, kind, val, pos):
        self.kind, self.val, self.pos = kind, val, pos

    def __repr__(self):
        return '%s(%r)' % (self.kind, self.val)


def lex(src):
    toks = []
    i = 0
    while i < len(src):
        m = _MASTER.match(src, i)
        if not m:
            raise SyntaxError('clic: unexpected char %r at %d' % (src[i], i))
        kind, val = m.lastgroup, m.group()
        i = m.end()
        if kind in ('WS', 'COMMENT'):
            continue
        if kind == 'ID' and val in KEYWORDS:
            kind = val            # keyword token: kind == its own text
        elif kind == 'OP':
            kind = val            # punctuation token: kind == its own text
        toks.append(Tok(kind, val, m.start()))
    toks.append(Tok('EOF', '', len(src)))
    return toks


# --------------------------------------------------------------------------
# Parser  (recursive descent -> tuple AST)
# --------------------------------------------------------------------------
_BINOPS = [
    ['||'],
    ['&&'],
    ['|'],
    ['^'],
    ['&'],
    ['==', '!='],
    ['<', '<=', '>', '>='],
    ['<<', '>>'],
    ['+', '-'],
    ['*', '/', '%'],
]


class Parser:
    def __init__(self, toks):
        self.toks = toks
        self.i = 0

    def peek(self, k=0):
        return self.toks[self.i + k]

    def next(self):
        t = self.toks[self.i]
        self.i += 1
        return t

    def at(self, kind):
        return self.peek().kind == kind

    def eat(self, kind):
        t = self.peek()
        if t.kind != kind:
            self.err('expected %r but got %s(%r)' % (kind, t.kind, t.val))
        return self.next()

    def err(self, msg):
        raise SyntaxError('clic parse error near pos %d: %s'
                          % (self.peek().pos, msg))

    # -- top level --
    def parse_program(self):
        decls = []
        while not self.at('EOF'):
            if self.at('fn'):
                decls.append(self.parse_fn())
            else:
                decls.append(self.parse_kernel())
        return decls

    def parse_fn(self):
        self.eat('fn')
        name = self.eat('ID').val
        self.eat('(')
        params = []
        if not self.at(')'):
            params.append(self.parse_param())
            while self.at(','):
                self.next()
                params.append(self.parse_param())
        self.eat(')')
        self.eat('->')
        ret = self.parse_type()
        body = self.parse_block()
        return ('fn', name, params, ret, body)

    def parse_kernel(self):
        self.eat('kernel')
        name = self.eat('ID').val
        self.eat('(')
        params = []
        if not self.at(')'):
            params.append(self.parse_param())
            while self.at(','):
                self.next()
                params.append(self.parse_param())
        self.eat(')')
        body = self.parse_block()
        return ('kernel', name, params, body)

    def parse_param(self):
        name = self.eat('ID').val
        self.eat(':')
        return (name, self.parse_type())

    def parse_type(self):
        t = self.peek()
        if t.kind == 'buffer':
            self.next()
            self.eat('<')
            elem = self.parse_type()
            self.eat('>')
            return ('buffer', elem)
        if t.kind == 'threadgroup':
            self.next()
            inner = self.parse_type()
            if inner[0] != 'array':
                self.err('threadgroup must qualify an array type')
            return ('array', inner[1], inner[2], 'threadgroup')
        if t.kind == 'array':
            self.next()
            self.eat('<')
            elem = self.parse_type()
            self.eat(',')
            size = int(self.eat('INT').val)
            self.eat('>')
            return ('array', elem, size, 'thread')
        if t.kind in ('i32', 'f32', 'f16', 'u32', 'i8', 'u8', 'f32x4', 'bool'):
            self.next()
            return ('scalar', t.kind)
        self.err('expected a type (i32/f32/u32/bool/buffer<..>/array<T,N>)')

    # -- statements --
    def parse_block(self):
        self.eat('{')
        stmts = []
        while not self.at('}'):
            stmts.append(self.parse_stmt())
        self.eat('}')
        return ('block', stmts)

    def parse_stmt(self):
        k = self.peek().kind
        if k in ('let', 'var'):
            return self.parse_decl()
        if k == 'if':
            return self.parse_if()
        if k == 'for':
            return self.parse_for()
        if k == 'while':
            return self.parse_while()
        if k == 'break':
            self.next(); self.eat(';'); return ('break',)
        if k == 'continue':
            self.next(); self.eat(';'); return ('continue',)
        if k == 'return':
            self.next()
            if self.at(';'):
                self.next()
                return ('return', None)
            e = self.parse_expr()
            self.eat(';')
            return ('return', e)
        if k == '{':
            return self.parse_block()
        e = self.parse_expr()
        if self.peek().kind in _ASSIGN_OPS:
            op = self.next().kind
            rhs = self.parse_expr()
            self.eat(';')
            return ('assign', e, op, rhs)
        self.eat(';')
        return ('exprstmt', e)

    def parse_while(self):
        self.eat('while')
        self.eat('(')
        cond = self.parse_expr()
        self.eat(')')
        return ('while', cond, self.parse_block())

    def parse_decl(self):
        kw = self.next().kind          # let | var
        name = self.eat('ID').val
        ty = None
        if self.at(':'):
            self.next()
            ty = self.parse_type()
        e = None
        if self.at('='):               # initializer optional (e.g. array decls)
            self.next()
            e = self.parse_expr()
        self.eat(';')
        return ('decl', kw, name, ty, e)

    def parse_if(self):
        self.eat('if')
        self.eat('(')
        cond = self.parse_expr()
        self.eat(')')
        then = self.parse_block()
        els = None
        if self.at('else'):
            self.next()
            els = self.parse_if() if self.at('if') else self.parse_block()
        return ('if', cond, then, els)

    def parse_for(self):
        self.eat('for')
        self.eat('(')
        init = self.parse_decl()       # consumes trailing ';'
        cond = self.parse_expr()
        self.eat(';')
        lhs = self.parse_expr()
        op = self.next().kind
        if op not in _ASSIGN_OPS:
            self.err('expected an assignment operator in for-step')
        rhs = self.parse_expr()
        step = ('assign', lhs, op, rhs)
        self.eat(')')
        body = self.parse_block()
        return ('for', init, cond, step, body)

    # -- expressions --
    def parse_expr(self):
        cond = self.parse_bin(0)
        if self.at('?'):                       # ternary: cond ? a : b (right-assoc)
            self.next()
            then_e = self.parse_expr()
            self.eat(':')
            else_e = self.parse_expr()
            return ('ternary', cond, then_e, else_e)
        return cond

    def parse_bin(self, level):
        if level == len(_BINOPS):
            return self.parse_unary()
        left = self.parse_bin(level + 1)
        while self.peek().kind in _BINOPS[level]:
            op = self.next().kind
            right = self.parse_bin(level + 1)
            left = ('bin', op, left, right)
        return left

    def parse_unary(self):
        if self.peek().kind in ('-', '!', '~'):
            op = self.next().kind
            return ('un', op, self.parse_unary())
        return self.parse_postfix()

    def parse_postfix(self):
        e = self.parse_primary()
        while True:
            k = self.peek().kind
            if k == '[':
                self.next()
                idx = self.parse_expr()
                self.eat(']')
                e = ('index', e, idx)
            elif k == '.':
                self.next()
                field = self.eat('ID').val
                e = ('member', e, field)
            elif k == '(':
                self.next()
                args = []
                if not self.at(')'):
                    args.append(self.parse_expr())
                    while self.at(','):
                        self.next()
                        args.append(self.parse_expr())
                self.eat(')')
                e = ('call', e, args)
            else:
                break
        return e

    def parse_primary(self):
        t = self.peek()
        if t.kind == 'INT':
            self.next()
            return ('int', int(t.val))
        if t.kind == 'FLOAT':
            self.next()
            return ('float', float(t.val))
        if t.kind in ('true', 'false'):
            self.next()
            return ('bool', t.kind == 'true')
        if t.kind == 'ID':
            self.next()
            return ('id', t.val)
        if t.kind == '(':
            self.next()
            e = self.parse_expr()
            self.eat(')')
            return e
        self.err('unexpected %s(%r)' % (t.kind, t.val))


# --------------------------------------------------------------------------
# Code generation:  clic AST -> Metal Shading Language
# --------------------------------------------------------------------------
_TYMAP = {'i32': 'int', 'u32': 'uint', 'f32': 'float', 'f16': 'half',
          'i8': 'char', 'u8': 'uchar', 'f32x4': 'float4', 'bool': 'bool'}
# builtin functions passed straight through to MSL
_BUILTINS = {'float', 'int', 'uint', 'half', 'char', 'uchar', 'float4', 'dot',
             'min', 'max', 'abs', 'sqrt', 'exp', 'log', 'pow', 'fma', 'floor',
             'ceil', 'tanh', 'clamp', 'round',
             # math stdlib (all genuine Metal functions)
             'rsqrt', 'sin', 'cos', 'tan', 'atan2', 'exp2', 'log2',
             'fract', 'sign', 'trunc'}
_USER_FNS = set()      # names of user-defined fns (populated per compile)
_ASSIGN_OPS = {'=', '+=', '-=', '*=', '/=', '%=', '&=', '|=', '^=', '<<=', '>>='}


def _cscalar(ty):
    if ty[0] == 'scalar':
        return _TYMAP[ty[1]]
    return 'device ' + _TYMAP[ty[1][1]] + '*'


def gen_expr(e):
    t = e[0]
    if t == 'int':
        return str(e[1])
    if t == 'float':
        return repr(e[1]) + 'f'          # 2.0 -> 2.0f
    if t == 'bool':
        return 'true' if e[1] else 'false'
    if t == 'id':
        return e[1]
    if t == 'member':
        base, field = e[1], e[2]
        if base == ('id', 'tid'):        # tid.x  -> global thread id
            return 'int(gid.%s)' % field
        if base == ('id', 'ltid'):       # ltid.x -> thread id within threadgroup
            return 'int(ltid.%s)' % field
        if base == ('id', 'bid'):        # bid.x  -> threadgroup id in grid
            return 'int(bid.%s)' % field
        return '%s.%s' % (gen_expr(base), field)
    if t == 'index':
        return '%s[%s]' % (gen_expr(e[1]), gen_expr(e[2]))
    if t == 'call':
        callee, args = e[1], e[2]
        name = callee[1] if callee[0] == 'id' else gen_expr(callee)
        if callee[0] == 'id':
            if name == 'rotr':                # rotate-right on 32-bit: rotr(x, n)
                x, n = gen_expr(args[0]), gen_expr(args[1])
                return '(((%s) >> (%s)) | ((%s) << (32 - (%s))))' % (x, n, x, n)
            if name == 'barrier':             # threadgroup synchronization
                return 'threadgroup_barrier(mem_flags::mem_threadgroup)'
            if name not in _BUILTINS and name not in _USER_FNS:
                raise SyntaxError('clic: unknown function %r' % name)
        return '%s(%s)' % (name, ', '.join(gen_expr(a) for a in args))
    if t == 'un':
        return '(%s%s)' % (e[1], gen_expr(e[2]))
    if t == 'bin':
        return '(%s %s %s)' % (gen_expr(e[2]), e[1], gen_expr(e[3]))
    if t == 'ternary':
        return '(%s ? %s : %s)' % (gen_expr(e[1]), gen_expr(e[2]), gen_expr(e[3]))
    raise SyntaxError('clic: bad expr node %r' % (t,))


def gen_stmt(s, ind):
    pad = '    ' * ind
    t = s[0]
    if t == 'block':
        return gen_block(s, ind)
    if t == 'decl':
        _, kw, name, ty, e = s
        if ty is not None and ty[0] == 'array':          # local array: T name[N];
            elem = _TYMAP[ty[1][1]]
            storage = ty[3] if len(ty) > 3 else 'thread'
            prefix = 'threadgroup ' if storage == 'threadgroup' else ''
            return '%s%s%s %s[%d];' % (pad, prefix, elem, name, ty[2])
        cty = 'auto' if ty is None else _cscalar(ty)
        if e is None:
            return '%s%s %s;' % (pad, cty, name)
        return '%s%s %s = %s;' % (pad, cty, name, gen_expr(e))
    if t == 'assign':
        return '%s%s %s %s;' % (pad, gen_expr(s[1]), s[2], gen_expr(s[3]))
    if t == 'break':
        return '%sbreak;' % pad
    if t == 'continue':
        return '%scontinue;' % pad
    if t == 'while':
        return '%swhile (%s) {\n%s\n%s}' % (pad, gen_expr(s[1]),
                                            gen_block(s[2], ind + 1), pad)
    if t == 'exprstmt':
        return '%s%s;' % (pad, gen_expr(s[1]))
    if t == 'return':
        if s[1] is None:
            return '%sreturn;' % pad
        return '%sreturn %s;' % (pad, gen_expr(s[1]))
    if t == 'if':
        _, cond, then, els = s
        out = '%sif (%s) {\n%s\n%s}' % (pad, gen_expr(cond),
                                        gen_block(then, ind + 1), pad)
        if els is not None:
            if els[0] == 'if':
                out += '\n%selse %s' % (pad, gen_stmt(els, ind).lstrip())
            else:
                out += '\n%selse {\n%s\n%s}' % (pad, gen_block(els, ind + 1), pad)
        return out
    if t == 'for':
        _, init, cond, step, body = s
        init_s = gen_stmt(init, 0).strip().rstrip(';')
        step_s = '%s %s %s' % (gen_expr(step[1]), step[2], gen_expr(step[3]))
        return '%sfor (%s; %s; %s) {\n%s\n%s}' % (
            pad, init_s, gen_expr(cond), step_s, gen_block(body, ind + 1), pad)
    raise SyntaxError('clic: bad stmt node %r' % (t,))


def gen_block(block, ind):
    return '\n'.join(gen_stmt(s, ind) for s in block[1])


def gen_kernel(k):
    _, name, params, body = k
    sig = []
    for idx, (pname, ty) in enumerate(params):
        if ty[0] == 'scalar':
            sig.append('    constant %s& %s [[buffer(%d)]]'
                       % (_TYMAP[ty[1]], pname, idx))
        else:
            sig.append('    device %s* %s [[buffer(%d)]]'
                       % (_TYMAP[ty[1][1]], pname, idx))
    sig.append('    uint3 gid [[thread_position_in_grid]]')
    sig.append('    uint3 ltid [[thread_position_in_threadgroup]]')
    sig.append('    uint3 bid [[threadgroup_position_in_grid]]')
    return 'kernel void %s(\n%s) {\n%s\n}' % (name, ',\n'.join(sig),
                                              gen_block(body, 1))


def _fn_ptype(ty):
    if ty[0] == 'scalar':
        return _TYMAP[ty[1]]
    if ty[0] == 'buffer':
        return 'device %s*' % _TYMAP[ty[1][1]]
    raise SyntaxError('clic: unsupported fn parameter type %r' % (ty,))


def gen_fn_proto(f):
    _, name, params, ret, _body = f
    ps = ['%s %s' % (_fn_ptype(ty), pn) for pn, ty in params]
    return '%s %s(%s);' % (_TYMAP[ret[1]], name, ', '.join(ps))


def gen_fn(f):
    _, name, params, ret, body = f
    ps = ['%s %s' % (_fn_ptype(ty), pn) for pn, ty in params]
    return '%s %s(%s) {\n%s\n}' % (_TYMAP[ret[1]], name, ', '.join(ps),
                                   gen_block(body, 1))


_HEADER = '#include <metal_stdlib>\nusing namespace metal;\n'


def compile_src(src):
    global _USER_FNS
    decls = Parser(lex(src)).parse_program()
    fns = [d for d in decls if d[0] == 'fn']
    kernels = [d for d in decls if d[0] == 'kernel']
    _USER_FNS = set(f[1] for f in fns)
    parts = [_HEADER]
    if fns:
        parts.append('\n'.join(gen_fn_proto(f) for f in fns))      # forward decls
        parts.append('\n\n'.join(gen_fn(f) for f in fns))
    if kernels:
        parts.append('\n\n'.join(gen_kernel(k) for k in kernels))
    return '\n\n'.join(parts) + '\n'


_INCLUDE = re.compile(r'\s*include\s+"([^"]+)"\s*$')


def preprocess(path, seen=None):
    """Resolve `include "file"` directives (relative to the including file)."""
    seen = set() if seen is None else seen
    real = os.path.realpath(path)
    if real in seen:
        return ''
    seen.add(real)
    base = os.path.dirname(path)
    out = []
    with open(path) as f:
        for line in f:
            m = _INCLUDE.match(line)
            if m:
                out.append(preprocess(os.path.join(base, m.group(1)), seen))
            else:
                out.append(line)
    return ''.join(out)


def main():
    ap = argparse.ArgumentParser(description='clic -> Metal compiler')
    ap.add_argument('src')
    ap.add_argument('-o', '--out')
    args = ap.parse_args()
    src = preprocess(args.src)
    out = compile_src(src)
    if args.out:
        with open(args.out, 'w') as f:
            f.write(out)
        print('clicc: wrote %s' % args.out)
    else:
        sys.stdout.write(out)


if __name__ == '__main__':
    main()
