# Chapter 14: Improving Results

## Techniques to Boost Search Quality

---

## The Improvement Toolbox

Search quality can be improved at every stage:

```
Query → [Query Enhancement] →
        [Retrieval] →
        [Re-ranking] →
        [Post-processing] → Results
```

Let's explore techniques for each stage.

---

## Stage 1: Query Enhancement

### Query Expansion

Add related terms to capture more relevant documents:

```python
def expand_query_with_synonyms(query: str, synonym_map: dict) -> str:
    """Add synonyms to query."""
    words = query.lower().split()
    expanded = []

    for word in words:
        expanded.append(word)
        if word in synonym_map:
            expanded.extend(synonym_map[word])

    return ' '.join(expanded)

# Example
synonyms = {
    'fast': ['quick', 'rapid', 'speedy'],
    'car': ['automobile', 'vehicle'],
}

query = "fast car"
expanded = expand_query_with_synonyms(query, synonyms)
# "fast quick rapid speedy car automobile vehicle"
```

### Query Rewriting with LLMs

```python
def rewrite_query(query: str, context: str = None) -> list:
    """Use LLM to generate query variations."""
    prompt = f"""
    Generate 3 alternative ways to search for: "{query}"
    Return only the queries, one per line.
    """

    # Call your LLM
    response = llm.generate(prompt)
    variations = response.strip().split('\n')

    return [query] + variations

# Example
variations = rewrite_query("python sort list")
# ["python sort list",
#  "how to sort a list in python",
#  "python list sorting methods",
#  "arrange list elements python"]
```

### Hypothetical Document Embedding (HyDE)

Generate a hypothetical answer, then search for similar documents:

```python
def hyde_search(query: str, search_engine, llm) -> list:
    """
    HyDE: Hypothetical Document Embedding.
    """
    # Generate hypothetical answer
    prompt = f"Write a short passage that answers: {query}"
    hypothetical_doc = llm.generate(prompt)

    # Embed the hypothetical document (not the query!)
    hyde_embedding = embed(hypothetical_doc)

    # Search using this embedding
    results = search_engine.search_by_embedding(hyde_embedding)

    return results

# This often works better than embedding the query directly
# because the hypothetical doc is more similar to real docs
```

---

## Stage 2: Retrieval Improvements

### Hybrid Search

Combine semantic and keyword search:

```python
def hybrid_search(
    query: str,
    semantic_engine,
    keyword_engine,
    alpha: float = 0.7  # Weight for semantic
) -> list:
    """
    Combine semantic and keyword search results.
    """
    # Get results from both
    semantic_results = semantic_engine.search(query, top_k=50)
    keyword_results = keyword_engine.search(query, top_k=50)

    # Normalize scores to [0, 1]
    semantic_scores = normalize_scores(semantic_results)
    keyword_scores = normalize_scores(keyword_results)

    # Combine scores
    combined = {}
    for doc_id, score in semantic_scores.items():
        combined[doc_id] = alpha * score

    for doc_id, score in keyword_scores.items():
        if doc_id in combined:
            combined[doc_id] += (1 - alpha) * score
        else:
            combined[doc_id] = (1 - alpha) * score

    # Sort by combined score
    ranked = sorted(combined.items(), key=lambda x: x[1], reverse=True)
    return ranked

def normalize_scores(results: list) -> dict:
    """Min-max normalization."""
    if not results:
        return {}

    scores = [r['score'] for r in results]
    min_s, max_s = min(scores), max(scores)
    range_s = max_s - min_s or 1

    return {
        r['id']: (r['score'] - min_s) / range_s
        for r in results
    }
```

### Multi-Vector Retrieval

Use multiple embeddings per document:

