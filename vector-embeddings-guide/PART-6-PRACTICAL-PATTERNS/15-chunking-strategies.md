# Chapter 15: Chunking Strategies

## Breaking Documents Into Searchable Pieces

---

## Why Chunking Matters

Embedding models have context limits (typically 256-8192 tokens). More importantly:

**Long documents dilute meaning.** A 10-page document about machine learning, databases, AND cooking will have an embedding that's "about" all three topics — matching none well.

Chunking creates focused, searchable units.

---

## The Chunking Trade-off

```
Smaller Chunks                    Larger Chunks
      │                                │
      ▼                                ▼
✓ Precise matching             ✓ More context
✓ More fine-grained            ✓ Self-contained
✗ Less context                 ✗ Diluted meaning
✗ May split ideas              ✗ Worse matching
```

**The goal**: Chunks large enough to be meaningful, small enough to be specific.

---

## Strategy 1: Fixed-Size Chunking

The simplest approach: split by character/token count.

```python
def fixed_size_chunk(
    text: str,
    chunk_size: int = 500,
    overlap: int = 50
) -> list:
    """
    Split text into fixed-size chunks with overlap.

    Args:
        text: Source text
        chunk_size: Characters per chunk
        overlap: Characters to repeat between chunks
    """
    chunks = []
    start = 0

    while start < len(text):
        end = start + chunk_size
        chunk = text[start:end]

        # Don't include tiny final chunks
        if len(chunk) > overlap:
            chunks.append({
                'text': chunk,
                'start': start,
                'end': min(end, len(text))
            })

        start = end - overlap

    return chunks

# Example
text = "A" * 1200  # 1200 characters
chunks = fixed_size_chunk(text, chunk_size=500, overlap=50)
# Results in 3 chunks: 0-500, 450-950, 900-1200
```

### Pros and Cons

| Pros | Cons |
|------|------|
| Simple to implement | Breaks mid-sentence |
| Predictable size | Breaks mid-paragraph |
| Even distribution | No semantic awareness |

---

## Strategy 2: Sentence-Based Chunking

Split at sentence boundaries, group into chunks.

```python
import re

def sentence_chunk(
    text: str,
    max_sentences: int = 5,
    overlap_sentences: int = 1
) -> list:
    """
    Split text by sentences, group into chunks.
    """
    # Simple sentence splitting (use nltk for better results)
    sentences = re.split(r'(?<=[.!?])\s+', text)

    chunks = []
    start_idx = 0

    while start_idx < len(sentences):
        end_idx = min(start_idx + max_sentences, len(sentences))
        chunk_sentences = sentences[start_idx:end_idx]

        chunks.append({
            'text': ' '.join(chunk_sentences),
            'sentences': chunk_sentences,
            'start_sentence': start_idx,
            'end_sentence': end_idx
        })

        start_idx = end_idx - overlap_sentences

    return chunks

# Better: Use NLTK or spaCy for sentence detection
import nltk
nltk.download('punkt')
from nltk.tokenize import sent_tokenize

def better_sentence_split(text: str) -> list:
    return sent_tokenize(text)
```

### Pros and Cons

| Pros | Cons |
|------|------|
| Preserves sentences | Variable chunk sizes |
| More natural breaks | May still split ideas |
| Better than fixed | Sentence detection can fail |

---

## Strategy 3: Paragraph/Section Chunking

Use document structure as natural boundaries.

```python
def paragraph_chunk(text: str, max_length: int = 1000) -> list:
    """
    Split by paragraphs, merge small ones, split large ones.
    """
    # Split by double newlines (paragraphs)
    paragraphs = re.split(r'\n\n+', text)

    chunks = []
    current_chunk = ""

    for para in paragraphs:
        para = para.strip()
        if not para:
            continue

        # If paragraph alone exceeds max, split it
        if len(para) > max_length:
            if current_chunk:
                chunks.append({'text': current_chunk})
                current_chunk = ""
            # Use sentence chunking for large paragraphs
            sub_chunks = sentence_chunk(para, max_sentences=3)
            chunks.extend(sub_chunks)
            continue

        # If adding paragraph exceeds max, start new chunk
        if len(current_chunk) + len(para) > max_length:
            if current_chunk:
                chunks.append({'text': current_chunk})
            current_chunk = para
        else:
            current_chunk = current_chunk + "\n\n" + para if current_chunk else para

    if current_chunk:
        chunks.append({'text': current_chunk})

    return chunks
```

