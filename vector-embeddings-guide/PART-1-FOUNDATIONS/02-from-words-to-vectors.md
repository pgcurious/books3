# Chapter 2: From Words to Vectors

## The Art of Teaching Computers to Understand Meaning

---

## The Challenge

Computers understand numbers, not words. To process language, we need to convert text into numbers. But here's the problem:

**How do we assign numbers to words such that the numbers capture meaning?**

Let's explore how this problem was solved, from naive approaches to breakthrough solutions.

---

## Approach 1: One-Hot Encoding (The Naive Way)

The simplest idea: give each word a unique position in a vector.

With a vocabulary of 5 words:

```python
vocabulary = ["cat", "dog", "fish", "bird", "tree"]

# One-hot encoding
cat  = [1, 0, 0, 0, 0]
dog  = [0, 1, 0, 0, 0]
fish = [0, 0, 1, 0, 0]
bird = [0, 0, 0, 1, 0]
tree = [0, 0, 0, 0, 1]
```

Each word is represented by a vector with a single `1` and all other positions `0`.

### Why This Fails

**Problem 1: No notion of similarity**

```python
# Distance between cat and dog
cat = [1, 0, 0, 0, 0]
dog = [0, 1, 0, 0, 0]

# Using dot product
similarity = sum(a * b for a, b in zip(cat, dog))  # = 0

# Cat is equally "similar" to dog as it is to tree!
```

Every word is equally distant from every other word. "cat" is no more similar to "dog" than it is to "tree".

**Problem 2: Curse of dimensionality**

Real vocabularies have 50,000+ words. Each vector would have 50,000 dimensions, with only one non-zero element. That's incredibly wasteful.

**Problem 3: No generalization**

The vector tells us nothing about the word. It's just an arbitrary ID.

---

## Approach 2: Hand-Crafted Features (The Linguistic Way)

What if linguists manually defined features?

```python
# Features: [is_animal, is_pet, can_fly, lives_in_water, has_fur]
cat  = [1, 1, 0, 0, 1]
dog  = [1, 1, 0, 0, 1]
fish = [1, 0, 0, 1, 0]
bird = [1, 0, 1, 0, 0]
tree = [0, 0, 0, 0, 0]
```

Now we can see that cat and dog are similar (both are furry pets).

### Why This Fails at Scale

- **Requires human expertise** for every word
- **Doesn't scale** to millions of words
- **Misses subtle meanings** — what features capture "melancholy" vs "sad"?
- **Language evolves** — new words, new meanings

---

## Approach 3: Distributional Semantics (The Key Insight)

In 1957, linguist John Firth wrote:

> *"You shall know a word by the company it keeps."*

This is the **distributional hypothesis**: Words that appear in similar contexts have similar meanings.

Consider these sentences:
- "The **cat** sat on the mat."
- "The **dog** sat on the mat."
- "The **cat** chased the mouse."
- "The **dog** chased the squirrel."

"Cat" and "dog" appear in similar contexts: both "sat on the mat" and "chased" things. This suggests they have related meanings.

### Co-occurrence Matrices

We can count which words appear together:

```
Corpus:
- "I like cats"
- "I like dogs"
- "cats chase mice"
- "dogs chase cats"

Co-occurrence matrix (window = 1 word):

        I    like   cats   dogs   chase   mice
I       0     2      0      0       0       0
like    2     0      1      1       0       0
cats    0     1      0      1       1       1
dogs    0     1      1      0       1       0
chase   0     0      1      1       0       1
mice    0     0      1      0       1       0
```

Now each word is a vector based on its context:
- `cats = [0, 1, 0, 1, 1, 1]`
- `dogs = [0, 1, 1, 0, 1, 0]`

These vectors are more similar to each other than to "mice"!

### Problems with Raw Co-occurrence

1. **Very sparse**: Most entries are zero
2. **Very large**: Vocabulary size × Vocabulary size
3. **Noisy**: Common words like "the" dominate

---

## Approach 4: Learned Embeddings (The Breakthrough)

The key insight: Instead of using raw co-occurrence counts, **learn a compact representation** that predicts context.

This is the foundation of modern embeddings:

1. Start with random vectors for each word
2. Train a neural network to predict context from words (or vice versa)
3. The learned vectors capture meaning as a byproduct

### The Magic of Learning

