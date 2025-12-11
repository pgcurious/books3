# Chapter 16: Hybrid Search

## Combining Keyword and Semantic Search

---

## Why Hybrid?

Neither keyword nor semantic search is universally better:

| Query Type | Keyword Wins | Semantic Wins |
|------------|-------------|---------------|
| Exact matches | "error code XJ42" | "why is my app crashing" |
| Technical terms | "CUDA_ERROR_OUT_OF_MEMORY" | "GPU memory problems" |
| Product codes | "SKU-12345" | "red running shoes size 10" |
| Natural language | Poor | Excellent |
| Typo tolerance | Poor | Good |

**Hybrid search gives you both.**

---

## The Basic Architecture

```
                    Query
                      │
           ┌─────────┴─────────┐
           ▼                   ▼
    ┌─────────────┐     ┌─────────────┐
    │   Keyword   │     │  Semantic   │
    │   Search    │     │   Search    │
    │   (BM25)    │     │  (Vector)   │
    └──────┬──────┘     └──────┬──────┘
           │                   │
           └─────────┬─────────┘
                     ▼
              ┌─────────────┐
              │   Fusion    │
              │  Algorithm  │
              └──────┬──────┘
                     ▼
                  Results
```

---

## Fusion Strategies

### Strategy 1: Score Combination

Combine normalized scores from both systems:

```python
def score_fusion(
    keyword_results: list,
    semantic_results: list,
    alpha: float = 0.5
) -> list:
    """
    Combine scores with weighted average.

    Args:
        keyword_results: [(doc_id, score), ...]
        semantic_results: [(doc_id, score), ...]
        alpha: Weight for semantic (1-alpha for keyword)
    """
    # Normalize scores to [0, 1]
    def normalize(results):
        if not results:
            return {}
        scores = [r[1] for r in results]
        min_s, max_s = min(scores), max(scores)
        range_s = max_s - min_s if max_s > min_s else 1
        return {r[0]: (r[1] - min_s) / range_s for r in results}

    keyword_norm = normalize(keyword_results)
    semantic_norm = normalize(semantic_results)

    # Combine
    combined = {}
    all_docs = set(keyword_norm.keys()) | set(semantic_norm.keys())

    for doc_id in all_docs:
        kw_score = keyword_norm.get(doc_id, 0)
        sem_score = semantic_norm.get(doc_id, 0)
        combined[doc_id] = (1 - alpha) * kw_score + alpha * sem_score

    # Sort by combined score
    return sorted(combined.items(), key=lambda x: x[1], reverse=True)
```

### Strategy 2: Reciprocal Rank Fusion (RRF)

A robust method that doesn't require score normalization:

```python
def reciprocal_rank_fusion(
    result_lists: list,
    k: int = 60
) -> list:
    """
    RRF: Combine multiple ranked lists.

    Formula: score(d) = sum(1 / (k + rank(d)))

    Args:
        result_lists: List of ranked document lists
        k: Constant to prevent high ranks from dominating
    """
    scores = {}

    for results in result_lists:
        for rank, doc_id in enumerate(results, 1):
            if doc_id not in scores:
                scores[doc_id] = 0
            scores[doc_id] += 1 / (k + rank)

    return sorted(scores.items(), key=lambda x: x[1], reverse=True)

# Usage
keyword_docs = ['doc1', 'doc3', 'doc2', 'doc5']  # Ranked by BM25
semantic_docs = ['doc2', 'doc1', 'doc4', 'doc3']  # Ranked by vector similarity

fused = reciprocal_rank_fusion([keyword_docs, semantic_docs])
# doc1 and doc2 rank high (appear in both lists)
```

### Strategy 3: Learned Fusion

Train a model to combine signals:

```python
from sklearn.linear_model import LogisticRegression
import numpy as np

class LearnedFusion:
    def __init__(self):
        self.model = LogisticRegression()

    def prepare_features(self, doc_id, keyword_results, semantic_results):
        """Create feature vector for a document."""
        # Find ranks and scores
        kw_rank = next((i for i, (d, _) in enumerate(keyword_results)
                       if d == doc_id), 100)
        sem_rank = next((i for i, (d, _) in enumerate(semantic_results)
                        if d == doc_id), 100)

        kw_score = next((s for d, s in keyword_results if d == doc_id), 0)
        sem_score = next((s for d, s in semantic_results if d == doc_id), 0)

        return [kw_rank, sem_rank, kw_score, sem_score]

    def train(self, training_data: list):
        """
        Train fusion model.

        training_data: [(keyword_results, semantic_results, relevant_docs), ...]
        """
        X, y = [], []

        for kw_res, sem_res, relevant in training_data:
            all_docs = set(d for d, _ in kw_res) | set(d for d, _ in sem_res)

            for doc_id in all_docs:
                features = self.prepare_features(doc_id, kw_res, sem_res)
                label = 1 if doc_id in relevant else 0
                X.append(features)
                y.append(label)

        self.model.fit(X, y)

    def fuse(self, keyword_results, semantic_results) -> list:
        """Apply learned fusion."""
        all_docs = set(d for d, _ in keyword_results) | set(d for d, _ in semantic_results)

        scores = []
        for doc_id in all_docs:
            features = self.prepare_features(doc_id, keyword_results, semantic_results)
            prob = self.model.predict_proba([features])[0][1]
            scores.append((doc_id, prob))

        return sorted(scores, key=lambda x: x[1], reverse=True)
```

