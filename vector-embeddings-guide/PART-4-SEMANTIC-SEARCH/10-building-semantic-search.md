# Chapter 10: Building Semantic Search

## A Complete Implementation Guide

---

## The Architecture

A semantic search system has three main components:

```
┌─────────────────────────────────────────────────────────────┐
│                    INGESTION PIPELINE                        │
│  Documents → Chunk → Embed → Store                          │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    VECTOR STORAGE                            │
│  Embeddings + Metadata + Index                               │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    QUERY PIPELINE                            │
│  Query → Embed → Search → Rank → Return                     │
└─────────────────────────────────────────────────────────────┘
```

Let's build each component.

---

## Step 1: Choose Your Embedding Model

```python
from sentence_transformers import SentenceTransformer

# Options by quality/speed trade-off:
models = {
    "fast": "all-MiniLM-L6-v2",        # 384 dim, very fast
    "balanced": "all-mpnet-base-v2",   # 768 dim, good balance
    "quality": "BAAI/bge-large-en-v1.5" # 1024 dim, best quality
}

# For this tutorial, we'll use the balanced option
model = SentenceTransformer("all-mpnet-base-v2")

def embed_text(text: str) -> list:
    """Convert text to embedding vector."""
    return model.encode(text).tolist()

def embed_batch(texts: list) -> list:
    """Embed multiple texts efficiently."""
    return model.encode(texts).tolist()
```

---

## Step 2: Document Processing

### Chunking Strategy

Documents need to be split into searchable chunks:

```python
def simple_chunk(text: str, chunk_size: int = 500, overlap: int = 50) -> list:
    """
    Split text into overlapping chunks.

    Args:
        text: The document text
        chunk_size: Target characters per chunk
        overlap: Characters to overlap between chunks
    """
    chunks = []
    start = 0

    while start < len(text):
        end = start + chunk_size

        # Try to break at sentence boundary
        if end < len(text):
            # Look for period, question mark, or exclamation
            for punct in ['. ', '? ', '! ', '\n\n']:
                last_punct = text[start:end].rfind(punct)
                if last_punct != -1:
                    end = start + last_punct + len(punct)
                    break

        chunk = text[start:end].strip()
        if chunk:
            chunks.append({
                "text": chunk,
                "start": start,
                "end": end
            })

        start = end - overlap

    return chunks

# Example
document = """
Machine learning is a subset of artificial intelligence.
It enables computers to learn from data without explicit programming.

There are three main types: supervised, unsupervised, and reinforcement learning.
Each has different use cases and requirements.

Deep learning uses neural networks with many layers.
It has revolutionized image recognition and natural language processing.
"""

chunks = simple_chunk(document, chunk_size=200, overlap=30)
for i, chunk in enumerate(chunks):
    print(f"Chunk {i}: {chunk['text'][:50]}...")
```

---

## Step 3: Vector Storage

### Option A: In-Memory (Small Scale)

```python
import numpy as np
from typing import List, Dict, Tuple

class SimpleVectorStore:
    def __init__(self):
        self.embeddings = []
        self.documents = []

    def add(self, embedding: list, document: dict):
        self.embeddings.append(np.array(embedding))
        self.documents.append(document)

    def search(self, query_embedding: list, top_k: int = 5) -> List[Tuple[dict, float]]:
        query = np.array(query_embedding)

        # Compute cosine similarities
        scores = []
        for i, emb in enumerate(self.embeddings):
            similarity = np.dot(query, emb) / (
                np.linalg.norm(query) * np.linalg.norm(emb)
            )
            scores.append((i, similarity))

        # Sort by similarity
        scores.sort(key=lambda x: x[1], reverse=True)

        # Return top results
        results = []
        for idx, score in scores[:top_k]:
            results.append((self.documents[idx], score))

        return results
```

### Option B: FAISS (Medium Scale)

```python
import faiss
import numpy as np

class FAISSVectorStore:
    def __init__(self, dimension: int):
        self.dimension = dimension
        self.index = faiss.IndexFlatIP(dimension)  # Inner product
        self.documents = []

    def add(self, embeddings: np.ndarray, documents: list):
        # Normalize for cosine similarity
        faiss.normalize_L2(embeddings)
        self.index.add(embeddings)
        self.documents.extend(documents)

    def search(self, query_embedding: np.ndarray, top_k: int = 5):
        # Normalize query
        query = query_embedding.reshape(1, -1).astype('float32')
        faiss.normalize_L2(query)

        # Search
        scores, indices = self.index.search(query, top_k)

        results = []
        for idx, score in zip(indices[0], scores[0]):
            if idx != -1:  # Valid result
                results.append((self.documents[idx], float(score)))

        return results
```

