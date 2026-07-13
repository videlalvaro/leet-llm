# Math Primer

This is a just-in-time reference, not an entrance exam. Read the section named
by the current problem and work its small example before coding.

## Notation and shapes

A scalar is one number, such as $x \in \mathbb{R}$. A vector is an ordered list
of numbers, such as $\mathbf{x} \in \mathbb{R}^{D}$. A matrix has rows and
columns, such as $W \in \mathbb{R}^{M \times K}$. A tensor generalizes this to
more axes.

In this course, brackets describe shapes:

```text
x: [D]
W: [M, D]
tokens: [S, D]
Q: [S, H_q, d_h]
K, V: [S, H_kv, d_h]
```

The shape is logical. A layout additionally says how indices map to adjacent
memory. A dtype says how each element is represented and how many bytes it
occupies. Kernel correctness depends on all three.

## Dot product

For equal-length vectors $\mathbf{x}, \mathbf{y} \in \mathbb{R}^{N}$,

$$
\mathbf{x} \cdot \mathbf{y} = \sum_{i=0}^{N-1} x_i y_i.
$$

For $\mathbf{x} = [1, 2, 3]$ and $\mathbf{y} = [4, -1, 2]$, the result is
$4 - 2 + 6 = 8$.

There are $N$ multiplications and approximately $N$ additions. In common
performance accounting this is about $2N$ floating-point operations, or FLOPs.

## Matrix-vector multiplication

For $W \in \mathbb{R}^{M \times K}$ and $\mathbf{x} \in \mathbb{R}^{K}$,

$$
\mathbf{y} = W\mathbf{x}, \qquad
y_m = \sum_{k=0}^{K-1} W_{m,k} x_k.
$$

Each output is a dot product between one row of $W$ and $\mathbf{x}$. A
single-token projection in decode commonly has this shape.

## Matrix-matrix multiplication

For $A \in \mathbb{R}^{M \times K}$ and $B \in \mathbb{R}^{K \times N}$,

$$
C = AB, \qquad
C_{m,n} = \sum_{k=0}^{K-1} A_{m,k} B_{k,n}.
$$

The inner dimensions must match. Unlike GEMV, a well-tiled GEMM can reuse values
from both inputs across many output elements. Prompt prefill creates these
larger matrix shapes.

## Linear layers

A dense neural-network layer is

$$
\mathbf{y} = W\mathbf{x} + \mathbf{b}.
$$

Some transformer projections omit the bias. The model architecture, not a
generic formula, determines whether it exists and how weights are laid out.

## Elementwise activations and gates

ReLU is

$$
\operatorname{ReLU}(x) = \max(0, x).
$$

The sigmoid and SiLU functions are

$$
\sigma(x) = \frac{1}{1 + e^{-x}}, \qquad
\operatorname{SiLU}(x) = x\sigma(x).
$$

A common SwiGLU feed-forward form is

$$
\operatorname{MLP}(\mathbf{x}) =
\left(\operatorname{SiLU}(\mathbf{x}W_g) \odot
      (\mathbf{x}W_u)\right) W_d,
$$

where $\odot$ is elementwise multiplication. Exact orientation and bias rules
come from the model being implemented.

## Stable softmax

Softmax turns logits $z_i$ into positive values that sum to one:

$$
p_i = \frac{e^{z_i}}{\sum_j e^{z_j}}.
$$

Direct exponentiation can overflow. Let $m = \max_j z_j$. Then

$$
p_i = \frac{e^{z_i-m}}{\sum_j e^{z_j-m}}.
$$

Subtracting the same constant from every logit does not change the ratio, and
the largest exponent is now $e^0 = 1$.

## RMS normalization

One common RMSNorm form is

$$
\operatorname{RMSNorm}(\mathbf{x}) =
\frac{\mathbf{x}}{
\sqrt{\frac{1}{D}\sum_{i=0}^{D-1} x_i^2 + \epsilon}}
\odot \boldsymbol{\gamma}.
$$

The reduction is often accumulated in wider precision than the stored input.
The exact scale convention must be taken from the model definition and weight
conversion path; it must not be guessed from the operator name.

## Rotary position embeddings

RoPE treats neighboring features as 2D pairs. At position $p$, pair $j$ is
rotated by angle $\theta_{p,j}$:

$$
\begin{aligned}
x'_{2j} &= x_{2j}\cos\theta_{p,j} - x_{2j+1}\sin\theta_{p,j}, \\
x'_{2j+1} &= x_{2j}\sin\theta_{p,j} + x_{2j+1}\cos\theta_{p,j}.
\end{aligned}
$$

The model specifies how frequencies produce $\theta_{p,j}$ and which dimensions
are rotated. RoPE is applied to queries and keys, not values.

## Scaled dot-product attention

For query, key, and value matrices with head width $d_h$,

$$
\operatorname{Attention}(Q, K, V) =
\operatorname{softmax}\left(\frac{QK^T}{\sqrt{d_h}} + M\right)V.
$$

$M$ is a mask. In causal attention, locations that would look into the future
receive a value that makes their post-softmax probability zero.

This equation describes the result, not a required implementation. A baseline
may materialize the score matrix. An online or tiled algorithm can produce the
same result while retaining only a small part of it at once.

## Quantization

For a simple symmetric signed quantizer with maximum integer magnitude
$q_{max}$, choose

$$
s = \frac{\max_i |w_i|}{q_{max}}, \qquad
q_i = \operatorname{clip}\left(\operatorname{round}(w_i/s),
-q_{max}, q_{max}\right).
$$

Approximate reconstruction is $\hat{w}_i = s q_i$. A scale can cover one tensor,
one output channel, or a smaller group. Smaller groups usually track local
ranges better but require more metadata and indexing work.

Low-bit formats are contracts. Signedness, packing order, zero points, group
size, scale dtype, and weight orientation must match between converter, loader,
and kernel.

## FLOPs, bytes, and arithmetic intensity

Arithmetic intensity is

$$
I = \frac{\text{FLOPs performed}}{\text{bytes moved from the limiting memory}}.
$$

For a large FP32 dot product, reading two vectors costs about $8N$ bytes and the
work is about $2N$ FLOPs, so

$$
I \approx \frac{2N}{8N} = 0.25\ \text{FLOP/byte}.
$$

The roofline estimate for attainable compute rate is

$$
P \leq \min(P_{peak}, B_{memory} I).
$$

This is a model, not a benchmark result. Small operations may instead be
dominated by launch, allocation, cache, or synchronization overhead.

## Latency and throughput

Latency is time for one request or stage. Throughput is work completed per unit
time. They are related but not interchangeable.

- Time to first token is strongly affected by prompt prefill.
- Decode tokens per second measures a serial stream of generated tokens.
- Batching can improve total throughput while making an individual request wait.

Always state which quantity and execution stage a number describes.

## Floating-point reductions

Real-number addition is associative; floating-point addition is not:

$$
(a+b)+c \neq a+(b+c)
$$

for some representable values. Parallel reductions change grouping, so a CPU
loop and Metal tree reduction can both be correct without matching bit for bit.
Judges therefore use a stated tolerance. A large or directional discrepancy is
still a defect to investigate, not something to dismiss automatically as
rounding or quantization noise.
