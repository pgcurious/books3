# Chapter 11: Vector Databases

## Storage and Retrieval at Scale

---

## Why Vector Databases?

Our simple implementation from Chapter 10 has a problem:

```python
# Linear search: O(n) comparisons
for embedding in all_embeddings:
    similarity = cosine_similarity(query, embedding)
```

With 1 million documents at 10ms per search, that's fine.
With 100 million documents, it takes 1000× longer.

**Vector databases solve this with Approximate Nearest Neighbor (ANN) algorithms.**

---

## The ANN Trade-off

Exact nearest neighbor search requires checking every vector. ANN algorithms trade a small accuracy loss for massive speed gains:

| Documents | Exact Search | ANN Search | Recall |
|-----------|-------------|------------|--------|
| 1M | 100ms | 5ms | 99% |
| 10M | 1s | 10ms | 98% |
| 100M | 10s | 20ms | 97% |
| 1B | 100s | 50ms | 95% |

"Recall" means: Of the true top-10, how many did we actually find?

---

## ANN Index Structures

### 1. HNSW (Hierarchical Navigable Small World)

The most popular algorithm. Think of it as a multi-level graph:

```
Level 2:    A ─────────────────── Z
            │                     │
Level 1:    A ──── M ──── Q ──── Z
            │      │      │      │
Level 0:    A─B─C─D─M─N─O─P─Q─R─S─Z
```

Search starts at the top level (sparse, long jumps) and descends to bottom level (dense, precise).

**Pros**: Fast, high recall, works well for cosine similarity
**Cons**: Memory-intensive, slow inserts

### 2. IVF (Inverted File Index)

Divides the space into clusters:

```
┌─────────┐  ┌─────────┐  ┌─────────┐
│Cluster 1│  │Cluster 2│  │Cluster 3│
│ ●  ●    │  │  ●  ●   │  │   ●     │
│   ●  ●  │  │ ●    ●  │  │  ●  ●   │
│ ●       │  │   ●     │  │    ●    │
└─────────┘  └─────────┘  └─────────┘
```

Search only the most relevant clusters, not all vectors.

**Pros**: Memory-efficient, supports disk storage
**Cons**: Requires training, cluster quality matters

### 3. Product Quantization (PQ)

Compresses vectors by dividing into sub-vectors:

```
Original: [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]
          └──────┘  └──────┘  └──────┘  └──────┘
          subvec1   subvec2   subvec3   subvec4

Each sub-vector → lookup table → compressed code
```

Reduces memory 4-64× with ~5-10% accuracy loss.

---

## Popular Vector Databases

### Comparison Matrix

| Database | Open Source | Managed | Best For |
|----------|------------|---------|----------|
| Pinecone | No | Yes | Serverless, easy start |
| Weaviate | Yes | Yes | GraphQL, modules |
| Qdrant | Yes | Yes | Performance, filtering |
| Milvus | Yes | Yes | Large scale, flexibility |
| Chroma | Yes | No | Local development |
| pgvector | Yes | Via Postgres | Existing Postgres users |

---

## Pinecone Example

Fully managed, easiest to start:

```python
from pinecone import Pinecone

# Initialize
pc = Pinecone(api_key="your-api-key")

# Create index
pc.create_index(
    name="semantic-search",
    dimension=768,
    metric="cosine",
    spec={"serverless": {"cloud": "aws", "region": "us-east-1"}}
)

index = pc.Index("semantic-search")

# Upsert vectors
index.upsert(vectors=[
    {
        "id": "doc1",
        "values": [0.1, 0.2, ...],  # 768 dimensions
        "metadata": {"category": "tech", "date": "2024-01-15"}
    },
    {
        "id": "doc2",
        "values": [0.3, 0.4, ...],
        "metadata": {"category": "science", "date": "2024-01-16"}
    }
])

# Query with filter
results = index.query(
    vector=[0.15, 0.25, ...],
    top_k=5,
    filter={"category": {"$eq": "tech"}},
    include_metadata=True
)

for match in results.matches:
    print(f"{match.id}: {match.score}")
```