```python
class MultiVectorIndex:
    """
    Store multiple vectors per document for better retrieval.
    """
    def __init__(self, model):
        self.model = model
        self.vectors = []  # (doc_id, vector, vector_type)
        self.documents = {}

    def add_document(self, doc_id: str, document: dict):
        """Add document with multiple vector representations."""
        self.documents[doc_id] = document

        # Vector 1: Full document
        doc_emb = self.model.encode(document['text'])
        self.vectors.append((doc_id, doc_emb, 'full'))

        # Vector 2: Title/summary
        if 'title' in document:
            title_emb = self.model.encode(document['title'])
            self.vectors.append((doc_id, title_emb, 'title'))

        # Vector 3: Key sentences
        key_sentences = extract_key_sentences(document['text'])
        for sent in key_sentences:
            sent_emb = self.model.encode(sent)
            self.vectors.append((doc_id, sent_emb, 'sentence'))

    def search(self, query: str, top_k: int = 10) -> list:
        """Search across all vectors, deduplicate by doc_id."""
        query_emb = self.model.encode(query)

        # Score all vectors
        scores = []
        for doc_id, vec, vec_type in self.vectors:
            sim = cosine_similarity(query_emb, vec)
            scores.append((doc_id, sim, vec_type))

        # Take max score per document
        doc_scores = {}
        for doc_id, sim, _ in scores:
            if doc_id not in doc_scores or sim > doc_scores[doc_id]:
                doc_scores[doc_id] = sim

        # Sort and return
        ranked = sorted(doc_scores.items(), key=lambda x: x[1], reverse=True)
        return [{'id': doc_id, 'score': score} for doc_id, score in ranked[:top_k]]
```

---

## Stage 3: Re-ranking

### Cross-Encoder Re-ranking

The most effective quality improvement:

```python
from sentence_transformers import CrossEncoder

class RerankedSearch:
    def __init__(self, retriever, reranker_model='cross-encoder/ms-marco-MiniLM-L-6-v2'):
        self.retriever = retriever
        self.reranker = CrossEncoder(reranker_model)

    def search(self, query: str, top_k: int = 10, rerank_top_n: int = 50):
        # Stage 1: Fast retrieval
        candidates = self.retriever.search(query, top_k=rerank_top_n)

        # Stage 2: Precise re-ranking
        pairs = [(query, c['text']) for c in candidates]
        rerank_scores = self.reranker.predict(pairs)

        # Combine and sort
        for i, score in enumerate(rerank_scores):
            candidates[i]['rerank_score'] = float(score)

        candidates.sort(key=lambda x: x['rerank_score'], reverse=True)
        return candidates[:top_k]

# Typical improvement: 10-30% better NDCG
```

### Diversity Re-ranking

Avoid redundant results:

```python
def maximal_marginal_relevance(
    query_emb,
    doc_embeddings: list,
    documents: list,
    lambda_param: float = 0.5,
    top_k: int = 10
) -> list:
    """
    MMR: Balance relevance and diversity.

    lambda_param: 1.0 = pure relevance, 0.0 = pure diversity
    """
    selected = []
    remaining = list(range(len(documents)))

    while len(selected) < top_k and remaining:
        best_score = -float('inf')
        best_idx = None

        for idx in remaining:
            # Relevance to query
            relevance = cosine_similarity(query_emb, doc_embeddings[idx])

            # Max similarity to already selected (diversity penalty)
            if selected:
                max_sim_to_selected = max(
                    cosine_similarity(doc_embeddings[idx], doc_embeddings[s])
                    for s in selected
                )
            else:
                max_sim_to_selected = 0

            # MMR score
            mmr_score = lambda_param * relevance - (1 - lambda_param) * max_sim_to_selected

            if mmr_score > best_score:
                best_score = mmr_score
                best_idx = idx

        selected.append(best_idx)
        remaining.remove(best_idx)

    return [documents[i] for i in selected]
```

---

## Stage 4: Post-processing

### Filtering and Boosting

