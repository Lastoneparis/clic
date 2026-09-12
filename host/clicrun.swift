// clicrun — the clic Metal runtime / benchmark host.
//
// Reads a JSON run-manifest, compiles the clic-generated .metal at runtime,
// allocates + fills buffers (f32 or u32), runs the kernel on this Mac's GPU,
// verifies the result against a CPU/OS reference, and reports throughput.
//
// Backend #1: clic on Apple Metal. The same kernels + manifests will later be
// driven by the FPGA-over-USB backend.
//
// Build:  swiftc -O host/clicrun.swift -o build/clicrun
// Run:    ./build/clicrun runs/sha256.json

import Foundation
import Metal
import QuartzCore
import CryptoKit
import CoreGraphics
import ImageIO

func fail(_ m: String) -> Never {
    FileHandle.standardError.write(("clicrun: " + m + "\n").data(using: .utf8)!)
    exit(1)
}

struct Binding {
    let name: String
    let kind: String      // "scalar" | "buffer"
    let type: String      // "i32" | "f32" | "u32"
    let value: Double     // scalar value
    let len: Int          // buffer element count
    let initMode: String  // "random" | "zero" | "sha256_k" | "sha256_h"
    let data: [Float]?    // inline f32 contents (overrides initMode)
    let dump: String?     // after the run, write this buffer's raw bytes here
}

func savePNG(buffer: MTLBuffer, width: Int, height: Int, path: String) {
    let cs = CGColorSpaceCreateDeviceRGB()
    let info = CGImageAlphaInfo.noneSkipLast.rawValue      // memory bytes R,G,B,x
    guard let ctx = CGContext(data: buffer.contents(), width: width, height: height,
                              bitsPerComponent: 8, bytesPerRow: width * 4,
                              space: cs, bitmapInfo: info),
          let img = ctx.makeImage(),
          let dest = CGImageDestinationCreateWithURL(
              URL(fileURLWithPath: path) as CFURL, "public.png" as CFString, 1, nil)
    else { return }
    CGImageDestinationAddImage(dest, img, nil)
    CGImageDestinationFinalize(dest)
}

// ---- SHA-256 constants (used by init modes) -------------------------------
let SHA_K: [UInt32] = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2]
let SHA_H: [UInt32] = [
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]

// ---- parse args + manifest ------------------------------------------------
guard CommandLine.arguments.count >= 2 else { fail("usage: clicrun <manifest.json>") }
let manifestURL = URL(fileURLWithPath: CommandLine.arguments[1])
let baseDir = manifestURL.deletingLastPathComponent()
guard let mdata = try? Data(contentsOf: manifestURL),
      let json = (try? JSONSerialization.jsonObject(with: mdata)) as? [String: Any]
else { fail("cannot read manifest \(manifestURL.path)") }

let kernelName = json["kernel"] as! String
let metalRel = json["metal"] as! String
let metalURL = metalRel.hasPrefix("/") ? URL(fileURLWithPath: metalRel) : baseDir.appendingPathComponent(metalRel)
guard let metalSrc = try? String(contentsOf: metalURL, encoding: .utf8)
else { fail("cannot read metal \(metalURL.path)") }

let grid = json["grid"] as! [Int]
let tg = json["threadgroup"] as! [Int]
let iters = (json["iters"] as? Int) ?? 50
let flops = ((json["flops"] as? NSNumber)?.doubleValue) ?? 0
let verify = json["verify"] as? String
let gridTotal = grid.reduce(1, *)

var bindings: [Binding] = []
for b in (json["bindings"] as! [[String: Any]]) {
    bindings.append(Binding(
        name: b["name"] as! String,
        kind: b["kind"] as! String,
        type: (b["type"] as? String) ?? "f32",
        value: ((b["value"] as? NSNumber)?.doubleValue) ?? 0,
        len: (b["len"] as? Int) ?? 0,
        initMode: (b["init"] as? String) ?? "zero",
        data: (b["data"] as? [Any])?.compactMap { ($0 as? NSNumber)?.floatValue },
        dump: b["dump"] as? String))
}

