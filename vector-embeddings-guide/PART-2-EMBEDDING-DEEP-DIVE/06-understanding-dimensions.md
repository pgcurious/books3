# Chapter 6: Understanding Dimensions

## Why 768? The Science of Embedding Size

---

## The Fundamental Question

When you see that BERT uses 768 dimensions, you might wonder:

- Why 768? Why not 800 or 700?
- What do these dimensions represent?
- Could we use fewer? More?

Let's explore the science of dimensionality.

---

## What Each Dimension Captures

### The Uncomfortable Truth

**Individual dimensions are largely uninterpretable.**

Unlike hand-crafted features ("is_animal", "has_wheels"), learned dimensions don't have clear meanings. The concept of "cat" isn't stored in dimension 42 — it's distributed across all dimensions.

### Distributed Representations

```python
# Hypothetical: If dimensions were interpretable
cat = [
    0.9,   # is_animal
    0.8,   # is_pet
    0.0,   # is_vehicle
    0.7,   # has_fur
    0.0,   # has_wheels
]

# Reality: Dimensions are abstract
cat = [0.023, -0.156, 0.089, 0.412, -0.067, ...]  # 768 mysterious numbers
```

### Why Distributed?

Distributed representations are more powerful:
1. **Efficiency**: Fewer dimensions needed to represent many concepts
2. **Generalization**: Similar concepts share similar patterns
3. **Robustness**: No single dimension failure breaks everything

---

## The Information Theory Perspective

### How Much Can We Store?

Each dimension is a floating-point number (typically 32 bits). With 768 dimensions:

```
Storage = 768 × 32 bits = 24,576 bits ≈ 3 KB per embedding
```

But information capacity isn't just about bits — it's about the meaningful distinctions we can make.

### The Curse of Dimensionality

Higher dimensions have counterintuitive properties:

**In high dimensions, most of the space is "empty".**

```python
# Volume of unit hypersphere vs unit hypercube
import math

def sphere_volume(dimensions):
    """Volume of sphere with radius 1 in n dimensions."""
    return (math.pi ** (dimensions / 2)) / math.gamma(dimensions / 2 + 1)

def cube_volume(dimensions):
    """Volume of hypercube with side 2 in n dimensions."""
    return 2 ** dimensions

# Ratio of sphere to cube volume
for d in [2, 10, 100, 768]:
    ratio = sphere_volume(d) / cube_volume(d)
    print(f"D={d}: sphere is {ratio:.2e} of cube")

# D=2:   sphere is 7.85e-01 of cube
# D=10:  sphere is 2.49e-03 of cube
# D=100: sphere is 1.87e-70 of cube
# D=768: sphere is essentially 0 of cube
```

**Implication**: In 768 dimensions, almost all points are near the surface of the hypersphere, not evenly distributed.

---

## Why Certain Dimensions Work

### Historical Choices

| Model | Year | Dimensions | Why? |
|-------|------|------------|------|
| Word2Vec | 2013 | 100-300 | Empirically tested |
| GloVe | 2014 | 50-300 | Matched Word2Vec |
| BERT-base | 2018 | 768 | 12 attention heads × 64 |
| BERT-large | 2018 | 1024 | 16 attention heads × 64 |
| GPT-3 | 2020 | 12288 | Massive scale |

### The 768 Mystery Solved

BERT uses 768 because:
- 12 attention heads in BERT-base
- Each head processes 64-dimensional subspaces
- 12 × 64 = 768

It's an architectural choice, not a magic number.

---

## Dimensionality vs Quality

### Empirical Results

Research shows diminishing returns:

```
Dimensions | Relative Quality
-----------|-----------------
    64     |     0.82
   128     |     0.89
   256     |     0.94
   384     |     0.96
   512     |     0.97
   768     |     0.98
  1024     |     0.99
  1536     |     0.995
  3072     |     1.00 (baseline)
```

The jump from 64 to 256 is significant. The jump from 768 to 3072 is marginal.

### The Sweet Spot

For most applications, **384-1024 dimensions** offer the best quality-to-cost ratio:

```python
# Practical recommendations
use_case_dimensions = {
    "quick_prototype": 384,      # all-MiniLM-L6-v2
    "production": 768,           # all-mpnet-base-v2
    "quality_critical": 1024,    # bge-large
    "cost_no_object": 3072,      # text-embedding-3-large
}
```

---

## Dimensionality Reduction

Sometimes you want fewer dimensions:
- Reduce storage costs
- Speed up similarity search
- Enable visualization

### Method 1: Principal Component Analysis (PCA)

