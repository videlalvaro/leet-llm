# Curriculum

## North star

The course builds one decoder-only transformer inference engine on an Apple
Silicon Mac. It begins with scalar arithmetic and ends with loading a small
educational model, producing tokens, measuring prefill and decode separately,
and defending the engine's memory and kernel choices. The final lesson states
the additional checkpoint, tokenizer, and external-parity work needed for a
pretrained model rather than presenting the bundled fixture as one.

Problem 000 is an orientation reading. Problems 001 through 047 are implemented
in the repository.

## How to read the sequence

The order is dependency-driven, not topic-driven. Metal is not postponed to a
separate advanced unit. Once a CPU operation is understood, its Metal mapping
appears beside it. Similarly, performance is not a final polishing step; bytes,
FLOPs, and launch cost are tracked from the first reduction onward.

Each problem ends with an artifact used later. The "driving question" is the
engineering decision the learner should be able to make after completing it.

## Module 0: See the whole machine

| ID | Problem | Artifact | Driving question | Status |
| --- | --- | --- | --- | --- |
| 000 | Start Here: Build an LLM Inference Engine | Course map and inference primer | What will I build, and how should I work through the course? | Available reading |
| 001 | Vector dot product | Swift oracle and Metal reduction | Why is a tiny equation already a memory and synchronization problem? | Available |

Milestone: explain where dot products occur in projection and attention, then
run one CPU and one Metal implementation through the same judge.

## Module 1: Tensors and dense linear algebra

| ID | Problem | Artifact | Driving question |
| --- | --- | --- | --- |
| 002 | Tensor storage and strides | Checked tensor view | How does a logical index become a byte address? |
| 003 | Transpose and tiled copy | Coalesced Metal copy kernel | When is changing layout worth its cost? |
| 004 | Matrix-vector multiplication | GEMV operator | Why does one-token decode often behave like a bandwidth workload? |
| 005 | Matrix-matrix multiplication | Tiled GEMM operator | Why can prefill use the GPU more efficiently than decode? |
| 006 | Build a roofline measurement | Machine-specific baseline report | Is this shape limited by arithmetic, memory bandwidth, or overhead? |

Milestone: compute a linear projection in both `[M, K] x [K]` and
`[S, K] x [K, N]` forms, measure them separately, and explain why their reuse
differs.

## Module 2: Neural-network operators

| ID | Problem | Artifact | Driving question |
| --- | --- | --- | --- |
| 007 | ReLU, GELU, and SiLU | Elementwise activation suite | Which cost comes from math and which comes from another memory pass? |
| 008 | SwiGLU feed-forward gate | Gated MLP operator | Why does a modern MLP need three projections rather than two? |
| 009 | Numerically stable softmax | CPU and Metal softmax | Why does subtracting the maximum preserve the result but avoid overflow? |
| 010 | RMSNorm | Mixed-precision normalization | Which values must be accumulated at higher precision? |
| 011 | Residual streams and precision | Residual-add policy | Where can a downcast change many later layers? |
| 012 | Fuse norm, scale, and projection input | Fused kernel and comparison | When does removing a memory round trip justify a more complex kernel? |

Milestone: run a normalized SwiGLU MLP with numerical parity and identify each
intermediate allocation that a fused implementation could remove.

## Module 3: Positions and attention

| ID | Problem | Artifact | Driving question |
| --- | --- | --- | --- |
| 013 | Embedding lookup and tied output weights | Embedding/unembedding operator | Why is a lookup memory access while unembedding is a large projection? |
| 014 | Q/K/V projections and head views | Shape-safe Q/K/V split | Which dimensions represent tokens, query heads, KV heads, and head width? |
| 015 | Rotary position embeddings | RoPE operator and fixtures | What information changes when each feature pair is rotated by position? |
| 016 | Causal attention for one head | Materialized reference attention | Where does the causal mask enter the equation? |
| 017 | Multi-head attention | Parallel head implementation | What does adding heads change about shapes and memory? |
| 018 | Multi-query and grouped-query attention | MHA/MQA/GQA variants | How can fewer KV heads reduce cache traffic while retaining query heads? |
| 019 | Online softmax | Streaming attention reduction | How can a stable softmax be updated without storing every score? |
| 020 | Tiled fused attention | Flash-style Metal kernel | Which score matrix reads and writes disappear when tiles stay on chip? |
| 021 | Sliding-window and local attention | Windowed attention policy | When is bounded context a quality tradeoff worth taking? |

Milestone: implement the same causal attention result three ways: materialized,
online, and tiled. Compare memory use, not only elapsed time.

## Module 4: KV-cache engineering

| ID | Problem | Artifact | Driving question |
| --- | --- | --- | --- |
| 022 | Preallocate and append K/V | Contiguous KV cache | Why is repeated array growth unacceptable in a decode loop? |
| 023 | Cached single-token attention | Decode attention operator | Which computation from prior tokens can be reused exactly? |
| 024 | KV layout shootout | Layout benchmark | Should token, layer, head, or feature be the contiguous dimension? |
| 025 | Shared KV heads | GQA-aware cache | How does KV-head sharing change bytes read per generated token? |
| 026 | Ring-buffer sliding cache | Fixed-memory cache | How do logical positions survive physical wraparound? |
| 027 | Paged KV allocation | Page table and allocator | What fragmentation and batching problems does paging solve? |
| 028 | Quantized KV cache | Low-bit cache path | When does reduced bandwidth repay dequantization and accuracy cost? |

