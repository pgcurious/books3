# Chapter 7: Distance Metrics Explained

## Measuring Similarity in High-Dimensional Space

---

## The Core Question

We have embeddings. Now what?

The power of embeddings is that **similar things are close together**. But "close" needs a definition. In mathematics, we call this a **distance metric** or **similarity measure**.

This chapter explores the most important metrics for semantic search.

---

## The Big Three

### 1. Cosine Similarity

**The most common metric for text embeddings.**

Measures the cosine of the angle between two vectors:

```
                    A · B
cos(θ) = ─────────────────────
           ||A|| × ||B||
```

```python
import numpy as np

def cosine_similarity(a, b):
    dot_product = np.dot(a, b)
    norm_a = np.linalg.norm(a)
    norm_b = np.linalg.norm(b)
    return dot_product / (norm_a * norm_b)

# Example
a = np.array([1, 2, 3])
b = np.array([2, 4, 6])  # Same direction as a
c = np.array([-1, -2, -3])  # Opposite direction

print(cosine_similarity(a, b))  # 1.0 (identical direction)
print(cosine_similarity(a, c))  # -1.0 (opposite direction)
```

**Properties:**
- Range: [-1, 1] where 1 = identical, 0 = orthogonal, -1 = opposite
- **Ignores magnitude**: [1, 2] and [2, 4] have similarity 1.0
- Best for comparing **meaning/direction**, not scale

**Visual intuition:**

```
        b
       ↗
      /
     / θ (small angle = similar)
    ↗
   a

Cosine similarity = cos(θ)
```

### 2. Euclidean Distance (L2)

**The "straight line" distance between points.**

```
d(A, B) = √[(a₁-b₁)² + (a₂-b₂)² + ... + (aₙ-bₙ)²]
```

```python
def euclidean_distance(a, b):
    return np.linalg.norm(a - b)

# Or manually:
def euclidean_distance_manual(a, b):
    return np.sqrt(np.sum((a - b) ** 2))

# Example
a = np.array([0, 0])
b = np.array([3, 4])
print(euclidean_distance(a, b))  # 5.0 (the 3-4-5 triangle!)
```

**Properties:**
- Range: [0, ∞) where 0 = identical
- **Considers magnitude**: [1, 2] and [2, 4] have distance √5 ≈ 2.24
- Good for spatial/geometric relationships

**Visual intuition:**

```
    b
    •
    |  \
    |    \  d (this line's length)
    |      \
    •───────•
    a
```

### 3. Dot Product (Inner Product)

**Raw "alignment" measure without normalization.**

```
A · B = a₁×b₁ + a₂×b₂ + ... + aₙ×bₙ
```

```python
def dot_product(a, b):
    return np.dot(a, b)

# Example
a = np.array([1, 2, 3])
b = np.array([4, 5, 6])
print(dot_product(a, b))  # 32 = 1*4 + 2*5 + 3*6
```

**Properties:**
- Range: (-∞, ∞)
- **Considers both direction AND magnitude**
- For normalized vectors, dot product = cosine similarity

**Key insight:**

```python
# If vectors are normalized (magnitude = 1):
a_norm = a / np.linalg.norm(a)
b_norm = b / np.linalg.norm(b)

dot_product(a_norm, b_norm) == cosine_similarity(a, b)  # True!
```

---

## Other Important Metrics

### Manhattan Distance (L1)

Sum of absolute differences:

```python
def manhattan_distance(a, b):
    return np.sum(np.abs(a - b))

# Like walking city blocks (can only go N/S/E/W, no diagonals)
```

### Jaccard Similarity

For binary or set data:

```python
def jaccard_similarity(set_a, set_b):
    intersection = len(set_a & set_b)
    union = len(set_a | set_b)
    return intersection / union

# Example with words
doc1 = {"the", "cat", "sat"}
doc2 = {"the", "dog", "sat"}
print(jaccard_similarity(doc1, doc2))  # 0.5 (2 shared / 4 total)
```

### Hamming Distance

For binary vectors (count of differing bits):

```python
def hamming_distance(a, b):
    return np.sum(a != b)

# Used with binary hash codes
hash1 = np.array([1, 0, 1, 1, 0])
hash2 = np.array([1, 1, 1, 0, 0])
print(hamming_distance(hash1, hash2))  # 2 (positions 1 and 3 differ)
```

---

## Deep Dive: Why Cosine for Text?

### The Magnitude Problem

Consider two documents about "machine learning":
- Document A: 100 words, mentions "ML" 5 times
- Document B: 1000 words, mentions "ML" 50 times

With raw term frequency vectors:
- A = [5, ...]
- B = [50, ...]

**Euclidean distance** would say they're far apart (different magnitudes).

**Cosine similarity** ignores magnitude — both documents are about the same topic, so they're similar.

### Mathematical Proof

```python
# These vectors point in the same direction
a = np.array([1, 2, 3])
b = np.array([10, 20, 30])  # 10× magnitude

# Euclidean distance: large
print(euclidean_distance(a, b))  # ~35.5

# Cosine similarity: maximum
print(cosine_similarity(a, b))  # 1.0

# For embeddings, direction = meaning, magnitude = artifact
```

