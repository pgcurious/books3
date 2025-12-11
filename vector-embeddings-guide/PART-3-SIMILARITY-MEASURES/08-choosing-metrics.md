# Chapter 8: Choosing the Right Metric

## A Practical Guide to Distance Selection

---

## The Decision Framework

Choosing a distance metric isn't arbitrary. The right choice depends on:

1. **What your vectors represent**
2. **What "similarity" means for your use case**
3. **Performance requirements**
4. **What your tools support**

---

## Decision Tree

```
Start Here
    │
    ▼
Are your vectors already normalized?
    │
    ├─ Yes ──▶ Use Dot Product (fastest)
    │
    └─ No ───▶ Does magnitude carry meaning?
                   │
                   ├─ Yes ──▶ Use Euclidean or Dot Product
                   │
                   └─ No ───▶ Use Cosine Similarity
```

---

## Use Case Recommendations

### Semantic Text Search

**Recommended: Cosine Similarity**

```python
# Text embeddings from models like BERT, sentence-transformers
# Meaning is in direction, not magnitude

metric = "cosine"
```

**Why**: Text length shouldn't affect similarity. A short query about "machine learning" should match a long document about ML.

### Image Similarity

**Recommended: Cosine or Euclidean**

```python
# Image embeddings from CLIP, ResNet, etc.

metric = "cosine"  # Usually best
# or
metric = "euclidean"  # Sometimes comparable
```

**Why**: Image embeddings are typically normalized, so both work similarly. Cosine handles any normalization variations.

### Recommendation Systems

**Recommended: Dot Product**

```python
# User and item embeddings from collaborative filtering

metric = "dot_product"
```

**Why**: Magnitude often encodes "strength" or "confidence." A user with a strong preference vector should match strongly-represented items.

### Clustering

**Recommended: Euclidean**

```python
# K-means, DBSCAN, hierarchical clustering

metric = "euclidean"  # Most clustering algorithms assume this
```

**Why**: Cluster centroids are computed using Euclidean geometry. Other metrics require specialized algorithms.

### Binary/Sparse Features

**Recommended: Jaccard or Hamming**

```python
# Presence/absence features, hash codes

metric = "jaccard"   # For sets
metric = "hamming"   # For binary vectors
```

**Why**: Designed specifically for binary data. More interpretable for set overlap.

---

## Comparative Analysis

### Experiment: Same Data, Different Metrics

```python
import numpy as np
from sklearn.metrics.pairwise import (
    cosine_similarity,
    euclidean_distances
)

# Simulate embeddings
np.random.seed(42)
n_docs = 5
dim = 768

# Create embeddings with varying magnitudes
embeddings = np.random.randn(n_docs, dim)
magnitudes = [1.0, 2.0, 0.5, 1.5, 3.0]  # Different document "lengths"
for i, mag in enumerate(magnitudes):
    embeddings[i] = embeddings[i] * mag

# Query
query = embeddings[0].reshape(1, -1)

# Cosine similarity ranking
cos_sim = cosine_similarity(query, embeddings)[0]
cos_ranking = np.argsort(-cos_sim)
print("Cosine ranking:", cos_ranking)

# Euclidean distance ranking
euc_dist = euclidean_distances(query, embeddings)[0]
euc_ranking = np.argsort(euc_dist)
print("Euclidean ranking:", euc_ranking)

# Dot product ranking
dot_prod = np.dot(embeddings, query.T).flatten()
dot_ranking = np.argsort(-dot_prod)
print("Dot product ranking:", dot_ranking)

# Results often differ due to magnitude effects!
```

### When Rankings Differ

| Scenario | Cosine | Euclidean | Dot Product |
|----------|--------|-----------|-------------|
| Equal magnitudes | Same | Same | Same |
| Varied magnitudes | By direction only | By position | By direction × magnitude |
| Normalized vectors | Same as Dot | Same as others | Same as Cosine |

---

## Common Pitfalls

### Pitfall 1: Mixing Metrics

```python
# BAD: Indexed with one metric, searching with another
index.add(vectors, metric="cosine")
results = index.search(query, metric="euclidean")  # Wrong results!

# GOOD: Consistent metrics
index.add(vectors, metric="cosine")
results = index.search(query, metric="cosine")
```

### Pitfall 2: Forgetting to Normalize

```python
# BAD: Using dot product without normalization
similarity = np.dot(a, b)  # Magnitude affects results

# GOOD: Normalize first
a_norm = a / np.linalg.norm(a)
b_norm = b / np.linalg.norm(b)
similarity = np.dot(a_norm, b_norm)  # Now equals cosine similarity
```

