# Chapter 12: Embedding Quality

## What Makes Embeddings Good or Bad?

---

## The Quality Question

Not all embeddings are created equal. The same text embedded by different models produces different vectors — and different search results.

```python
# Same text, different models
text = "How do I reset my password?"

miniLM_embedding = miniLM.encode(text)    # 384 dimensions
mpnet_embedding = mpnet.encode(text)      # 768 dimensions
bge_embedding = bge.encode(text)          # 1024 dimensions

# All different! Some are "better" for certain tasks.
```

What determines quality?

---

## Factors Affecting Embedding Quality

### 1. Training Data

**Principle**: Embeddings reflect the data they were trained on.

| Training Data | Good For | Poor For |
|---------------|----------|----------|
| Wikipedia + Books | General knowledge | Medical, legal jargon |
| Scientific papers | Research search | Casual conversation |
| Customer support tickets | Support search | News articles |
| Code repositories | Code search | Natural language |

```python
# A general model vs domain-specific
general_model = SentenceTransformer('all-mpnet-base-v2')
legal_model = SentenceTransformer('legal-bert-base-uncased')  # Hypothetical

query = "breach of fiduciary duty"

# Legal model will likely produce better embeddings for legal search
```

### 2. Training Objective

Different training tasks produce different embedding spaces:

| Objective | What It Learns | Best For |
|-----------|---------------|----------|
| Masked Language Modeling | Word prediction | General NLU |
| Contrastive Learning | Similar vs dissimilar | Retrieval |
| Sentence Classification | Category boundaries | Classification |
| Question-Answer Pairs | Q-A matching | QA systems |

**Key insight**: Models trained with contrastive objectives (like sentence-transformers) are usually best for semantic search.

### 3. Model Architecture

| Architecture | Pros | Cons |
|--------------|------|------|
| Bi-encoder | Fast, scalable | Less precise |
| Cross-encoder | Very precise | Slow, can't pre-compute |
| Poly-encoder | Balance | Complex |

```python
# Bi-encoder: Encode query and documents independently
query_emb = model.encode(query)
doc_emb = model.encode(document)
similarity = cosine_similarity(query_emb, doc_emb)

# Cross-encoder: Encode query-document pair together
similarity = cross_encoder.predict([(query, document)])[0]
```

### 4. Embedding Dimensions

More dimensions can capture more nuance, but with diminishing returns:

```
Dimensions | Relative Quality (example benchmark)
-----------+-------------------------------------
    128    | 0.82
    256    | 0.91
    384    | 0.94
    512    | 0.96
    768    | 0.98
   1024    | 0.99
   1536    | 0.995
```

---

## Measuring Embedding Quality

### Intrinsic Evaluation: Similarity Benchmarks

Test if embeddings match human similarity judgments:

```python
# STS Benchmark: Human-rated sentence similarity
test_pairs = [
    ("A man is playing guitar", "A person is playing music", 4.2),
    ("A cat is sleeping", "A dog is running", 0.5),
]

# Compare model similarity to human rating
for sent1, sent2, human_score in test_pairs:
    emb1 = model.encode(sent1)
    emb2 = model.encode(sent2)
    model_score = cosine_similarity(emb1, emb2) * 5  # Scale to 0-5

    print(f"Human: {human_score}, Model: {model_score:.2f}")
```

### Extrinsic Evaluation: Task Performance

Measure on actual downstream tasks:

```python
# Retrieval task: Given query, find relevant documents
def evaluate_retrieval(model, queries, relevant_docs):
    hits = 0
    for query, relevant_ids in zip(queries, relevant_docs):
        query_emb = model.encode(query)
        results = search(query_emb, top_k=10)
        result_ids = [r['id'] for r in results]

        # Check if relevant docs are in results
        if any(rid in result_ids for rid in relevant_ids):
            hits += 1

    return hits / len(queries)  # Recall@10
```

---

## Common Quality Problems

### Problem 1: Domain Mismatch

```python
# General model on specialized domain
model = SentenceTransformer('all-mpnet-base-v2')

# Medical query
query = "differential diagnosis for dyspnea with JVD"
docs = ["shortness of breath with neck vein distension", ...]

# Model might not understand medical terminology well
```

**Solution**: Fine-tune on domain data or use domain-specific model.

### Problem 2: Length Mismatch

```python
# Short query vs long document
query = "python sort list"  # 3 words

document = """
Python provides multiple ways to sort lists. The sort() method
modifies the list in-place, while sorted() returns a new list.
You can customize sorting with the key parameter...
[500 more words]
"""

# Embedding of short text vs long text may not align well
```

**Solution**: Use asymmetric models or chunk documents appropriately.

### Problem 3: Semantic Drift

```python
# Query and document use same words differently
query = "apple stock price"  # Financial
document = "Store apple stock in cool, dry place"  # Fruit storage

# Embeddings might be similar due to word overlap
```