---

## Implementation with Popular Tools

### Elasticsearch + Vector Search

```python
from elasticsearch import Elasticsearch

es = Elasticsearch()

# Create index with both text and vector fields
index_mapping = {
    "mappings": {
        "properties": {
            "content": {"type": "text"},  # For BM25
            "embedding": {
                "type": "dense_vector",
                "dims": 768,
                "index": True,
                "similarity": "cosine"
            }
        }
    }
}

es.indices.create(index="documents", body=index_mapping)

# Hybrid search query
def hybrid_search_es(query: str, query_embedding: list, alpha: float = 0.5):
    search_body = {
        "query": {
            "script_score": {
                "query": {
                    "bool": {
                        "should": [
                            # BM25 text search
                            {"match": {"content": query}}
                        ]
                    }
                },
                "script": {
                    "source": """
                        double bm25 = _score;
                        double vector = cosineSimilarity(params.embedding, 'embedding') + 1;
                        return params.alpha * vector + (1 - params.alpha) * bm25;
                    """,
                    "params": {
                        "embedding": query_embedding,
                        "alpha": alpha
                    }
                }
            }
        }
    }

    return es.search(index="documents", body=search_body)
```

### Weaviate Hybrid Search

```python
import weaviate

client = weaviate.Client("http://localhost:8080")

# Weaviate has built-in hybrid search
result = client.query.get(
    "Document",
    ["content", "title"]
).with_hybrid(
    query="machine learning basics",
    alpha=0.5  # 0 = pure keyword, 1 = pure vector
).with_limit(10).do()
```

### Pinecone + External Keyword Search

```python
from pinecone import Pinecone
from rank_bm25 import BM25Okapi

class HybridSearchPinecone:
    def __init__(self, index_name: str, documents: list):
        # Vector search with Pinecone
        pc = Pinecone(api_key="...")
        self.vector_index = pc.Index(index_name)

        # Keyword search with BM25
        tokenized = [doc['text'].split() for doc in documents]
        self.bm25 = BM25Okapi(tokenized)
        self.documents = documents

    def search(self, query: str, query_embedding: list, top_k: int = 10):
        # Vector search
        vector_results = self.vector_index.query(
            vector=query_embedding,
            top_k=top_k * 2
        )

        # Keyword search
        tokenized_query = query.split()
        bm25_scores = self.bm25.get_scores(tokenized_query)
        bm25_results = sorted(
            enumerate(bm25_scores),
            key=lambda x: x[1],
            reverse=True
        )[:top_k * 2]

        # Fusion
        vector_docs = [(m.id, m.score) for m in vector_results.matches]
        keyword_docs = [(self.documents[i]['id'], s) for i, s in bm25_results]

        return reciprocal_rank_fusion([
            [d for d, _ in vector_docs],
            [d for d, _ in keyword_docs]
        ])[:top_k]
```

---

## Tuning the Alpha Parameter

```python
def tune_alpha(
    test_queries: list,
    keyword_search,
    semantic_search,
    alphas: list = None
) -> float:
    """Find optimal alpha by grid search."""
    if alphas is None:
        alphas = [0.0, 0.2, 0.4, 0.5, 0.6, 0.8, 1.0]

    results = {}

    for alpha in alphas:
        scores = []

        for query_data in test_queries:
            query = query_data['query']
            relevant = query_data['relevant']

            kw_results = keyword_search(query)
            sem_results = semantic_search(query)

            fused = score_fusion(kw_results, sem_results, alpha=alpha)
            fused_docs = [doc_id for doc_id, _ in fused]

            # Calculate MRR
            for rank, doc_id in enumerate(fused_docs, 1):
                if doc_id in relevant:
                    scores.append(1 / rank)
                    break
            else:
                scores.append(0)

        results[alpha] = sum(scores) / len(scores)
        print(f"Alpha {alpha}: MRR = {results[alpha]:.3f}")

    best_alpha = max(results.items(), key=lambda x: x[1])[0]
    return best_alpha
```

### Typical Results