### Pitfall 3: Ignoring Database Conventions

```python
# Pinecone: Returns similarity scores (higher = better)
# pgvector: Returns distances (lower = better)

# Always check and convert if needed!
def normalize_score(score, metric_type):
    if metric_type == "distance":
        return -score  # Flip for ranking
    return score
```

### Pitfall 4: Using Euclidean in High Dimensions

In very high dimensions (>1000), Euclidean distances concentrate:

```python
# All pairs become similarly distant
# Cosine similarity remains discriminative

# Prefer cosine for high-dimensional data
```

---

## Performance Optimization

### Strategy 1: Pre-normalize for Speed

```python
class OptimizedSearch:
    def __init__(self, vectors):
        # Normalize once during indexing
        norms = np.linalg.norm(vectors, axis=1, keepdims=True)
        self.normalized_vectors = vectors / norms

    def search(self, query):
        # Normalize query once
        query_norm = query / np.linalg.norm(query)

        # Dot product = cosine similarity for normalized vectors
        similarities = np.dot(self.normalized_vectors, query_norm)
        return np.argsort(-similarities)
```

### Strategy 2: Batch Operations

```python
# Slow: One at a time
similarities = [cosine_similarity(query, v) for v in vectors]

# Fast: Vectorized
query_norm = query / np.linalg.norm(query)
vectors_norm = vectors / np.linalg.norm(vectors, axis=1, keepdims=True)
similarities = np.dot(vectors_norm, query_norm)
```

### Strategy 3: Use Optimized Libraries

```python
# NumPy is good, but specialized libraries are faster

# For large-scale:
import faiss  # Facebook's similarity search library

index = faiss.IndexFlatIP(dimension)  # Inner Product (dot product)
index.add(normalized_vectors)
distances, indices = index.search(query, k=10)
```

---

## Metric Conversion Formulas

Sometimes you need to convert between metrics:

### Cosine Similarity ↔ Cosine Distance

```python
cosine_distance = 1 - cosine_similarity
cosine_similarity = 1 - cosine_distance
```

### Cosine ↔ Euclidean (for normalized vectors)

```python
# For unit vectors:
euclidean_distance = np.sqrt(2 * (1 - cosine_similarity))
cosine_similarity = 1 - (euclidean_distance ** 2) / 2
```

### Dot Product ↔ Cosine

```python
# For normalized vectors: they're equal
# For unnormalized:
cosine_similarity = dot_product / (norm_a * norm_b)
```

---

## Real-World Configurations

### Pinecone

```python
import pinecone

pinecone.create_index(
    name="semantic-search",
    dimension=768,
    metric="cosine"  # Also: "euclidean", "dotproduct"
)
```

### Weaviate

```python
# In schema definition
{
    "class": "Document",
    "vectorIndexConfig": {
        "distance": "cosine"  # Also: "l2-squared", "dot", "hamming"
    }
}
```

### pgvector (PostgreSQL)

```sql
-- Cosine distance (note: lower is better)
SELECT * FROM documents
ORDER BY embedding <=> query_embedding
LIMIT 10;

-- L2 distance
SELECT * FROM documents
ORDER BY embedding <-> query_embedding
LIMIT 10;

-- Inner product (note: negate for similarity)
SELECT * FROM documents
ORDER BY embedding <#> query_embedding
LIMIT 10;
```

---

## Summary: Quick Reference

| Use Case | Metric | Why |
|----------|--------|-----|
| Text search | Cosine | Direction matters, not length |
| Image search | Cosine | Generally normalized |
| Recommendations | Dot Product | Magnitude = preference strength |
| Clustering | Euclidean | Centroid computation |
| Binary data | Jaccard/Hamming | Designed for sets/bits |
| Pre-normalized data | Dot Product | Fastest, equals cosine |

---

## Key Insights

1. **Default to cosine** for text embeddings
2. **Pre-normalize** vectors to use faster dot product
3. **Consistency is critical** — same metric for indexing and search
4. **High dimensions favor cosine** due to distance concentration
5. **Check your database** — conventions vary widely
6. **Dot product ≠ cosine** unless vectors are normalized

---

## What's Next?

We've covered embeddings and how to compare them. Now we'll put it all together: Part 4 covers building actual semantic search systems.

---

*Continue to [Part 4: From Keywords to Meaning](../PART-4-SEMANTIC-SEARCH/09-keywords-to-meaning.md)*