**Solution**: Use models with better contextual understanding, or add hybrid search.

### Problem 4: Negation Blindness

```python
# Many models struggle with negation
sent1 = "I love this product"
sent2 = "I don't love this product"

# Some models give these high similarity!
similarity = cosine_similarity(
    model.encode(sent1),
    model.encode(sent2)
)
# Might be 0.85+ despite opposite meaning
```

**Solution**: Test for negation handling, consider models trained on NLI tasks.

---

## Evaluating Models for Your Use Case

### Step 1: Create a Test Set

```python
# Collect query-document pairs from your domain
test_set = [
    {
        "query": "how to cancel subscription",
        "relevant": ["cancel-guide.md", "billing-faq.md"],
        "irrelevant": ["pricing.md", "features.md"]
    },
    # ... more examples
]
```

### Step 2: Define Metrics

```python
def evaluate_model(model, test_set):
    results = {
        'mrr': [],        # Mean Reciprocal Rank
        'recall_at_5': [],
        'recall_at_10': []
    }

    for test in test_set:
        query_emb = model.encode(test['query'])
        all_docs = test['relevant'] + test['irrelevant']

        # Rank documents
        doc_embs = model.encode([load_doc(d) for d in all_docs])
        similarities = cosine_similarity([query_emb], doc_embs)[0]
        ranking = sorted(zip(all_docs, similarities),
                        key=lambda x: x[1], reverse=True)

        # Calculate metrics
        for rank, (doc, _) in enumerate(ranking, 1):
            if doc in test['relevant']:
                results['mrr'].append(1 / rank)
                break

        top_5 = [doc for doc, _ in ranking[:5]]
        top_10 = [doc for doc, _ in ranking[:10]]

        results['recall_at_5'].append(
            len(set(top_5) & set(test['relevant'])) / len(test['relevant'])
        )
        results['recall_at_10'].append(
            len(set(top_10) & set(test['relevant'])) / len(test['relevant'])
        )

    return {k: sum(v)/len(v) for k, v in results.items()}
```

### Step 3: Compare Models

```python
models_to_test = [
    ('MiniLM', 'all-MiniLM-L6-v2'),
    ('MPNet', 'all-mpnet-base-v2'),
    ('BGE', 'BAAI/bge-base-en-v1.5'),
]

for name, model_id in models_to_test:
    model = SentenceTransformer(model_id)
    scores = evaluate_model(model, test_set)
    print(f"{name}: MRR={scores['mrr']:.3f}, R@10={scores['recall_at_10']:.3f}")
```

---

## Improving Embedding Quality

### Option 1: Choose a Better Base Model

```python
# Leaderboard resources:
# - MTEB (Massive Text Embedding Benchmark)
# - Hugging Face leaderboards

# Top performers change frequently, check current benchmarks
```

### Option 2: Fine-tune on Your Data

```python
from sentence_transformers import SentenceTransformer, InputExample, losses
from torch.utils.data import DataLoader

# Prepare training data
train_examples = [
    InputExample(texts=["query1", "relevant_doc1"]),
    InputExample(texts=["query2", "relevant_doc2"]),
    # ...
]

# Fine-tune
model = SentenceTransformer('all-mpnet-base-v2')
train_dataloader = DataLoader(train_examples, batch_size=16)
train_loss = losses.MultipleNegativesRankingLoss(model)

model.fit(
    train_objectives=[(train_dataloader, train_loss)],
    epochs=3,
    warmup_steps=100
)

model.save('fine-tuned-model')
```

### Option 3: Use Instruction-Tuned Models

Some models accept instructions to guide embedding:

```python
# BGE with instruction prefix
model = SentenceTransformer('BAAI/bge-large-en-v1.5')

# Add instruction for retrieval
query = "Represent this sentence for retrieval: " + user_query
query_emb = model.encode(query)
```

---

## Quality Checklist

Before deploying, verify:

- [ ] **Domain fit**: Model trained on similar data?
- [ ] **Benchmark scores**: Check MTEB or similar leaderboards
- [ ] **Negation handling**: Test with negative examples
- [ ] **Length handling**: Test short queries vs long documents
- [ ] **Speed requirements**: Latency acceptable for your use case?
- [ ] **Custom evaluation**: Tested on your specific task?

---

## Key Insights

1. **Training data determines domain fit** — general models may fail on specialized content
2. **Contrastive training** produces better retrieval embeddings
3. **Test on your data** — benchmark scores don't guarantee task performance
4. **Fine-tuning helps** — even small datasets can improve domain performance
5. **Watch for edge cases**: negation, length mismatch, semantic drift

---

## What's Next?

Good embeddings are necessary but not sufficient. We also need to measure search quality. The next chapter covers evaluation metrics that tell us if our search system actually works.

---

*Continue to [Chapter 13: Search Quality Metrics](./13-search-quality-metrics.md)*