Milestone: derive and measure the cache budget

$$
\text{KV bytes} = 2 L T H_{kv} d_h b,
$$

where $L$ is layer count, $T$ is cached token count, $H_{kv}$ is KV-head count,
$d_h$ is head width, and $b$ is bytes per stored element.

## Module 5: Weight quantization

| ID | Problem | Artifact | Driving question | Status |
| --- | --- | --- | --- | --- |
| 029 | Symmetric INT8 quantization | Quantize/dequantize pair | What range and error does one scale represent? | Available |
| 030 | Per-channel and groupwise scales | Grouped quantizer | How does a smaller group trade metadata for fidelity? | Available |
| 031 | Pack and unpack INT4 | Bit-exact storage format | Which nibble, sign, and alignment conventions must match the loader? | Available |
| 032 | Dequantize then GEMV | Correct low-bit baseline | How much temporary memory does an unfused path create? | Available |
| 033 | Fused Q4 GEMV | Metal low-bit projection | Is the kernel saving enough weight traffic to pay for unpacking? | Available |
| 034 | Quantization error propagation | Layerwise error report | Which metric catches a convention bug before it is called "quantization noise"? | Available |

Milestone: run the same deterministic pipeline in FP32, INT8, and groupwise
INT4; report cosine similarity, maximum error, RMSE, argmax agreement, bytes,
and fused-projection latency. Conversion and runtime conventions must be
verified independently.

## Module 6: Assemble inference

| ID | Problem | Artifact | Driving question | Status |
| --- | --- | --- | --- | --- |
| 035 | One decoder transformer block | Integrated block | In what exact order do norm, attention, residual, MLP, and residual run? | Available |
| 036 | Parse a model weight format | Bounds-checked weight loader | How are names, shapes, dtypes, offsets, and model metadata trusted? | Available |
| 037 | Tokenization and detokenization | Byte-level BPE tokenizer with fixtures | What bytes actually enter and leave the model? | Available |
| 038 | Logits and sampling | Greedy, temperature, top-k, and top-p sampling | Which operations change model probabilities versus the sampling policy? | Available |
| 039 | Prompt prefill | Multi-token execution path and populated per-layer KV cache | Which matrices make prefill compute-friendly? | Available |
| 040 | Autoregressive decode | Stateful one-token loop and deterministic generation session | Which weights and cache bytes are reread for every new token? | Available |
| 041 | Buffer reuse and memory planning | Executable aligned arena plan | Which allocations can safely share a physical range? | Available |
| 042 | Checkpoint parity and first divergence | Named-capture artifact and comparison report | Where does the first divergence from a reference capture set occur? | Available |

Milestone: run the deterministic educational mini-model, prefill a prompt,
decode tokens without reprojecting prior K/V, plan intermediate storage, and
localize deliberate convention faults against a serialized independent-oracle
artifact. No third-party production checkpoint or runtime is bundled; Problem
042 documents how to replace the educational artifact with captures from a
trusted external implementation.

## Module 7: Make tradeoffs with evidence

| ID | Problem | Artifact | Driving question | Status |
| --- | --- | --- | --- | --- |
| 043 | Fuse a transformer subgraph | Fused RMSNorm/QKV CPU and Metal path | Which dispatches and intermediate writes dominate enough to remove? | Available |
| 044 | Profile prefill and decode separately | Monotonic CPU stage profile | Why does one tokens-per-second number hide the useful diagnosis? | Available |
| 045 | Batch prompts and decode requests | Static and continuous discrete-event lab | When does throughput improve at the expense of per-request latency? | Available |
| 046 | Speculative decoding | Probability-correct draft-and-verify prototype | When can extra compute reduce serial target-model steps? | Available |
| 047 | Capstone inference engine | Reproducible educational engine report | Which design is best for this model, machine, context, and objective? | Available |

The capstone report includes:

- time to first token, prefill time, and serial decode tokens per second;
- exact model-weight and allocated KV-cache bytes plus modeled arena sizes;
- CPU stage timings and the Metal verification slice's command buffers and waits;
- weight and KV-cache formats;
- independent full-prefix and named Metal parity evidence;
- one adopted and one rejected optimization with their evidence basis; and
- explicit fixture, backend, timing, and model-quality limitations.

Milestone: run all five final judges, profile prefill and decode separately,
explain the batching and speculation conditions, and produce the capstone report
without relabeling modeled units as measurements or the Metal slice as a full
inference backend.

## What the sequence deliberately avoids

- Unmotivated algorithm riddles that never enter the engine
- A long math prerequisite course before touching a tensor
- GPU kernels without readable CPU oracles
- Performance claims made from debug builds or a single input shape
- Treating all attention or quantization methods as universally better
- Calling an output difference "low-bit noise" before checking conventions,
  layouts, scales, and accumulation behavior