```python
def post_process_results(
    results: list,
    filters: dict = None,
    boost_rules: list = None
) -> list:
    """
    Apply business logic to search results.
    """
    processed = results.copy()

    # Apply filters
    if filters:
        processed = [
            r for r in processed
            if all(r.get(k) == v for k, v in filters.items())
        ]

    # Apply boosts
    if boost_rules:
        for result in processed:
            for rule in boost_rules:
                if rule['condition'](result):
                    result['score'] *= rule['boost_factor']

        processed.sort(key=lambda x: x['score'], reverse=True)

    return processed

# Example boost rules
boost_rules = [
    {
        'condition': lambda r: r.get('is_verified', False),
        'boost_factor': 1.2  # 20% boost for verified content
    },
    {
        'condition': lambda r: r.get('recency_days', 365) < 30,
        'boost_factor': 1.1  # 10% boost for recent content
    },
]
```

### Result Clustering

Group similar results:

```python
from sklearn.cluster import KMeans

def cluster_results(results: list, n_clusters: int = 3) -> dict:
    """Group results by topic."""
    embeddings = [r['embedding'] for r in results]

    # Cluster
    kmeans = KMeans(n_clusters=n_clusters)
    labels = kmeans.fit_predict(embeddings)

    # Group by cluster
    clusters = {}
    for i, label in enumerate(labels):
        if label not in clusters:
            clusters[label] = []
        clusters[label].append(results[i])

    return clusters

# Present one result from each cluster for diversity
```

---

## Feedback Loop: Learning from Users

### Implicit Feedback

```python
class FeedbackCollector:
    def __init__(self):
        self.feedback_log = []

    def log_search(self, query: str, results: list, clicked_ids: list):
        """Log which results were clicked."""
        self.feedback_log.append({
            'query': query,
            'results': [r['id'] for r in results],
            'clicked': clicked_ids,
            'timestamp': datetime.now()
        })

    def get_training_data(self) -> list:
        """Convert feedback to training pairs."""
        training_data = []

        for log in self.feedback_log:
            query = log['query']
            for clicked_id in log['clicked']:
                # Positive pair
                training_data.append({
                    'query': query,
                    'document': clicked_id,
                    'label': 1
                })

            # Negative pairs: shown but not clicked
            for result_id in log['results']:
                if result_id not in log['clicked']:
                    training_data.append({
                        'query': query,
                        'document': result_id,
                        'label': 0
                    })

        return training_data
```

### A/B Testing

```python
class ABTestSearch:
    def __init__(self, engine_a, engine_b):
        self.engine_a = engine_a
        self.engine_b = engine_b
        self.metrics = {'a': [], 'b': []}

    def search(self, query: str, user_id: str):
        # Deterministic assignment based on user
        variant = 'a' if hash(user_id) % 2 == 0 else 'b'

        if variant == 'a':
            return self.engine_a.search(query), 'a'
        else:
            return self.engine_b.search(query), 'b'

    def log_click(self, variant: str, position: int):
        # Track click position for MRR calculation
        self.metrics[variant].append(1 / position)

    def get_results(self):
        mrr_a = sum(self.metrics['a']) / len(self.metrics['a'])
        mrr_b = sum(self.metrics['b']) / len(self.metrics['b'])

        return {'mrr_a': mrr_a, 'mrr_b': mrr_b}
```

---

## Quick Wins Checklist

In order of impact:

1. **Add re-ranking** — Cross-encoders give 10-30% improvement
2. **Implement hybrid search** — Catches keyword-dependent queries
3. **Tune chunk size** — Often overlooked, big impact
4. **Try better embedding model** — Check MTEB leaderboard
5. **Add query expansion** — Helps with vocabulary mismatch
6. **Filter and boost** — Apply domain-specific business logic

---

## Key Insights

1. **Query enhancement** expands search coverage
2. **Hybrid search** combines semantic and keyword strengths
3. **Re-ranking** is the single most impactful improvement
4. **MMR** ensures diverse results
5. **User feedback** enables continuous improvement
6. **A/B testing** validates changes in production

---

## What's Next?

We've covered how to improve results. The final part addresses practical patterns for production systems — chunking strategies and hybrid search implementations.

---

*Continue to [Part 6: Chunking Strategies](../PART-6-PRACTICAL-PATTERNS/15-chunking-strategies.md)*