```python
from sklearn.decomposition import PCA
import numpy as np

# Original embeddings: 1000 sentences × 768 dimensions
embeddings = np.random.randn(1000, 768)

# Reduce to 256 dimensions
pca = PCA(n_components=256)
reduced = pca.fit_transform(embeddings)

print(f"Original: {embeddings.shape}")   # (1000, 768)
print(f"Reduced: {reduced.shape}")       # (1000, 256)

# How much variance is preserved?
print(f"Variance retained: {sum(pca.explained_variance_ratio_):.1%}")
# Typically 85-95% with 256 dimensions
```

### Method 2: Matryoshka Embeddings

Modern models like `text-embedding-3-small` support **Matryoshka representations**:

```python
# The embedding is designed so that the first N dimensions
# are already meaningful

full_embedding = [0.1, 0.2, 0.3, ..., 0.9]  # 1536 dimensions

# Just take the first 256!
truncated = full_embedding[:256]  # Still works well!
```

This is because the model was trained to front-load important information.

```python
# OpenAI API example
from openai import OpenAI
client = OpenAI()

response = client.embeddings.create(
    model="text-embedding-3-small",
    input="Hello world",
    dimensions=256  # Request smaller output
)
```

### Method 3: Quantization

Instead of reducing dimensions, reduce precision:

```python
import numpy as np

# Original: float32 (4 bytes per dimension)
embedding_f32 = np.array([0.123456, -0.789012, ...], dtype=np.float32)

# Quantized: int8 (1 byte per dimension)
embedding_int8 = (embedding_f32 * 127).astype(np.int8)

# 4× storage reduction, ~3-5% quality loss
```

---

## The Geometry of High Dimensions

### Distance Concentration

In high dimensions, distances between random points converge:

```python
import numpy as np

def distance_stats(dimensions, num_points=1000):
    """Show distance concentration in high dimensions."""
    points = np.random.randn(num_points, dimensions)

    # Compute all pairwise distances
    from scipy.spatial.distance import pdist
    distances = pdist(points)

    return distances.mean(), distances.std()

for d in [2, 10, 100, 768]:
    mean, std = distance_stats(d)
    cv = std / mean  # Coefficient of variation
    print(f"D={d:4d}: mean={mean:.2f}, std={std:.2f}, CV={cv:.3f}")

# D=   2: mean=1.40, std=0.52, CV=0.371
# D=  10: mean=3.12, std=0.49, CV=0.157
# D= 100: mean=9.96, std=0.50, CV=0.050
# D= 768: mean=27.7, std=0.51, CV=0.018
```

**Implication**: In 768 dimensions, all points are roughly the same distance apart! This is why **cosine similarity** (which measures angle) works better than **Euclidean distance** for embeddings.

### Why Cosine Similarity Wins

```python
import numpy as np

def euclidean_similarity(a, b):
    return -np.linalg.norm(a - b)

def cosine_similarity(a, b):
    return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))

# In high dimensions, cosine similarity is more discriminative
# because it measures direction, not absolute distance
```

---

## Choosing Dimensions for Your Use Case

### Decision Matrix

| Constraint | Recommended Dimensions | Model Examples |
|------------|----------------------|----------------|
| Limited memory | 256-384 | MiniLM, truncated Matryoshka |
| Real-time search | 384-512 | MiniLM, custom quantized |
| Balanced production | 768 | MPNet, E5-base |
| Quality critical | 1024-1536 | BGE-large, text-embedding-3-small |
| Maximum quality | 3072 | text-embedding-3-large |

### Cost Calculation

```python
# Storage cost per embedding
def storage_bytes(dimensions, dtype='float32'):
    bytes_per_value = {'float32': 4, 'float16': 2, 'int8': 1}
    return dimensions * bytes_per_value[dtype]

# For 1 million documents:
docs = 1_000_000

for dim in [384, 768, 1536, 3072]:
    gb = docs * storage_bytes(dim) / (1024**3)
    print(f"{dim:4d} dimensions: {gb:.2f} GB")

# 384 dimensions: 1.43 GB
# 768 dimensions: 2.86 GB
# 1536 dimensions: 5.72 GB
# 3072 dimensions: 11.44 GB
```

---

## Key Insights

1. **Dimensions are distributed** — no single dimension has clear meaning
2. **More dimensions = more capacity**, but with diminishing returns
3. **768 isn't magic** — it's 12 attention heads × 64 dimensions
4. **384-1024 is the sweet spot** for most applications
5. **Matryoshka embeddings** let you truncate dimensions at runtime
6. **High-dimensional geometry is weird** — most points are equidistant
7. **Cosine similarity** works better than Euclidean in high dimensions

---

## What's Next?

We've covered what embeddings are, how they're created, and why dimensions matter. Now we need to understand how to compare them. Part 3 explores **similarity measures** — the mathematical foundation of semantic search.

---

*Continue to [Part 3: Distance Metrics](../PART-3-SIMILARITY-MEASURES/07-distance-metrics.md)*