### Markdown/HTML Aware Chunking

```python
def markdown_chunk(text: str, max_length: int = 1000) -> list:
    """
    Split markdown by headers, preserving hierarchy.
    """
    # Split by headers
    sections = re.split(r'(^#{1,6}\s+.+$)', text, flags=re.MULTILINE)

    chunks = []
    current_headers = []
    current_content = ""

    for i, section in enumerate(sections):
        section = section.strip()
        if not section:
            continue

        # Check if it's a header
        header_match = re.match(r'^(#{1,6})\s+(.+)$', section)

        if header_match:
            level = len(header_match.group(1))
            header_text = header_match.group(2)

            # Save current chunk if exists
            if current_content:
                chunks.append({
                    'text': current_content,
                    'headers': current_headers.copy()
                })

            # Update header stack
            current_headers = current_headers[:level-1]
            current_headers.append(header_text)
            current_content = section + "\n"
        else:
            current_content += section + "\n"

            # Check if chunk is getting too large
            if len(current_content) > max_length:
                chunks.append({
                    'text': current_content,
                    'headers': current_headers.copy()
                })
                current_content = ""

    if current_content:
        chunks.append({
            'text': current_content,
            'headers': current_headers.copy()
        })

    return chunks
```

---

## Strategy 4: Semantic Chunking

Use embeddings to find natural topic boundaries.

```python
import numpy as np
from sentence_transformers import SentenceTransformer

def semantic_chunk(
    text: str,
    model: SentenceTransformer,
    threshold: float = 0.5,
    min_chunk_size: int = 100
) -> list:
    """
    Split text where semantic similarity drops significantly.
    """
    # Split into sentences
    sentences = sent_tokenize(text)
    if len(sentences) < 2:
        return [{'text': text}]

    # Get embeddings for each sentence
    embeddings = model.encode(sentences)

    # Calculate similarity between adjacent sentences
    similarities = []
    for i in range(len(embeddings) - 1):
        sim = np.dot(embeddings[i], embeddings[i+1]) / (
            np.linalg.norm(embeddings[i]) * np.linalg.norm(embeddings[i+1])
        )
        similarities.append(sim)

    # Find breakpoints where similarity drops below threshold
    breakpoints = [0]
    for i, sim in enumerate(similarities):
        if sim < threshold:
            breakpoints.append(i + 1)
    breakpoints.append(len(sentences))

    # Create chunks
    chunks = []
    for i in range(len(breakpoints) - 1):
        start, end = breakpoints[i], breakpoints[i+1]
        chunk_text = ' '.join(sentences[start:end])

        # Merge small chunks with previous
        if len(chunk_text) < min_chunk_size and chunks:
            chunks[-1]['text'] += ' ' + chunk_text
        else:
            chunks.append({'text': chunk_text})

    return chunks
```

### Pros and Cons

| Pros | Cons |
|------|------|
| Topic-aware splits | Slower (requires embeddings) |
| Natural boundaries | Variable sizes |
| Preserves context | Threshold tuning needed |

---

## Strategy 5: Recursive Chunking

LangChain's approach: try multiple strategies in order.

```python
class RecursiveChunker:
    def __init__(
        self,
        chunk_size: int = 500,
        overlap: int = 50,
        separators: list = None
    ):
        self.chunk_size = chunk_size
        self.overlap = overlap
        self.separators = separators or [
            "\n\n",      # Paragraphs
            "\n",        # Lines
            ". ",        # Sentences
            ", ",        # Clauses
            " ",         # Words
            ""           # Characters
        ]

    def chunk(self, text: str, separators: list = None) -> list:
        """Recursively split text using separators in order."""
        separators = separators or self.separators

        if not separators:
            return [text]

        separator = separators[0]
        remaining_separators = separators[1:]

        # Try to split by current separator
        if separator:
            splits = text.split(separator)
        else:
            splits = list(text)

        chunks = []
        current_chunk = ""

        for split in splits:
            test_chunk = current_chunk + separator + split if current_chunk else split

            if len(test_chunk) <= self.chunk_size:
                current_chunk = test_chunk
            else:
                # Current chunk is full
                if current_chunk:
                    chunks.append(current_chunk)

                # If split itself is too large, recurse with next separator
                if len(split) > self.chunk_size:
                    sub_chunks = self.chunk(split, remaining_separators)
                    chunks.extend(sub_chunks)
                    current_chunk = ""
                else:
                    current_chunk = split

        if current_chunk:
            chunks.append(current_chunk)

        return chunks
```