---

## Qdrant Example

Open source, high performance:

```python
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct

# Connect (local or cloud)
client = QdrantClient(host="localhost", port=6333)

# Create collection
client.create_collection(
    collection_name="documents",
    vectors_config=VectorParams(
        size=768,
        distance=Distance.COSINE
    )
)

# Add vectors
client.upsert(
    collection_name="documents",
    points=[
        PointStruct(
            id=1,
            vector=[0.1, 0.2, ...],
            payload={"text": "Machine learning intro", "category": "AI"}
        ),
        PointStruct(
            id=2,
            vector=[0.3, 0.4, ...],
            payload={"text": "Web development basics", "category": "web"}
        )
    ]
)

# Search with filter
results = client.search(
    collection_name="documents",
    query_vector=[0.15, 0.25, ...],
    query_filter={
        "must": [{"key": "category", "match": {"value": "AI"}}]
    },
    limit=5
)
```

---

## pgvector Example

Vector search in PostgreSQL:

```sql
-- Enable extension
CREATE EXTENSION vector;

-- Create table with vector column
CREATE TABLE documents (
    id SERIAL PRIMARY KEY,
    content TEXT,
    embedding vector(768)
);

-- Add index for fast search
CREATE INDEX ON documents
USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);

-- Insert document
INSERT INTO documents (content, embedding)
VALUES ('Machine learning basics', '[0.1, 0.2, ...]');

-- Search
SELECT content, 1 - (embedding <=> '[0.15, 0.25, ...]') AS similarity
FROM documents
ORDER BY embedding <=> '[0.15, 0.25, ...]'
LIMIT 5;
```

Python with SQLAlchemy:

```python
from sqlalchemy import create_engine, Column, Integer, String
from sqlalchemy.orm import declarative_base
from pgvector.sqlalchemy import Vector

Base = declarative_base()

class Document(Base):
    __tablename__ = 'documents'
    id = Column(Integer, primary_key=True)
    content = Column(String)
    embedding = Column(Vector(768))

# Query
from sqlalchemy.orm import Session

with Session(engine) as session:
    results = session.query(Document).order_by(
        Document.embedding.cosine_distance([0.15, 0.25, ...])
    ).limit(5).all()
```

---

## Chroma Example

Perfect for local development:

```python
import chromadb
from chromadb.utils import embedding_functions

# Create client
client = chromadb.Client()

# Use built-in embedding function
embedding_fn = embedding_functions.SentenceTransformerEmbeddingFunction(
    model_name="all-MiniLM-L6-v2"
)

# Create collection
collection = client.create_collection(
    name="documents",
    embedding_function=embedding_fn
)

# Add documents (embeddings generated automatically)
collection.add(
    documents=[
        "Machine learning is fascinating",
        "Web development with JavaScript",
        "Data science fundamentals"
    ],
    metadatas=[
        {"category": "AI"},
        {"category": "web"},
        {"category": "data"}
    ],
    ids=["doc1", "doc2", "doc3"]
)

# Query (embedding generated automatically)
results = collection.query(
    query_texts=["artificial intelligence"],
    n_results=2,
    where={"category": "AI"}
)
```

---

## Choosing a Vector Database

### Decision Framework

```
Start Here
    │
    ▼
Do you need a managed service?
    │
    ├─ Yes ──▶ Budget sensitive?
    │              │
    │              ├─ Yes ──▶ Qdrant Cloud / Weaviate Cloud
    │              └─ No ───▶ Pinecone (easiest)
    │
    └─ No ───▶ Already using PostgreSQL?
                   │
                   ├─ Yes ──▶ pgvector
                   │
                   └─ No ───▶ Scale?
                                │
                                ├─ Small (<1M) ──▶ Chroma
                                ├─ Medium (<100M) ─▶ Qdrant
                                └─ Large (>100M) ──▶ Milvus
```