```
Alpha 0.0 (pure keyword):  MRR = 0.45
Alpha 0.2:                 MRR = 0.52
Alpha 0.4:                 MRR = 0.58
Alpha 0.5:                 MRR = 0.61  ← Often optimal
Alpha 0.6:                 MRR = 0.59
Alpha 0.8:                 MRR = 0.54
Alpha 1.0 (pure semantic): MRR = 0.50
```

The optimal alpha varies by domain. Technical domains often favor keyword; conversational domains favor semantic.

---

## Advanced: Query-Dependent Alpha

Different queries may need different weights:

```python
class AdaptiveHybridSearch:
    def __init__(self, keyword_search, semantic_search, classifier):
        self.keyword = keyword_search
        self.semantic = semantic_search
        self.classifier = classifier  # Predicts optimal alpha

    def classify_query(self, query: str) -> float:
        """Predict optimal alpha for this query."""
        # Features that might indicate keyword vs semantic
        features = {
            'has_quotes': '"' in query,
            'has_code': any(c in query for c in '{}[]()='),
            'is_question': query.strip().endswith('?'),
            'word_count': len(query.split()),
            'has_numbers': any(c.isdigit() for c in query),
        }

        # Simple rule-based (replace with ML model)
        if features['has_quotes'] or features['has_code']:
            return 0.2  # Favor keyword
        elif features['is_question'] and features['word_count'] > 5:
            return 0.8  # Favor semantic
        else:
            return 0.5  # Balanced

    def search(self, query: str, top_k: int = 10):
        alpha = self.classify_query(query)

        kw_results = self.keyword(query)
        sem_results = self.semantic(query)

        return score_fusion(kw_results, sem_results, alpha=alpha)
```

---

## Production Considerations

### Latency

```python
import asyncio
import time

async def parallel_hybrid_search(query: str, query_embedding: list):
    """Run keyword and semantic search in parallel."""
    async def keyword_search():
        # Simulated async keyword search
        return await keyword_client.search(query)

    async def semantic_search():
        # Simulated async vector search
        return await vector_client.search(query_embedding)

    # Run in parallel
    start = time.time()
    kw_results, sem_results = await asyncio.gather(
        keyword_search(),
        semantic_search()
    )
    parallel_time = time.time() - start

    # Fusion is fast
    fused = reciprocal_rank_fusion([kw_results, sem_results])

    return fused, parallel_time

# Parallel: ~max(kw_time, sem_time)
# Sequential: ~kw_time + sem_time
```

### Caching

```python
from functools import lru_cache
import hashlib

class CachedHybridSearch:
    def __init__(self, keyword_search, semantic_search):
        self.keyword = keyword_search
        self.semantic = semantic_search
        self.cache = {}

    def _cache_key(self, query: str) -> str:
        return hashlib.md5(query.encode()).hexdigest()

    def search(self, query: str, top_k: int = 10):
        key = self._cache_key(query)

        if key in self.cache:
            return self.cache[key][:top_k]

        # Cache miss - run search
        result = self._hybrid_search(query, top_k * 2)
        self.cache[key] = result

        return result[:top_k]
```

---

## Summary: Hybrid Search Recipe

```python
class ProductionHybridSearch:
    """
    Complete hybrid search implementation.
    """
    def __init__(
        self,
        embedding_model,
        keyword_index,
        vector_index,
        alpha: float = 0.5
    ):
        self.model = embedding_model
        self.keyword = keyword_index
        self.vector = vector_index
        self.alpha = alpha

    def search(self, query: str, top_k: int = 10) -> list:
        # 1. Embed query
        query_embedding = self.model.encode(query)

        # 2. Parallel search (in production, use async)
        keyword_results = self.keyword.search(query, top_k=top_k * 2)
        vector_results = self.vector.search(query_embedding, top_k=top_k * 2)

        # 3. Fusion
        fused = reciprocal_rank_fusion([
            [r['id'] for r in keyword_results],
            [r['id'] for r in vector_results]
        ])

        # 4. Fetch full documents
        return self._fetch_documents([doc_id for doc_id, _ in fused[:top_k]])
```

---

## Key Insights

1. **Hybrid search combines strengths** of keyword and semantic approaches
2. **RRF is robust** — doesn't require score normalization
3. **Alpha tuning matters** — test on your data
4. **Query-dependent fusion** can improve further
5. **Parallel execution** keeps latency low
6. **Most production systems** use hybrid search

---

## Conclusion

Congratulations! You've completed the Vector Embeddings & Semantic Search guide.

You now understand:
- How vectors represent meaning
- How embeddings are created and evaluated
- How to build semantic search systems
- How to measure and improve quality
- Production patterns for real-world applications

The field evolves rapidly. Stay current by:
- Following the MTEB leaderboard for new models
- Experimenting with your specific use case
- Measuring everything

Happy searching!

---

*Return to [Table of Contents](../README.md)*
