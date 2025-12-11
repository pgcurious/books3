# Chapter 5: Transformer Embeddings

## Context-Aware Representations That Revolutionized NLP

---

## The Problem with Static Embeddings

Word2Vec gives every word a single, fixed vector. But language doesn't work that way:

```
"I deposited money in the bank."     → bank = financial institution
"I sat on the bank of the river."    → bank = riverside
```

**Same word, different meanings.** Word2Vec gives both the same vector.

---

## The Transformer Revolution

In 2017, the paper "Attention Is All You Need" introduced transformers. In 2018, BERT showed how to use transformers for embeddings.

The key innovation: **Contextual embeddings**.

```python
# BERT gives different vectors based on context
embed("bank", context="I deposited money in the bank")  # Financial vector
embed("bank", context="I sat by the river bank")         # Nature vector
```

The same word gets different representations depending on surrounding text.

---

## How Transformers Work (Simplified)

### The Attention Mechanism

The core idea: When processing a word, **look at all other words** to understand context.

```
Input: "The cat sat on the mat"

Processing "sat":
  - Look at "The" → some relevance
  - Look at "cat" → high relevance (who sat?)
  - Look at "on" → medium relevance (sat where?)
  - Look at "the" → low relevance
  - Look at "mat" → medium relevance (sat on what?)
```

Each word "attends" to all other words, learning which are important for understanding.

### Self-Attention Calculation

For each word, compute:
1. **Query**: "What am I looking for?"
2. **Key**: "What do I contain?"
3. **Value**: "What information do I provide?"

```python
# Simplified attention mechanism
def attention(query, keys, values):
    # How relevant is each key to the query?
    scores = [dot(query, key) for key in keys]

    # Normalize to probabilities
    weights = softmax(scores)

    # Weighted sum of values
    output = sum(w * v for w, v in zip(weights, values))
    return output
```

### Multi-Head Attention

Transformers use **multiple attention heads** — each head learns different relationships:

- Head 1 might learn syntactic relationships (subject-verb)
- Head 2 might learn semantic relationships (word meaning)
- Head 3 might learn positional relationships (word order)

```
┌──────────────────────────────────────┐
│           Multi-Head Attention        │
│  ┌────────┐ ┌────────┐ ┌────────┐   │
│  │ Head 1 │ │ Head 2 │ │ Head 3 │   │
│  │syntax  │ │semantic│ │position│   │
│  └───┬────┘ └───┬────┘ └───┬────┘   │
│      └──────────┴──────────┘         │
│               ↓                      │
│         Concatenate                  │
│               ↓                      │
│         Linear Layer                 │
└──────────────────────────────────────┘
```

---

## BERT: Embeddings from Transformers

**BERT (Bidirectional Encoder Representations from Transformers)** was trained on two tasks:

### Task 1: Masked Language Modeling

Hide some words, predict them:

```
Input:  "The [MASK] sat on the [MASK]."
Output: "The  cat   sat on the  mat."
```

This forces the model to understand context.

### Task 2: Next Sentence Prediction

Predict if sentence B follows sentence A:

```
A: "The cat sat on the mat."
B: "It was a fluffy cat."
→ True (B follows A)

A: "The cat sat on the mat."
B: "Stock prices rose sharply."
→ False (unrelated)
```

This teaches document-level understanding.

---

## Getting Embeddings from BERT

BERT processes text through multiple layers. Each layer produces embeddings:

```
Input: "The cat sat"

Layer 0 (Input):     [CLS] The   cat   sat   [SEP]
Layer 1:             [v]   [v]   [v]   [v]   [v]
Layer 2:             [v]   [v]   [v]   [v]   [v]
...
Layer 12 (Output):   [v]   [v]   [v]   [v]   [v]
```

### Which Embeddings to Use?

| Approach | Method | Use Case |
|----------|--------|----------|
| Last layer | Take final layer embeddings | General purpose |
| [CLS] token | Use the special classification token | Classification tasks |
| Mean pooling | Average all token embeddings | Semantic similarity |
| Multiple layers | Concatenate or average layers | Sometimes better |

```python
from transformers import AutoTokenizer, AutoModel
import torch

# Load BERT
tokenizer = AutoTokenizer.from_pretrained('bert-base-uncased')
model = AutoModel.from_pretrained('bert-base-uncased')

# Encode text
text = "The cat sat on the mat"
inputs = tokenizer(text, return_tensors='pt')

# Get embeddings
with torch.no_grad():
    outputs = model(**inputs)
    last_hidden = outputs.last_hidden_state  # (1, seq_len, 768)

# Mean pooling (common for sentence embeddings)
sentence_embedding = last_hidden.mean(dim=1)  # (1, 768)
```

---

## Sentence Transformers: Purpose-Built for Embeddings

While BERT wasn't designed for embeddings, **Sentence Transformers** were:

```python
from sentence_transformers import SentenceTransformer

# Load a model optimized for embeddings
model = SentenceTransformer('all-MiniLM-L6-v2')

# Simple API
sentences = [
    "A man is eating pizza.",
    "A man is eating food.",
    "A cat is sleeping."
]

embeddings = model.encode(sentences)
# Returns: numpy array of shape (3, 384)
```

### Why Sentence Transformers Are Better

BERT wasn't trained to make similar sentences have similar vectors. Sentence Transformers add:

1. **Siamese training**: Process two sentences, optimize for similarity
2. **Triplet loss**: Similar pairs should be closer than dissimilar pairs
3. **Efficient pooling**: Optimized strategies for sentence representation

---

## Modern Embedding Models

### Evolution of Models

```
2013: Word2Vec      → Static word embeddings
2018: BERT          → Contextual embeddings (not optimized for retrieval)
2019: Sentence-BERT → Optimized for semantic similarity
2021: Contriever    → Trained specifically for retrieval
2022: E5, GTR       → Even better retrieval embeddings
2023: BGE, Nomic    → State-of-the-art open models
2024: text-embedding-3 → OpenAI's latest
```

### Popular Models for Semantic Search

| Model | Dimensions | Speed | Quality | Notes |
|-------|------------|-------|---------|-------|
| all-MiniLM-L6-v2 | 384 | Very fast | Good | Great for prototyping |
| all-mpnet-base-v2 | 768 | Fast | Better | Good balance |
| bge-large-en-v1.5 | 1024 | Medium | Excellent | State-of-the-art open |
| text-embedding-3-small | 1536 | API | Excellent | OpenAI |
| text-embedding-3-large | 3072 | API | Best | OpenAI (highest quality) |

---

## Code: Comparing Different Models

```python
from sentence_transformers import SentenceTransformer
import numpy as np

# Load different models
mini = SentenceTransformer('all-MiniLM-L6-v2')      # 384-dim
mpnet = SentenceTransformer('all-mpnet-base-v2')   # 768-dim

# Test sentences
sentences = [
    "How do I reset my password?",
    "I forgot my login credentials",
    "What's the weather like today?"
]

def compare_models(model, sentences):
    embeddings = model.encode(sentences)

    # Compute similarities
    def cosine_sim(a, b):
        return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))

    print(f"Sentence 1 vs 2: {cosine_sim(embeddings[0], embeddings[1]):.3f}")
    print(f"Sentence 1 vs 3: {cosine_sim(embeddings[0], embeddings[2]):.3f}")

print("MiniLM:")
compare_models(mini, sentences)
# Sentence 1 vs 2: 0.724 (similar - both about login)
# Sentence 1 vs 3: 0.089 (different - unrelated topics)

print("\nMPNet:")
compare_models(mpnet, sentences)
# Similar pattern, potentially more nuanced distinctions
```

---

## Contextual vs Static: The Key Difference

```python
# Static embeddings (Word2Vec)
word2vec["bank"]  # Always the same vector

# Contextual embeddings (BERT-based)
model.encode("Money in the bank")["bank"]   # Financial context
model.encode("River bank fishing")["bank"]   # Nature context
# Different vectors!
```

### Why Context Matters for Search

Query: "apple products"

Without context:
- Might match "apple pie recipes" (fruit)
- Might match "banana products" (similar fruits)

With context:
- Understands "apple" here means Apple Inc.
- Better matches: "iPhone", "MacBook", "iPad"

---

## Computational Considerations

### Speed vs Quality Trade-offs

```python
# Fast model (good for real-time)
fast_model = SentenceTransformer('all-MiniLM-L6-v2')
# ~50ms for 100 sentences

# Quality model (better for offline indexing)
quality_model = SentenceTransformer('all-mpnet-base-v2')
# ~200ms for 100 sentences
```

### Memory Requirements

| Model | Parameters | Memory |
|-------|------------|--------|
| MiniLM-L6 | 22M | ~90MB |
| MPNet-base | 110M | ~440MB |
| BGE-large | 335M | ~1.3GB |

### Batch Processing

```python
# Efficient: batch encoding
embeddings = model.encode(sentences, batch_size=32)

# Inefficient: one at a time
embeddings = [model.encode(s) for s in sentences]
```

---

## Key Insights

1. **Contextual embeddings** give different vectors based on surrounding text
2. **Transformers** use attention to understand context
3. **BERT** provides contextual embeddings but wasn't optimized for similarity
4. **Sentence Transformers** are purpose-built for semantic similarity
5. **Model choice** involves speed/quality/cost trade-offs
6. **Modern models** (BGE, E5) often outperform older ones significantly

---

## What's Next?

We've covered how embeddings are created. But we haven't fully explored what the numbers mean. In the next chapter, we'll dive into **dimensionality** — why 384 dimensions? Why not 50 or 5000?

---

*Continue to [Chapter 6: Understanding Dimensions](./06-understanding-dimensions.md)*