### Factors to Consider

| Factor | Best Options |
|--------|-------------|
| Easiest start | Pinecone, Chroma |
| Best performance | Qdrant, Milvus |
| Existing Postgres | pgvector |
| GraphQL API | Weaviate |
| Cost-sensitive | Self-hosted Qdrant/Milvus |
| Hybrid search | Weaviate, Qdrant |

---

## Index Configuration

### HNSW Parameters

```python
# Qdrant example
from qdrant_client.models import HnswConfigDiff

client.update_collection(
    collection_name="documents",
    hnsw_config=HnswConfigDiff(
        m=16,           # Connections per node (higher = better recall, more memory)
        ef_construct=100  # Build-time search depth (higher = better index, slower build)
    )
)

# Search-time parameter
results = client.search(
    collection_name="documents",
    query_vector=query,
    search_params={"ef": 128}  # Higher = better recall, slower search
)
```

### Trade-off Guide

| Parameter | Lower Value | Higher Value |
|-----------|------------|--------------|
| m | Faster, less memory | Better recall |
| ef_construct | Faster indexing | Better index quality |
| ef (search) | Faster search | Better recall |

---

## Scaling Strategies

### Horizontal Scaling

```
                    Load Balancer
                         │
         ┌───────────────┼───────────────┐
         │               │               │
    ┌────┴────┐    ┌────┴────┐    ┌────┴────┐
    │ Shard 1 │    │ Shard 2 │    │ Shard 3 │
    │  docs   │    │  docs   │    │  docs   │
    │ 0-33%   │    │ 33-66%  │    │ 66-100% │
    └─────────┘    └─────────┘    └─────────┘
```

Query goes to all shards, results merged.

### Replication

```
         Write ──▶ Primary
                      │
              ┌───────┼───────┐
              │       │       │
              ▼       ▼       ▼
          Replica  Replica  Replica
           Read     Read     Read
```

Reads can go to any replica for higher throughput.

---

## Common Patterns

### Pattern 1: Two-Stage Retrieval

```python
# Stage 1: Fast ANN retrieval
candidates = vector_db.search(query_embedding, top_k=100)

# Stage 2: Precise re-ranking
reranked = cross_encoder.rerank(query, candidates)
final_results = reranked[:10]
```

### Pattern 2: Filtered Search

```python
# Pre-filtering (filter then search within results)
results = vector_db.search(
    query_embedding,
    filter={"date": {"$gte": "2024-01-01"}},
    top_k=10
)

# Post-filtering (search then filter results)
candidates = vector_db.search(query_embedding, top_k=100)
results = [r for r in candidates if r.metadata["date"] >= "2024-01-01"][:10]
```

Pre-filtering is more efficient when filters are selective.

### Pattern 3: Namespace Isolation

```python
# Pinecone namespaces
index.upsert(vectors=user_a_docs, namespace="user_a")
index.upsert(vectors=user_b_docs, namespace="user_b")

# Query only user_a's documents
results = index.query(vector=query, namespace="user_a", top_k=10)
```

---

## Key Insights

1. **ANN algorithms** trade small accuracy loss for massive speed gains
2. **HNSW** is most common — fast queries, memory-intensive
3. **Choose based on scale**: Chroma < pgvector < Qdrant < Milvus
4. **Managed services** (Pinecone) trade cost for convenience
5. **Index parameters** control recall/speed trade-off
6. **Two-stage retrieval** combines ANN speed with reranker precision

---

## What's Next?

We've built a complete semantic search system. But how do we know if it's good? Part 5 covers quality factors — what makes embeddings good, how to measure search quality, and how to improve results.

---

*Continue to [Part 5: Embedding Quality](../PART-5-QUALITY-FACTORS/12-embedding-quality.md)*
