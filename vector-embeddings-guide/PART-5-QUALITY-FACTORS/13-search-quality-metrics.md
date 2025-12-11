# Chapter 13: Search Quality Metrics

## Measuring What Matters

---

## Why Metrics Matter

"The search seems to work" isn't good enough. We need quantifiable metrics to:

1. Compare different models/approaches
2. Track quality over time
3. Justify engineering investments
4. Identify degradation quickly

---

## The Fundamental Concepts

### Relevance

A document is **relevant** if it satisfies the user's information need.

```
Query: "How to sort a list in Python"

Relevant:
✓ "Python's sort() method modifies lists in-place"
✓ "Using sorted() to create a new sorted list"
✓ "Custom sorting with key functions"

Not Relevant:
✗ "Python installation guide"
✗ "List comprehensions in Python"
✗ "Sorting algorithms explained (C++)"
```

### Graded Relevance

Often relevance isn't binary:

| Grade | Meaning | Example |
|-------|---------|---------|
| 3 | Perfect | Exactly answers the query |
| 2 | Excellent | Highly relevant |
| 1 | Fair | Somewhat relevant |
| 0 | Irrelevant | Not useful |

---

## Core Metrics

### 1. Precision@K

**"Of the top K results, how many are relevant?"**

```python
def precision_at_k(retrieved: list, relevant: set, k: int) -> float:
    """
    Precision at K.

    Args:
        retrieved: Ordered list of document IDs
        relevant: Set of relevant document IDs
        k: Number of results to consider
    """
    top_k = retrieved[:k]
    relevant_in_top_k = sum(1 for doc in top_k if doc in relevant)
    return relevant_in_top_k / k

# Example
retrieved = ['doc1', 'doc2', 'doc3', 'doc4', 'doc5']
relevant = {'doc1', 'doc3', 'doc7'}

print(precision_at_k(retrieved, relevant, 3))  # 2/3 = 0.667
print(precision_at_k(retrieved, relevant, 5))  # 2/5 = 0.400
```

**Use when**: You care about result quality at a specific cutoff (e.g., first page).

### 2. Recall@K

**"Of all relevant documents, how many are in the top K?"**

```python
def recall_at_k(retrieved: list, relevant: set, k: int) -> float:
    """
    Recall at K.
    """
    top_k = retrieved[:k]
    relevant_found = sum(1 for doc in top_k if doc in relevant)
    return relevant_found / len(relevant) if relevant else 0

# Example
retrieved = ['doc1', 'doc2', 'doc3', 'doc4', 'doc5']
relevant = {'doc1', 'doc3', 'doc7'}

print(recall_at_k(retrieved, relevant, 3))  # 2/3 = 0.667
print(recall_at_k(retrieved, relevant, 5))  # 2/3 = 0.667 (doc7 not found)
```

**Use when**: Missing relevant documents is costly (medical, legal).

### 3. Mean Reciprocal Rank (MRR)

**"How highly is the first relevant result ranked?"**

```python
def reciprocal_rank(retrieved: list, relevant: set) -> float:
    """
    Reciprocal rank for a single query.
    """
    for rank, doc in enumerate(retrieved, 1):
        if doc in relevant:
            return 1 / rank
    return 0

def mean_reciprocal_rank(results: list) -> float:
    """
    MRR across multiple queries.

    Args:
        results: List of (retrieved, relevant) tuples
    """
    rrs = [reciprocal_rank(retr, rel) for retr, rel in results]
    return sum(rrs) / len(rrs) if rrs else 0

# Example
query_results = [
    (['doc1', 'doc2', 'doc3'], {'doc1'}),  # RR = 1/1 = 1.0
    (['doc4', 'doc5', 'doc2'], {'doc2'}),  # RR = 1/3 = 0.33
    (['doc7', 'doc8', 'doc9'], {'doc1'}),  # RR = 0 (not found)
]

print(mean_reciprocal_rank(query_results))  # (1.0 + 0.33 + 0) / 3 = 0.44
```

**Use when**: Users typically want one good answer (e.g., FAQ search).

### 4. Normalized Discounted Cumulative Gain (NDCG)

**"Are highly relevant documents ranked higher than somewhat relevant ones?"**

```python
import math

def dcg_at_k(relevances: list, k: int) -> float:
    """
    Discounted Cumulative Gain.

    Args:
        relevances: List of relevance scores in ranking order
        k: Number of results to consider
    """
    dcg = 0
    for i, rel in enumerate(relevances[:k], 1):
        dcg += rel / math.log2(i + 1)
    return dcg

def ndcg_at_k(relevances: list, k: int) -> float:
    """
    Normalized DCG.
    """
    dcg = dcg_at_k(relevances, k)
    # Ideal DCG: sort relevances descending
    ideal_relevances = sorted(relevances, reverse=True)
    idcg = dcg_at_k(ideal_relevances, k)
    return dcg / idcg if idcg > 0 else 0

# Example with graded relevance (3=perfect, 2=good, 1=fair, 0=bad)
relevances = [3, 2, 0, 1, 2]  # Actual ranking
print(ndcg_at_k(relevances, 5))  # How close to ideal ranking?
```

**Use when**: Relevance is graded, not binary.

---

## Comprehensive Evaluation

### Average Precision (AP) and MAP