---

## Choosing Chunk Size

### Factors to Consider

| Factor | Smaller Chunks | Larger Chunks |
|--------|---------------|---------------|
| Model context limit | Fits easily | May truncate |
| Precision needs | Better | Worse |
| Context needs | Worse | Better |
| Storage cost | Higher (more chunks) | Lower |
| Query type | Short queries | Complex queries |

### Empirical Guidelines

| Document Type | Recommended Size | Overlap |
|---------------|------------------|---------|
| FAQs | 100-200 chars | 0 |
| Documentation | 300-500 chars | 50 |
| Articles | 500-1000 chars | 100 |
| Books | 1000-2000 chars | 200 |
| Code | By function/class | 0 |

### Testing Your Chunk Size

```python
def evaluate_chunk_sizes(
    documents: list,
    queries: list,
    relevant_docs: list,
    chunk_sizes: list,
    model
):
    """Compare different chunk sizes."""
    results = {}

    for size in chunk_sizes:
        # Chunk all documents
        chunker = RecursiveChunker(chunk_size=size)
        all_chunks = []
        for doc in documents:
            chunks = chunker.chunk(doc['text'])
            for i, chunk in enumerate(chunks):
                all_chunks.append({
                    'text': chunk,
                    'doc_id': doc['id'],
                    'chunk_index': i
                })

        # Build index
        embeddings = model.encode([c['text'] for c in all_chunks])

        # Evaluate
        scores = evaluate_retrieval(queries, relevant_docs, embeddings, all_chunks)
        results[size] = scores

        print(f"Chunk size {size}: MRR={scores['mrr']:.3f}, Chunks={len(all_chunks)}")

    return results
```

---

## Advanced Pattern: Parent Document Retrieval

Return the full document (or larger context) after finding relevant chunk.

```python
class ParentDocumentRetriever:
    def __init__(self, model, chunk_size=500):
        self.model = model
        self.chunker = RecursiveChunker(chunk_size=chunk_size)
        self.chunks = []  # Small chunks for retrieval
        self.parents = {}  # Full documents

    def add_document(self, doc_id: str, text: str):
        """Index chunks but store parent."""
        self.parents[doc_id] = text

        chunks = self.chunker.chunk(text)
        for i, chunk in enumerate(chunks):
            embedding = self.model.encode(chunk)
            self.chunks.append({
                'embedding': embedding,
                'parent_id': doc_id,
                'chunk_text': chunk,
                'chunk_index': i
            })

    def search(self, query: str, top_k: int = 5) -> list:
        """Search chunks, return parent documents."""
        query_emb = self.model.encode(query)

        # Find best chunks
        scores = []
        for i, chunk in enumerate(self.chunks):
            sim = cosine_similarity(query_emb, chunk['embedding'])
            scores.append((i, sim))

        scores.sort(key=lambda x: x[1], reverse=True)

        # Deduplicate by parent, return full docs
        seen_parents = set()
        results = []

        for idx, score in scores:
            parent_id = self.chunks[idx]['parent_id']
            if parent_id not in seen_parents:
                seen_parents.add(parent_id)
                results.append({
                    'doc_id': parent_id,
                    'text': self.parents[parent_id],
                    'matched_chunk': self.chunks[idx]['chunk_text'],
                    'score': score
                })

                if len(results) >= top_k:
                    break

        return results
```

---

## Key Insights

1. **Chunk size is a key parameter** — test empirically
2. **Overlap prevents losing context** at boundaries
3. **Document structure** (paragraphs, headers) provides natural breaks
4. **Semantic chunking** is smarter but slower
5. **Recursive chunking** balances simplicity and quality
6. **Parent document retrieval** — search small, return large

---

## What's Next?

The final chapter covers hybrid search — combining the best of keyword and semantic approaches for production systems.

---

*Continue to [Chapter 16: Hybrid Search](./16-hybrid-search.md)*