// ---- Metal setup ----------------------------------------------------------
guard let device = MTLCreateSystemDefaultDevice() else { fail("no Metal device") }
guard let queue = device.makeCommandQueue() else { fail("no command queue") }
let lib: MTLLibrary
do { lib = try device.makeLibrary(source: metalSrc, options: nil) }
catch { fail("Metal compile error: \(error)") }
guard let fn = lib.makeFunction(name: kernelName) else { fail("kernel \(kernelName) not found") }
let pipe: MTLComputePipelineState
do { pipe = try device.makeComputePipelineState(function: fn) }
catch { fail("pipeline error: \(error)") }

// ---- allocate + fill buffers (type-aware) ---------------------------------
var gpuBuffers = [MTLBuffer?](repeating: nil, count: bindings.count)
var hostF = [String: [Float]]()     // initial data for f32 buffers
var hostU = [String: [UInt32]]()    // initial data for u32 buffers
var rng = SystemRandomNumberGenerator()

for (idx, b) in bindings.enumerated() where b.kind == "buffer" {
    let bytes = b.len * 4
    guard let buf = device.makeBuffer(length: bytes, options: .storageModeShared)
    else { fail("buffer alloc failed for \(b.name)") }
    if let d = b.data {                       // inline data (e.g. rasterizer geometry)
        var arr = d
        if arr.count < b.len { arr += [Float](repeating: 0, count: b.len - arr.count) }
        hostF[b.name] = arr
        _ = arr.withUnsafeBytes { memcpy(buf.contents(), $0.baseAddress!, bytes) }
        gpuBuffers[idx] = buf
        continue
    }
    switch b.initMode {
    case "random":
        var arr = [Float](repeating: 0, count: b.len)
        for i in 0..<b.len { arr[i] = Float.random(in: 0..<1, using: &rng) }
        hostF[b.name] = arr
        _ = arr.withUnsafeBytes { memcpy(buf.contents(), $0.baseAddress!, bytes) }
    case "wide":                                   // [-1, 2): exercises clamps/branches
        var arr = [Float](repeating: 0, count: b.len)
        for i in 0..<b.len { arr[i] = Float.random(in: -1..<2, using: &rng) }
        hostF[b.name] = arr
        _ = arr.withUnsafeBytes { memcpy(buf.contents(), $0.baseAddress!, bytes) }
    case "sha256_k":
        hostU[b.name] = SHA_K
        _ = SHA_K.withUnsafeBytes { memcpy(buf.contents(), $0.baseAddress!, bytes) }
    case "sha256_h":
        hostU[b.name] = SHA_H
        _ = SHA_H.withUnsafeBytes { memcpy(buf.contents(), $0.baseAddress!, bytes) }
    default: // zero
        if b.type == "u32" { hostU[b.name] = [UInt32](repeating: 0, count: b.len) }
        else { hostF[b.name] = [Float](repeating: 0, count: b.len) }
        memset(buf.contents(), 0, bytes)
    }
    gpuBuffers[idx] = buf
}

func resetBuffers() {
    for (idx, b) in bindings.enumerated() where b.kind == "buffer" {
        guard let buf = gpuBuffers[idx] else { continue }
        let bytes = b.len * 4
        if let hf = hostF[b.name] { _ = hf.withUnsafeBytes { memcpy(buf.contents(), $0.baseAddress!, bytes) } }
        else if let hu = hostU[b.name] { _ = hu.withUnsafeBytes { memcpy(buf.contents(), $0.baseAddress!, bytes) } }
        else { memset(buf.contents(), 0, bytes) }
    }
}

func scalar(_ name: String) -> Double { bindings.first { $0.name == name }!.value }
func bufF(_ name: String) -> UnsafeMutablePointer<Float> {
    let i = bindings.firstIndex { $0.name == name }!
    return gpuBuffers[i]!.contents().bindMemory(to: Float.self, capacity: bindings[i].len)
}
func bufU(_ name: String) -> UnsafeMutablePointer<UInt32> {
    let i = bindings.firstIndex { $0.name == name }!
    return gpuBuffers[i]!.contents().bindMemory(to: UInt32.self, capacity: bindings[i].len)
}