### Option C: Production Vector Database

See Chapter 11 for detailed coverage of Pinecone, Weaviate, Qdrant, etc.

---

## Step 4: Ingestion Pipeline

```python
class SemanticSearchEngine:
    def __init__(self, model_name: str = "all-mpnet-base-v2"):
        self.model = SentenceTransformer(model_name)
        self.dimension = self.model.get_sentence_embedding_dimension()
        self.store = FAISSVectorStore(self.dimension)

    def ingest(self, documents: List[Dict], batch_size: int = 32):
        """
        Ingest documents into the search engine.

        Args:
            documents: List of {"id": ..., "text": ..., "metadata": ...}
            batch_size: Number of documents to embed at once
        """
        all_chunks = []
        all_metadata = []

        # Process each document
        for doc in documents:
            chunks = simple_chunk(doc["text"])

            for i, chunk in enumerate(chunks):
                all_chunks.append(chunk["text"])
                all_metadata.append({
                    "doc_id": doc["id"],
                    "chunk_index": i,
                    "text": chunk["text"],
                    **doc.get("metadata", {})
                })

        # Embed in batches
        all_embeddings = []
        for i in range(0, len(all_chunks), batch_size):
            batch = all_chunks[i:i+batch_size]
            embeddings = self.model.encode(batch)
            all_embeddings.extend(embeddings)

        # Add to store
        embeddings_array = np.array(all_embeddings).astype('float32')
        self.store.add(embeddings_array, all_metadata)

        print(f"Ingested {len(documents)} documents ({len(all_chunks)} chunks)")

    def search(self, query: str, top_k: int = 5) -> List[Dict]:
        """
        Search for relevant documents.

        Args:
            query: Search query
            top_k: Number of results to return
        """
        # Embed query
        query_embedding = self.model.encode(query).astype('float32')

        # Search
        results = self.store.search(query_embedding, top_k)

        # Format results
        formatted = []
        for metadata, score in results:
            formatted.append({
                "text": metadata["text"],
                "score": score,
                "doc_id": metadata["doc_id"],
                "chunk_index": metadata["chunk_index"]
            })

        return formatted
```

---

## Step 5: Putting It All Together

```python
# Initialize
engine = SemanticSearchEngine()

# Sample documents
documents = [
    {
        "id": "doc1",
        "text": """
        Python is a high-level programming language known for its simplicity.
        It's widely used in web development, data science, and automation.
        Python's syntax emphasizes readability and reduces code complexity.
        """,
        "metadata": {"category": "programming"}
    },
    {
        "id": "doc2",
        "text": """
        Machine learning enables computers to learn from data.
        Common algorithms include decision trees, neural networks, and SVMs.
        Deep learning is a subset that uses multi-layer neural networks.
        """,
        "metadata": {"category": "AI"}
    },
    {
        "id": "doc3",
        "text": """
        JavaScript powers interactive web applications.
        It runs in browsers and on servers via Node.js.
        Modern JavaScript includes features like async/await and modules.
        """,
        "metadata": {"category": "programming"}
    }
]

# Ingest
engine.ingest(documents)

# Search
queries = [
    "How do I learn Python?",
    "What is deep learning?",
    "Frontend web development",
]

for query in queries:
    print(f"\nQuery: {query}")
    results = engine.search(query, top_k=2)
    for i, result in enumerate(results):
        print(f"  {i+1}. [{result['score']:.3f}] {result['text'][:60]}...")
```

Output:
```
Query: How do I learn Python?
  1. [0.723] Python is a high-level programming language known for its s...
  2. [0.412] JavaScript powers interactive web applications. It runs in...

Query: What is deep learning?
  1. [0.856] Machine learning enables computers to learn from data. Com...
  2. [0.234] Python is a high-level programming language known for its s...

Query: Frontend web development
  1. [0.678] JavaScript powers interactive web applications. It runs in...
  2. [0.321] Python is a high-level programming language known for its s...
```

---

## Step 6: Adding Filters

Real applications need metadata filtering:

```python
def search_with_filters(
    self,
    query: str,
    filters: Dict = None,
    top_k: int = 5
) -> List[Dict]:
    """
    Search with metadata filters.

    Args:
        query: Search query
        filters: {"field": "value"} to filter by
        top_k: Number of results
    """
    # Get more results than needed (we'll filter)
    results = self.search(query, top_k=top_k * 3)

    # Apply filters
    if filters:
        filtered = []
        for result in results:
            match = all(
                result.get(key) == value
                for key, value in filters.items()
            )
            if match:
                filtered.append(result)
        results = filtered

    return results[:top_k]

# Usage
results = engine.search_with_filters(
    query="programming languages",
    filters={"category": "programming"},
    top_k=2
)
```

---

## Step 7: Improving Result Quality

### Re-ranking

First-pass retrieval is fast but imprecise. Re-ranking improves quality:

```python
from sentence_transformers import CrossEncoder

class SearchEngineWithReranking(SemanticSearchEngine):
    def __init__(self):
        super().__init__()
        # Cross-encoder for re-ranking
        self.reranker = CrossEncoder('cross-encoder/ms-marco-MiniLM-L-6-v2')

    def search_with_rerank(
        self,
        query: str,
        top_k: int = 5,
        rerank_top_n: int = 20
    ):
        # Initial retrieval (get more candidates)
        candidates = self.search(query, top_k=rerank_top_n)

        # Re-rank with cross-encoder
        pairs = [(query, c["text"]) for c in candidates]
        rerank_scores = self.reranker.predict(pairs)

        # Sort by re-rank score
        for i, score in enumerate(rerank_scores):
            candidates[i]["rerank_score"] = float(score)

        candidates.sort(key=lambda x: x["rerank_score"], reverse=True)

        return candidates[:top_k]
```

### Query Expansion

Expand queries to capture more relevant results:

```python
def expand_query(query: str, model) -> List[str]:
    """
    Generate query variations for better recall.
    """
    # Simple approach: use the model to find similar phrases
    variations = [query]

    # Add common reformulations
    if "how to" in query.lower():
        variations.append(query.replace("how to", "guide for"))
        variations.append(query.replace("how to", "tutorial on"))

    return variations

def search_with_expansion(self, query: str, top_k: int = 5):
    variations = expand_query(query, self.model)

    all_results = {}
    for q in variations:
        results = self.search(q, top_k=top_k)
        for r in results:
            key = r["doc_id"] + str(r["chunk_index"])
            if key not in all_results or r["score"] > all_results[key]["score"]:
                all_results[key] = r

    return sorted(all_results.values(), key=lambda x: x["score"], reverse=True)[:top_k]
```

---

## Complete Example

```python
# Full working example
from sentence_transformers import SentenceTransformer
import numpy as np

class ProductionSemanticSearch:
    """A production-ready semantic search implementation."""

    def __init__(self, model_name="all-MiniLM-L6-v2"):
        self.model = SentenceTransformer(model_name)
        self.embeddings = []
        self.documents = []

    def add_documents(self, docs: list):
        """Add documents to the index."""
        texts = [d["text"] for d in docs]
        embeddings = self.model.encode(texts, normalize_embeddings=True)

        self.embeddings.extend(embeddings)
        self.documents.extend(docs)

    def search(self, query: str, k: int = 5) -> list:
        """Search for relevant documents."""
        query_emb = self.model.encode(query, normalize_embeddings=True)

        # Compute similarities
        similarities = np.dot(self.embeddings, query_emb)

        # Get top-k indices
        top_indices = np.argsort(similarities)[-k:][::-1]

        return [
            {"document": self.documents[i], "score": float(similarities[i])}
            for i in top_indices
        ]

# Usage
search = ProductionSemanticSearch()

search.add_documents([
    {"id": 1, "text": "Python is great for machine learning"},
    {"id": 2, "text": "JavaScript powers the modern web"},
    {"id": 3, "text": "Neural networks learn from data"},
])

results = search.search("AI and deep learning")
for r in results:
    print(f"{r['score']:.3f}: {r['document']['text']}")
```

---

## Key Insights

1. **Architecture**: Ingest → Store → Query is the standard pattern
2. **Chunking**: Documents must be split into searchable units
3. **Batching**: Always embed in batches for efficiency
4. **Storage**: Start simple, scale to vector databases as needed
5. **Re-ranking**: Cross-encoders improve precision significantly
6. **Filtering**: Metadata filters complement semantic search

---

## What's Next?

Our basic search works, but it won't scale. The next chapter covers vector databases — specialized storage systems designed for billion-scale semantic search.

---

*Continue to [Chapter 11: Vector Databases](./11-vector-databases.md)*