When you train a model to predict that "cat" often appears near "meow", "fur", "pet", the model learns to represent "cat" with numbers that encode these relationships.

The resulting vectors are:
- **Dense**: Every dimension has meaning (not mostly zeros)
- **Compact**: Typically 100-1536 dimensions (not vocabulary-size)
- **Meaningful**: Similar words have similar vectors

---

## Example: How "King - Man + Woman = Queen" Works

The famous Word2Vec demonstration:

```python
king   = [0.8,  0.6,  0.1]  # Simplified 3D
man    = [0.7,  0.1,  0.0]
woman  = [0.7,  0.1,  0.9]
queen  = [0.8,  0.6,  1.0]  # What we want to find

# Vector arithmetic
result = king - man + woman
#      = [0.8, 0.6, 0.1] - [0.7, 0.1, 0.0] + [0.7, 0.1, 0.9]
#      = [0.8, 0.6, 1.0]
#      ≈ queen!
```

This works because:
- The direction from "man" to "woman" captures the concept of gender
- Adding this direction to "king" moves toward the female equivalent

**The embedding space captures relationships as directions.**

---

## From Words to Sentences to Documents

Word embeddings are just the beginning. We also need to represent:

### Sentences

**Simple approach: Average the word vectors**

```python
def sentence_embedding(sentence, word_vectors):
    words = sentence.lower().split()
    vectors = [word_vectors[w] for w in words if w in word_vectors]
    return [sum(v[i] for v in vectors) / len(vectors)
            for i in range(len(vectors[0]))]

# "I love cats" = average of [I, love, cats] vectors
```

**Problem**: "Dog bites man" and "Man bites dog" have the same average!

**Better approach**: Use sequence-aware models (more in Chapter 5)

### Documents

For longer text, we need embeddings that capture the overall meaning:
- Paragraph vectors (Doc2Vec)
- Transformer-based embeddings (BERT, etc.)
- Pooling strategies (CLS token, mean pooling)

---

## The Embedding Process Visualized

```
Input Text              Tokenization           Embedding Model           Output Vector
─────────────          ─────────────          ─────────────────         ─────────────

"cats are great"   →   ["cats", "are",   →   [Neural Network]    →    [0.23, -0.17,
                        "great"]                                         0.89, ...,
                                                                         0.42]
                                                                      (768 dimensions)
```

The neural network is trained on massive amounts of text, learning to compress meaning into dense vectors.

---

## Code: Using Pre-trained Embeddings

```python
# Using sentence-transformers (pip install sentence-transformers)
from sentence_transformers import SentenceTransformer

# Load a pre-trained model
model = SentenceTransformer('all-MiniLM-L6-v2')

# Get embeddings
sentences = [
    "I love programming",
    "Coding is my passion",
    "The weather is nice today"
]

embeddings = model.encode(sentences)

# Check similarity
from numpy import dot
from numpy.linalg import norm

def cosine_similarity(a, b):
    return dot(a, b) / (norm(a) * norm(b))

# Programming sentences are similar
print(cosine_similarity(embeddings[0], embeddings[1]))  # ~0.7

# Programming and weather are not similar
print(cosine_similarity(embeddings[0], embeddings[2]))  # ~0.1
```

---

## Different Types of Embeddings

| Type | Granularity | Example Models | Use Case |
|------|-------------|----------------|----------|
| Word | Single words | Word2Vec, GloVe | Vocabulary analysis |
| Sentence | Full sentences | SBERT, USE | Semantic search |
| Document | Paragraphs/pages | Doc2Vec, Longformer | Document retrieval |
| Multi-modal | Text + images | CLIP | Cross-modal search |

For semantic search, **sentence/document embeddings** are typically most useful.

---

## Key Insights

1. **One-hot encoding** treats all words as equally different — useless for meaning
2. **Distributional hypothesis**: Context reveals meaning
3. **Learned embeddings** compress co-occurrence patterns into dense vectors
4. **Vector arithmetic** captures semantic relationships
5. **Modern embeddings** handle words, sentences, and documents

---

## What's Next?

We've seen how words become vectors. But where do these vectors live? In the next chapter, we'll explore the **embedding space** — the high-dimensional realm where meaning becomes geometry.

---

*Continue to [Chapter 3: The Embedding Space](./03-the-embedding-space.md)*