func dispatchOnce() {
    let cb = queue.makeCommandBuffer()!
    let enc = cb.makeComputeCommandEncoder()!
    enc.setComputePipelineState(pipe)
    for (idx, b) in bindings.enumerated() {
        if b.kind == "scalar" {
            switch b.type {
            case "f32": var v = Float(b.value); enc.setBytes(&v, length: 4, index: idx)
            case "u32": var v = UInt32(truncatingIfNeeded: Int(b.value)); enc.setBytes(&v, length: 4, index: idx)
            default:    var v = Int32(b.value); enc.setBytes(&v, length: 4, index: idx)
            }
        } else {
            enc.setBuffer(gpuBuffers[idx], offset: 0, index: idx)
        }
    }
    let g = MTLSize(width: grid[0], height: grid.count > 1 ? grid[1] : 1, depth: grid.count > 2 ? grid[2] : 1)
    let t = MTLSize(width: tg[0], height: tg.count > 1 ? tg[1] : 1, depth: tg.count > 2 ? tg[2] : 1)
    enc.dispatchThreads(g, threadsPerThreadgroup: t)
    enc.endEncoding()
    cb.commit()
    cb.waitUntilCompleted()
}

// ---- correctness (run once on fresh data, compare to reference) -----------
resetBuffers()
dispatchOnce()
var verifyMsg = "no reference"
if verify == "saxpy" {
    let a = Float(scalar("a")); let n = Int(scalar("n"))
    let x = hostF["x"]!; let y0 = hostF["y"]!; let y = bufF("y")
    var maxRel = 0.0
    for i in stride(from: 0, to: n, by: max(1, n / 4096)) {
        let ref = a * x[i] + y0[i]
        if ref != 0 { maxRel = max(maxRel, Double(abs(y[i] - ref) / abs(ref))) }
    }
    verifyMsg = (maxRel <= 1e-4 ? "PASS" : "FAIL") + String(format: " (max rel err %.2e)", maxRel)
} else if verify == "gemm" {
    let M = Int(scalar("M")); let N = Int(scalar("N")); let K = Int(scalar("K"))
    let A = hostF["A"]!; let B = hostF["B"]!; let C = bufF("C")
    var maxRel = 0.0
    for _ in 0..<24 {
        let r = Int.random(in: 0..<M), c = Int.random(in: 0..<N)
        var acc: Float = 0
        for k in 0..<K { acc += A[r * K + k] * B[k * N + c] }
        if acc != 0 { maxRel = max(maxRel, Double(abs(C[r * N + c] - acc) / abs(acc))) }
    }
    verifyMsg = (maxRel <= 1e-3 ? "PASS" : "FAIL") + String(format: " (max rel err %.2e, 24 elems)", maxRel)
} else if verify == "linear_relu" {
    let M = Int(scalar("M")); let N = Int(scalar("N")); let K = Int(scalar("K"))
    let A = hostF["A"]!; let B = hostF["B"]!; let bias = hostF["bias"]!; let C = bufF("C")
    var maxRel = 0.0
    for _ in 0..<24 {
        let r = Int.random(in: 0..<M), c = Int.random(in: 0..<N)
        var acc = bias[c]
        for k in 0..<K { acc += A[r * K + k] * B[k * N + c] }
        let ref = max(0, acc)                       // relu
        if ref != 0 { maxRel = max(maxRel, Double(abs(C[r * N + c] - ref) / abs(ref))) }
    }
    verifyMsg = (maxRel <= 1e-3 ? "PASS" : "FAIL") + String(format: " (max rel err %.2e, relu+bias+matmul)", maxRel)
} else if verify == "linear" {
    let M = Int(scalar("M")); let N = Int(scalar("N")); let K = Int(scalar("K"))
    let A = hostF["A"]!; let B = hostF["B"]!; let bias = hostF["bias"]!; let C = bufF("C")
    var maxRel = 0.0
    for _ in 0..<24 {
        let r = Int.random(in: 0..<M), c = Int.random(in: 0..<N)
        var acc = bias[c]
        for k in 0..<K { acc += A[r * K + k] * B[k * N + c] }
        if acc != 0 { maxRel = max(maxRel, Double(abs(C[r * N + c] - acc) / abs(acc))) }
    }
    verifyMsg = (maxRel <= 1e-3 ? "PASS" : "FAIL") + String(format: " (max rel err %.2e, matmul+bias)", maxRel)
} else if verify == "reduce_sum" {
    let n = Int(scalar("n"))
    let x = hostF["x"]!
    let partials = bufF("partials")
    let np = bindings.first(where: { $0.name == "partials" })!.len
    var gpu = 0.0
    for i in 0..<np { gpu += Double(partials[i]) }
    var ref = 0.0
    for i in 0..<n { ref += Double(x[i]) }
    let rel = ref != 0 ? abs(gpu - ref) / abs(ref) : abs(gpu)
    verifyMsg = (rel <= 1e-3 ? "PASS" : "FAIL") + String(format: " (sum rel err %.2e)", rel)
} else if verify == "softmax" {
    let R = Int(scalar("R")); let C = Int(scalar("C"))
    let x = hostF["x"]!; let y = bufF("y")
    var maxRel = 0.0, maxSumErr = 0.0
    for _ in 0..<16 {
        let r = Int.random(in: 0..<R)
        var m = -Float.greatestFiniteMagnitude
        for j in 0..<C { m = max(m, x[r * C + j]) }
        var s: Float = 0
        for j in 0..<C { s += exp(x[r * C + j] - m) }
        var rowsum: Float = 0
        for j in 0..<C { rowsum += y[r * C + j] }
        maxSumErr = max(maxSumErr, Double(abs(rowsum - 1)))
        for _ in 0..<8 {
            let j = Int.random(in: 0..<C)
            let ref = exp(x[r * C + j] - m) / s
            if ref != 0 { maxRel = max(maxRel, Double(abs(y[r * C + j] - ref) / abs(ref))) }
        }
    }
    verifyMsg = (maxRel <= 1e-3 && maxSumErr <= 1e-3 ? "PASS" : "FAIL")
        + String(format: " (rel %.1e, row-sum err %.1e)", maxRel, maxSumErr)
} else if verify == "layernorm" {
    let R = Int(scalar("R")); let C = Int(scalar("C")); let eps = Float(scalar("eps"))
    let x = hostF["x"]!; let y = bufF("y")
    var maxRel = 0.0
    for _ in 0..<16 {
        let r = Int.random(in: 0..<R)
        var mean: Float = 0
        for j in 0..<C { mean += x[r * C + j] }
        mean /= Float(C)
        var v: Float = 0
        for j in 0..<C { let d = x[r * C + j] - mean; v += d * d }
        v /= Float(C)
        let inv = 1 / (v + eps).squareRoot()
        for _ in 0..<8 {
            let j = Int.random(in: 0..<C)
            let ref = (x[r * C + j] - mean) * inv
            maxRel = max(maxRel, Double(abs(y[r * C + j] - ref) / max(abs(ref), 1e-3)))
        }
    }
    verifyMsg = (maxRel <= 1e-2 ? "PASS" : "FAIL") + String(format: " (rel %.1e)", maxRel)
} else if verify == "clamp01" {
    let n = Int(scalar("n")); let x = hostF["x"]!; let y = bufF("y")
    var maxErr = 0.0
    for i in stride(from: 0, to: n, by: max(1, n / 4096)) {
        let ref = min(max(x[i], 0), 1)             // reference clamp
        maxErr = max(maxErr, Double(abs(y[i] - ref)))
    }
    verifyMsg = (maxErr <= 1e-6 ? "PASS" : "FAIL") + String(format: " (max err %.1e, ternary)", maxErr)
} else if verify == "scale_half" {
    let n = Int(scalar("n")); let x = hostF["x"]!; let y = bufF("y")
    var maxRel = 0.0
    for i in stride(from: 0, to: n, by: max(1, n / 4096)) {
        let ref = Float(Float16(x[i])) * 2.0       // half-rounded reference
        if ref != 0 { maxRel = max(maxRel, Double(abs(y[i] - ref) / abs(ref))) }
    }
    verifyMsg = (maxRel <= 1e-3 ? "PASS" : "FAIL") + String(format: " (rel %.1e, f16 compute)", maxRel)
} else if verify == "attention" {
    let S = Int(scalar("S")); let D = Int(scalar("D")); let scale = Float(scalar("scale"))
    let Q = hostF["Q"]!; let K = hostF["K"]!; let V = hostF["V"]!; let O = bufF("O")
    var maxRel = 0.0
    for _ in 0..<8 {
        let i = Int.random(in: 0..<S)
        var sc = [Float](repeating: 0, count: S)
        var m = -Float.greatestFiniteMagnitude
        for j in 0..<S {
            var a: Float = 0
            for d in 0..<D { a += Q[i*D+d] * K[j*D+d] }
            a *= scale; sc[j] = a; m = max(m, a)
        }
        var s: Float = 0
        for j in 0..<S { sc[j] = exp(sc[j] - m); s += sc[j] }
        for d in 0..<D {
            var o: Float = 0
            for j in 0..<S { o += sc[j] * V[j*D+d] }
            let ref = o / s
            if abs(ref) > 1e-4 { maxRel = max(maxRel, Double(abs(O[i*D+d] - ref) / abs(ref))) }
        }
    }
    verifyMsg = (maxRel <= 1e-3 ? "PASS" : "FAIL") + String(format: " (rel %.1e, attention)", maxRel)
} else if verify == "conv2d" {
    let H = Int(scalar("H")); let W = Int(scalar("W"))
    let KH = Int(scalar("KH")); let KW = Int(scalar("KW"))
    let OW = W - KW + 1, OH = H - KH + 1
    let In = hostF["In"]!; let Wt = hostF["Wt"]!; let Out = bufF("Out")
    var maxRel = 0.0
    for _ in 0..<24 {
        let ox = Int.random(in: 0..<OW), oy = Int.random(in: 0..<OH)
        var acc: Float = 0
        for ky in 0..<KH { for kx in 0..<KW { acc += In[(oy+ky)*W + (ox+kx)] * Wt[ky*KW + kx] } }
        if acc != 0 { maxRel = max(maxRel, Double(abs(Out[oy*OW + ox] - acc) / abs(acc))) }
    }
    verifyMsg = (maxRel <= 1e-3 ? "PASS" : "FAIL") + String(format: " (rel %.1e, conv2d)", maxRel)
} else if verify == "quant_i8" {
    let n = Int(scalar("n")); let x = hostF["x"]!; let y = bufF("y")
    var maxErr = 0.0
    for i in stride(from: 0, to: n, by: max(1, n / 4096)) {
        let q = Int8((x[i] * 127.0).rounded())     // reference INT8 quantization
        let ref = Float(q) / 127.0
        maxErr = max(maxErr, Double(abs(y[i] - ref)))
    }
    verifyMsg = (maxErr <= 1e-6 ? "PASS" : "FAIL") + String(format: " (max err %.1e, i8 quant)", maxErr)
} else if verify == "collatz" {
    let base = UInt32(truncatingIfNeeded: Int(scalar("base")))
    let n = Int(scalar("n"))
    let out = bufU("out")
    var checks = 0, oks = 0
    for id in stride(from: 0, to: n, by: max(1, n / 2000)) {
        var x = base &+ UInt32(id)
        if x == 0 { x = 1 }
        var steps: UInt32 = 0
        while true {
            if x <= 1 { break }
            if steps >= 2000 { break }
            if x % 2 == 0 { x /= 2 } else { x = 3 &* x &+ 1 }
            steps &+= 1
        }
        checks += 1; if out[id] == steps { oks += 1 }
    }
    verifyMsg = (oks == checks ? "PASS" : "FAIL") + " (\(oks)/\(checks) Collatz step counts)"
} else if verify == "sha256" {
    let base = UInt32(truncatingIfNeeded: Int(scalar("base")))
    let out = bufU("out")
    var checks = 0, oks = 0
    for id in stride(from: 0, to: gridTotal, by: max(1, gridTotal / 1000)) {
        let nonce = base &+ UInt32(id)
        let msg: [UInt8] = [UInt8(nonce >> 24), UInt8((nonce >> 16) & 0xff),
                            UInt8((nonce >> 8) & 0xff), UInt8(nonce & 0xff)]
        let digest = Array(SHA256.hash(data: Data(msg)))   // 32 bytes, big-endian words
        var match = true
        for j in 0..<8 {
            let expected = (UInt32(digest[j * 4]) << 24) | (UInt32(digest[j * 4 + 1]) << 16)
                         | (UInt32(digest[j * 4 + 2]) << 8) | UInt32(digest[j * 4 + 3])
            if out[id * 8 + j] != expected { match = false }
        }
        checks += 1; if match { oks += 1 }
    }
    verifyMsg = (oks == checks ? "PASS" : "FAIL")
        + " (\(oks)/\(checks) hashes match Apple CryptoKit SHA-256)"
}

