# Chapter 4: Word2Vec — The Revolution

## The Algorithm That Changed NLP

---

## The Year Everything Changed

In 2013, Tomas Mikolov and colleagues at Google published a paper that transformed natural language processing. **Word2Vec** showed that simple neural networks could learn rich word representations from raw text — no human labeling required.

The famous "King - Man + Woman = Queen" example captured imaginations worldwide. Suddenly, semantic relationships were computable.

---

## The Core Idea

Word2Vec is based on a simple prediction task:

**Given some context words, predict the target word (or vice versa).**

By training a neural network on this task across billions of words, the network learns embeddings as a byproduct.

---

## Two Architectures

### 1. CBOW (Continuous Bag of Words)

**Task**: Given surrounding context words, predict the center word.

```
Context: ["The", "cat", "on", "the", "mat"]
                        ↓
                   Predict: "sat"
```

```
Input: Context words → Hidden Layer → Output: Predict center word

    [The]    ─┐
    [cat]    ─┼→ Average → [Hidden Layer] → [sat]
    [on]     ─┤            (word vector)
    [the]    ─┤
    [mat]    ─┘
```

CBOW asks: "Given the neighborhood, what word belongs here?"

### 2. Skip-gram

**Task**: Given a center word, predict surrounding context words.

```
Input: "sat"
         ↓
Predict: ["The", "cat", "on", "the", "mat"]
```

```
Input: Center word → Hidden Layer → Output: Predict context words

                                  ┌→ [The]
                                  ├→ [cat]
    [sat] → [Hidden Layer]       ─┼→ [on]
            (word vector)         ├→ [the]
                                  └→ [mat]
```

Skip-gram asks: "What words might appear near this word?"

### Which Is Better?

| Aspect | CBOW | Skip-gram |
|--------|------|-----------|
| Speed | Faster | Slower |
| Rare words | Worse | Better |
| Common words | Better | Worse |
| Typical choice | Large data | Smaller data |

Skip-gram is generally preferred for quality; CBOW for speed.

---

## How Training Works

### The Training Loop

```python
# Pseudocode for Skip-gram training
for sentence in corpus:
    for i, center_word in enumerate(sentence):
        # Get context words within window
        context = sentence[max(0, i-window):i] + sentence[i+1:i+window+1]

        for context_word in context:
            # Positive example: center_word should predict context_word
            train(center_word, context_word, label=1)

            # Negative sampling: random words should NOT be predicted
            for neg_word in sample_random_words(k=5):
                train(center_word, neg_word, label=0)
```

### Negative Sampling

Training on every word in the vocabulary is expensive. **Negative sampling** is a trick:

1. For each positive pair (center, context), we also train on a few "negative" pairs
2. Negative pairs are (center, random_word) where random_word wasn't in the context
3. This teaches the model to distinguish real context from noise

```python
# Real context: "cat" appears near "fur"
positive_example = ("cat", "fur", 1)  # label = 1 (true pair)

# Negative samples: "cat" doesn't appear near "democracy"
negative_examples = [
    ("cat", "democracy", 0),
    ("cat", "fiscal", 0),
    ("cat", "quantum", 0),
]
```

---

## The Network Architecture

Word2Vec uses a surprisingly simple neural network:

```
Input Layer          Hidden Layer         Output Layer
(one-hot vector)     (word embedding)     (softmax/sigmoid)

[0]                                       [0.01]  "the"
[0]                   [0.2]               [0.03]  "cat"
[1] "cat"    ──→      [0.8]      ──→      [0.85]  "fur"  ← PREDICT
[0]                   [-0.1]              [0.02]  "democracy"
[0]                   [0.5]               [0.09]  "sat"
...                   ...                 ...
```

**The hidden layer IS the embedding!**

After training:
- The input→hidden weights form the word embeddings
- We discard the output layer

---

## Code: Training Word2Vec

Using Gensim:

```python
from gensim.models import Word2Vec

# Sample corpus (list of tokenized sentences)
sentences = [
    ["the", "cat", "sat", "on", "the", "mat"],
    ["the", "dog", "ran", "in", "the", "park"],
    ["cats", "and", "dogs", "are", "pets"],
    # ... millions more sentences
]

# Train Word2Vec
model = Word2Vec(
    sentences,
    vector_size=100,    # Embedding dimensions
    window=5,           # Context window size
    min_count=1,        # Ignore words with frequency < this
    sg=1,               # 1 for Skip-gram, 0 for CBOW
    workers=4           # Parallel training threads
)

# Get word vector
cat_vector = model.wv['cat']
print(cat_vector.shape)  # (100,)

# Find similar words
similar = model.wv.most_similar('cat', topn=5)
# [('dog', 0.89), ('pet', 0.85), ('kitten', 0.82), ...]

# Vector arithmetic
result = model.wv.most_similar(
    positive=['king', 'woman'],
    negative=['man'],
    topn=1
)
# [('queen', 0.87)]
```

---

## Why Vector Arithmetic Works

The magic of "King - Man + Woman = Queen" emerges from how the model learns.

### Relationship as Direction

During training, the model sees:
- "king" and "queen" in similar royal contexts
- "man" and "woman" in similar human contexts
- The gender difference is consistent across pairs

The model learns that the **direction** from "man" to "woman" is similar to the **direction** from "king" to "queen":

```
woman - man ≈ queen - king

Therefore:
king + (woman - man) ≈ queen
```

### Not Magic, Just Patterns

This works because:
1. The training data contains many gendered pairs in similar contexts
2. The model learns consistent offsets for relationships
3. Linear algebra lets us manipulate these offsets

---

## Limitations of Word2Vec

### 1. One Vector Per Word

```python
# "bank" (financial) and "bank" (river) have the same vector!
bank_vector = model.wv['bank']  # Which bank?
```

Word2Vec can't handle **polysemy** (multiple meanings).

### 2. No Sentence Understanding

```python
# Word2Vec treats these identically (same words, different meaning)
"dog bites man"  # Different from...
"man bites dog"  # ...but Word2Vec doesn't know that
```

Word order and sentence structure are ignored.

### 3. Fixed Vocabulary

Words not seen during training have no embedding:

```python
model.wv['cryptocurrency']  # KeyError if not in training data
```

### 4. Context Window Limitations

Word2Vec only looks at nearby words (typically 5-10). Long-range dependencies are missed.

---

## The Legacy

Despite limitations, Word2Vec's contributions were enormous:

1. **Proved** that unsupervised learning could capture semantics
2. **Efficient** — could train on billions of words
3. **Inspired** all subsequent embedding research
4. **Practical** — still used today for specific applications

The next generation (ELMo, BERT, GPT) built on Word2Vec's foundation to address its limitations.

---

## GloVe: A Worthy Competitor

**GloVe (Global Vectors)** from Stanford takes a different approach:

- Instead of prediction, it directly factorizes the co-occurrence matrix
- Combines global statistics with local context windows
- Often achieves similar or better results than Word2Vec

```python
# Using pre-trained GloVe with Gensim
import gensim.downloader as api

glove = api.load("glove-wiki-gigaword-100")
glove.most_similar("cat")
```

### Word2Vec vs GloVe

| Aspect | Word2Vec | GloVe |
|--------|----------|-------|
| Training | Prediction-based | Factorization-based |
| Data usage | Local windows | Global co-occurrence |
| Speed | Fast | Faster (one-time matrix) |
| Quality | Excellent | Excellent |

In practice, they often perform similarly. The choice often comes down to what pre-trained models are available.

---

## Key Insights

1. **Word2Vec learns embeddings by predicting context** — a simple task that captures meaning
2. **Skip-gram** predicts context from center word; **CBOW** does the reverse
3. **Negative sampling** makes training efficient
4. **Vector arithmetic** works because relationships are encoded as directions
5. **Limitations**: No polysemy, no word order, fixed vocabulary
6. **Legacy**: Foundation for all modern embeddings

---

## What's Next?

Word2Vec gave us word embeddings, but it has significant limitations. The next revolution came with **transformer models** that give us contextual embeddings — where the same word gets different vectors based on context.

---

*Continue to [Chapter 5: Transformer Embeddings](./05-transformer-embeddings.md)*