### When Magnitude Matters

Sometimes you DO want magnitude:

- **Popularity-weighted search**: More discussed topics rank higher
- **Confidence scores**: Stronger embeddings for clearer text
- **Maximum Inner Product Search (MIPS)**: Some ML applications

---

## Similarity vs Distance

These are inverse concepts:

| If | Then |
|----|------|
| High similarity | Low distance |
| Low similarity | High distance |

### Converting Between Them

```python
# Cosine similarity to distance
def cosine_distance(a, b):
    return 1 - cosine_similarity(a, b)

# Now: 0 = identical, 2 = opposite

# Euclidean distance to similarity
def euclidean_similarity(a, b, max_dist):
    return 1 - (euclidean_distance(a, b) / max_dist)
```

### Database Conventions

Different vector databases use different conventions:

| Database | Default Metric | Higher = Better? |
|----------|---------------|------------------|
| Pinecone | Cosine | Yes (similarity) |
| Weaviate | Cosine distance | No (distance) |
| Qdrant | Cosine | Yes (similarity) |
| Milvus | L2 distance | No (distance) |
| pgvector | L2 distance | No (distance) |

Always check documentation!

---

## Performance Comparison

```python
import numpy as np
import time

def benchmark(func, a, b, iterations=100000):
    start = time.time()
    for _ in range(iterations):
        func(a, b)
    return (time.time() - start) / iterations * 1e6  # microseconds

a = np.random.randn(768)
b = np.random.randn(768)

# Normalize for fair comparison
a_norm = a / np.linalg.norm(a)
b_norm = b / np.linalg.norm(b)

print(f"Dot product: {benchmark(np.dot, a_norm, b_norm):.2f} µs")
print(f"Euclidean:   {benchmark(euclidean_distance, a, b):.2f} µs")
print(f"Cosine:      {benchmark(cosine_similarity, a, b):.2f} µs")

# Typical results:
# Dot product: ~1.5 µs
# Euclidean:   ~2.0 µs
# Cosine:      ~3.5 µs (two norms + dot)
```

**Optimization tip**: Pre-normalize vectors, then use dot product (same as cosine but faster).

---

## The Triangle Inequality

A true distance metric must satisfy:

```
d(A, C) ≤ d(A, B) + d(B, C)
```

"The direct path is never longer than a detour."

**Why it matters**: Enables efficient index structures (can prune search space).

| Metric | Triangle Inequality? |
|--------|---------------------|
| Euclidean (L2) | Yes |
| Manhattan (L1) | Yes |
| Cosine distance | Yes |
| Dot product | No |

---

## Code: Implementing a Similarity Search

```python
import numpy as np
from typing import List, Tuple

class SimpleVectorSearch:
    def __init__(self, metric: str = 'cosine'):
        self.vectors = []
        self.metadata = []
        self.metric = metric

    def add(self, vector: np.ndarray, metadata: dict = None):
        # Normalize for cosine similarity
        if self.metric == 'cosine':
            vector = vector / np.linalg.norm(vector)
        self.vectors.append(vector)
        self.metadata.append(metadata or {})

    def search(self, query: np.ndarray, top_k: int = 5) -> List[Tuple[int, float]]:
        if self.metric == 'cosine':
            query = query / np.linalg.norm(query)

        similarities = []
        for i, vec in enumerate(self.vectors):
            if self.metric == 'cosine':
                sim = np.dot(query, vec)
            elif self.metric == 'euclidean':
                sim = -np.linalg.norm(query - vec)  # Negative so higher = better
            else:
                sim = np.dot(query, vec)

            similarities.append((i, sim))

        # Sort by similarity (descending)
        similarities.sort(key=lambda x: x[1], reverse=True)
        return similarities[:top_k]

# Usage
search = SimpleVectorSearch(metric='cosine')
search.add(np.array([0.1, 0.2, 0.3]), {"text": "first document"})
search.add(np.array([0.15, 0.25, 0.35]), {"text": "similar document"})
search.add(np.array([-0.5, 0.1, 0.9]), {"text": "different document"})

query = np.array([0.1, 0.2, 0.3])
results = search.search(query, top_k=2)
print(results)  # [(0, 1.0), (1, 0.999...)]
```

---

## Key Insights

1. **Cosine similarity** is standard for text — measures direction, ignores magnitude
2. **Euclidean distance** measures absolute spatial distance
3. **Dot product** equals cosine similarity for normalized vectors
4. **Pre-normalize** vectors for faster cosine computation
5. **Higher similarity = lower distance** (inverse relationship)
6. **Check your database's convention** — some use distance, some use similarity

---

## What's Next?

Now that you understand the metrics, how do you choose the right one? The next chapter provides practical guidance for different use cases.

---

*Continue to [Chapter 8: Choosing the Right Metric](./08-choosing-metrics.md)*