// ---- timing ---------------------------------------------------------------
resetBuffers(); dispatchOnce()               // warm up
resetBuffers()
let t0 = CACurrentMediaTime()
for _ in 0..<iters { dispatchOnce() }
let t1 = CACurrentMediaTime()
let avg = (t1 - t0) / Double(iters)

// ---- mining scan (sha256): find the "hardest" hash in the scanned range --
var miningLine: String? = nil
if verify == "sha256" {
    let outAll = bufU("out")
    let base2 = UInt32(truncatingIfNeeded: Int(scalar("base")))
    var bestZeros = -1
    var bestNonce: UInt32 = 0
    for id in 0..<gridTotal {
        var zeros = 0, j = 0
        while j < 8 {
            let word = outAll[id * 8 + j]
            if word == 0 { zeros += 32; j += 1 } else { zeros += word.leadingZeroBitCount; break }
        }
        if zeros > bestZeros { bestZeros = zeros; bestNonce = base2 &+ UInt32(id) }
    }
    miningLine = "mined     : best \(bestZeros) leading zero bits @ nonce \(bestNonce) (of \(gridTotal) scanned)"
}

// ---- image output (rasterizer) -------------------------------------------
var imageLine: String? = nil
if let im = json["image"] as? [String: Any], let bname = im["buffer"] as? String,
   let w = im["width"] as? Int, let h = im["height"] as? Int, let rel = im["path"] as? String,
   let bidx = bindings.firstIndex(where: { $0.name == bname }) {
    let outURL = rel.hasPrefix("/") ? URL(fileURLWithPath: rel) : baseDir.appendingPathComponent(rel)
    savePNG(buffer: gpuBuffers[bidx]!, width: w, height: h, path: outURL.path)
    imageLine = "image     : \(outURL.path)"
}