```python
def average_precision(retrieved: list, relevant: set) -> float:
    """
    Average precision for a single query.
    """
    if not relevant:
        return 0

    precisions = []
    relevant_found = 0

    for rank, doc in enumerate(retrieved, 1):
        if doc in relevant:
            relevant_found += 1
            precisions.append(relevant_found / rank)

    return sum(precisions) / len(relevant) if precisions else 0

def mean_average_precision(results: list) -> float:
    """
    MAP across multiple queries.
    """
    aps = [average_precision(retr, rel) for retr, rel in results]
    return sum(aps) / len(aps) if aps else 0

# Example
retrieved = ['doc1', 'doc2', 'doc3', 'doc4', 'doc5']
relevant = {'doc1', 'doc3', 'doc5'}

# Precisions at relevant positions: 1/1=1, 2/3=0.67, 3/5=0.6
print(average_precision(retrieved, relevant))  # (1 + 0.67 + 0.6) / 3 = 0.76
```

**MAP is the most comprehensive single metric** — it considers both precision and recall across all ranks.

---

## Practical Evaluation Framework

### Step 1: Create a Test Dataset

```python
# Gold standard: human-judged query-document pairs
test_queries = [
    {
        "query": "python list sorting",
        "relevant": {
            "doc_123": 3,  # Perfect match
            "doc_456": 2,  # Good match
            "doc_789": 1,  # Fair match
        }
    },
    {
        "query": "machine learning basics",
        "relevant": {
            "doc_234": 3,
            "doc_567": 2,
        }
    },
    # ... more queries
]
```

### Step 2: Run Evaluation

```python
class SearchEvaluator:
    def __init__(self, search_engine):
        self.engine = search_engine

    def evaluate(self, test_queries: list, k: int = 10) -> dict:
        metrics = {
            'mrr': [],
            'precision_at_k': [],
            'recall_at_k': [],
            'ndcg_at_k': [],
            'map': []
        }

        for test in test_queries:
            query = test['query']
            relevant = set(test['relevant'].keys())
            relevance_grades = test['relevant']

            # Get search results
            results = self.engine.search(query, top_k=k)
            retrieved = [r['id'] for r in results]

            # Calculate metrics
            metrics['mrr'].append(reciprocal_rank(retrieved, relevant))
            metrics['precision_at_k'].append(precision_at_k(retrieved, relevant, k))
            metrics['recall_at_k'].append(recall_at_k(retrieved, relevant, k))
            metrics['map'].append(average_precision(retrieved, relevant))

            # NDCG with grades
            result_grades = [relevance_grades.get(doc, 0) for doc in retrieved]
            metrics['ndcg_at_k'].append(ndcg_at_k(result_grades, k))

        # Average across queries
        return {name: sum(values)/len(values)
                for name, values in metrics.items()}

# Usage
evaluator = SearchEvaluator(my_search_engine)
scores = evaluator.evaluate(test_queries, k=10)

print(f"MRR: {scores['mrr']:.3f}")
print(f"P@10: {scores['precision_at_k']:.3f}")
print(f"R@10: {scores['recall_at_k']:.3f}")
print(f"NDCG@10: {scores['ndcg_at_k']:.3f}")
print(f"MAP: {scores['map']:.3f}")
```

---

## Online vs Offline Metrics

### Offline Metrics (What we've covered)

Measured on test sets before deployment:
- Precision, Recall, MRR, NDCG, MAP
- **Pros**: Controlled, reproducible
- **Cons**: May not reflect real user behavior

### Online Metrics (Production)

Measured from real user behavior:

```python
# Click-through rate
ctr = clicks / impressions

# Mean Reciprocal Rank (from clicks)
# Position of first clicked result
mrr_online = 1 / first_click_position

# Abandonment rate
abandonment = searches_with_no_clicks / total_searches

# Reformulation rate
reformulation = searches_followed_by_another_search / total_searches
```

**Best practice**: Use offline metrics for development, online metrics for monitoring.

---

## Metric Selection Guide

| Scenario | Primary Metric | Why |
|----------|---------------|-----|
| FAQ/Single answer | MRR | First relevant result matters most |
| Research/Explore | Recall@K | Don't miss relevant documents |
| Ranked list display | NDCG | Order matters, relevance is graded |
| General comparison | MAP | Comprehensive single number |
| E-commerce | Click-through + Conversion | Business outcome |

---

## Interpreting Results

### What's "Good"?

Benchmarks vary by domain, but rough guidelines:

| Metric | Poor | Acceptable | Good | Excellent |
|--------|------|------------|------|-----------|
| MRR | <0.3 | 0.3-0.5 | 0.5-0.7 | >0.7 |
| P@10 | <0.2 | 0.2-0.4 | 0.4-0.6 | >0.6 |
| NDCG@10 | <0.4 | 0.4-0.6 | 0.6-0.8 | >0.8 |
| MAP | <0.3 | 0.3-0.5 | 0.5-0.7 | >0.7 |

### Statistical Significance

Small differences might be noise:

```python
from scipy import stats

# Compare two systems
system_a_scores = [0.65, 0.72, 0.68, ...]  # Per-query scores
system_b_scores = [0.67, 0.71, 0.70, ...]

# Paired t-test
t_stat, p_value = stats.ttest_rel(system_a_scores, system_b_scores)

if p_value < 0.05:
    print("Difference is statistically significant")
else:
    print("Difference might be due to chance")
```

---

## Key Insights

1. **Precision**: Quality of returned results
2. **Recall**: Completeness of results
3. **MRR**: How quickly users find what they need
4. **NDCG**: Quality of ranking with graded relevance
5. **MAP**: Comprehensive metric balancing precision and recall
6. **Use multiple metrics** — no single metric tells the whole story
7. **Test set quality** is as important as the metrics

---

## What's Next?

We can measure search quality. Now let's improve it. The next chapter covers techniques to boost your search results.

---

*Continue to [Chapter 14: Improving Results](./14-improving-results.md)*