// ---- dump output buffers (for the Python host API) ------------------------
for (idx, b) in bindings.enumerated() where b.kind == "buffer" {
    if let path = b.dump, let buf = gpuBuffers[idx] {
        let data = Data(bytes: buf.contents(), count: b.len * 4)
        try? data.write(to: URL(fileURLWithPath: path))
    }
}

// ---- report ---------------------------------------------------------------
print("┌─ clic · Metal backend ─────────────────────────────")
print(String(format: "│ device      : %@", device.name))
print(String(format: "│ kernel      : %@", kernelName))
print(String(format: "│ grid        : %@   threadgroup: %@", grid.description, tg.description))
print(String(format: "│ iterations  : %d", iters))
print(String(format: "│ avg time    : %.3f ms", avg * 1e3))
if flops > 0 {
    print(String(format: "│ throughput  : %.1f GFLOP/s", (flops / avg) / 1e9))
} else if verify == "sha256" {
    print(String(format: "│ hash rate   : %.1f MH/s (%.0f hashes / dispatch)",
                 (Double(gridTotal) / avg) / 1e6, Double(gridTotal)))
}
if verify != nil { print(String(format: "│ correctness : %@", verifyMsg)) }
if let m = miningLine { print("│ " + m) }
if let im = imageLine { print("│ " + im) }
print("└────────────────────────────────────────────────────")
