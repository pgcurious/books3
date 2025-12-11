# Chapter 1: What Are Vectors?

## The Building Block of Semantic Understanding

---

## Starting Simple: A Point in Space

Forget everything complex you've heard about vectors in machine learning. Let's start with what a vector actually *is*.

**A vector is just a list of numbers that represents a position or direction.**

That's it. Really.

### One Dimension: A Number Line

Remember the number line from elementary school?

```
<----+----+----+----+----+----+----+---->
    -3   -2   -1    0    1    2    3
```

The number `2` represents a position on this line. We could write it as a vector with one dimension:

```
position = [2]
```

### Two Dimensions: A Flat Surface

Now add another number line perpendicular to the first. This is the familiar x-y coordinate plane:

```
    y
    |
  3 +           * (2, 3)
    |
  2 +
    |
  1 +
    |
----+----+----+----+---- x
    0    1    2    3
```

The point (2, 3) can be written as a vector:

```
position = [2, 3]
```

This vector says: "go 2 units along x, then 3 units along y."

### Three Dimensions: The World Around Us

Add a third axis (z), and you get 3D space — the physical world:

```
position = [2, 3, 5]
```

This could represent a point in a room: 2 meters from the left wall, 3 meters from the front wall, 5 meters from the floor.

---

## The Leap: Beyond Three Dimensions

Here's where it gets interesting. There's no mathematical reason to stop at three dimensions.

**A vector can have any number of dimensions:**

```python
# 1 dimension
v1 = [5]

# 2 dimensions
v2 = [3, 4]

# 3 dimensions
v3 = [1, 2, 3]

# 100 dimensions
v100 = [0.1, 0.5, -0.3, ..., 0.7]  # 100 numbers

# 1536 dimensions (typical for modern embeddings)
v1536 = [0.012, -0.034, 0.078, ..., 0.045]  # 1536 numbers
```

We can't visualize 1536 dimensions, but mathematically, it works exactly the same as 2D or 3D. Each number is a coordinate along some axis.

---

## Why More Dimensions?

**More dimensions = more information can be captured.**

Think of it this way:

| Dimensions | What Can Be Represented |
|------------|------------------------|
| 1 | A single property (like temperature) |
| 2 | Two properties (temperature + humidity) |
| 3 | Three properties (temperature + humidity + pressure) |
| 768 | Hundreds of subtle aspects of meaning |

When we represent words or sentences as vectors, each dimension captures some aspect of meaning. More dimensions allow for more nuanced representations.

---

## Vectors as Directions

Vectors aren't just positions — they can also represent *directions* and *magnitudes*.

```
     ^
     |  * (2, 3)
     | /
     |/  <- This arrow IS the vector
  ---+-------->
```

The vector `[2, 3]` can be thought of as:
- A position: "the point at (2, 3)"
- A direction: "an arrow pointing up and to the right"
- A displacement: "move 2 right and 3 up"

This duality will become important when we discuss similarity.

---

## Key Vector Operations

### 1. Addition: Combining Vectors

```python
a = [1, 2]
b = [3, 1]
a + b = [4, 3]  # Add corresponding elements
```

Visual intuition: Place vector `b` at the end of vector `a`.

### 2. Scalar Multiplication: Scaling

```python
a = [1, 2]
2 * a = [2, 4]  # Multiply each element by 2
```

This makes the vector twice as long, pointing in the same direction.

### 3. Magnitude (Length): How Long is the Vector?

```python
import math

a = [3, 4]
magnitude = math.sqrt(3**2 + 4**2)  # = 5
```

This is the Pythagorean theorem extended to any number of dimensions:

```python
def magnitude(vector):
    return math.sqrt(sum(x**2 for x in vector))

# Works for any dimension
magnitude([1, 2, 3, 4, 5])  # sqrt(1 + 4 + 9 + 16 + 25) = sqrt(55)
```

### 4. Normalization: Unit Vectors

A **unit vector** has a magnitude of 1. To normalize a vector:

```python
def normalize(vector):
    mag = magnitude(vector)
    return [x / mag for x in vector]

# Original: [3, 4] (magnitude = 5)
# Normalized: [0.6, 0.8] (magnitude = 1)
```

**Why normalize?** It lets us focus on *direction* without being affected by *magnitude*. This is crucial for comparing meanings.

---

## The Dot Product: Measuring Alignment

The **dot product** tells us how aligned two vectors are:

```python
def dot_product(a, b):
    return sum(x * y for x, y in zip(a, b))

a = [1, 0]  # Points right
b = [0, 1]  # Points up
c = [1, 0]  # Points right

dot_product(a, b)  # = 0 (perpendicular)
dot_product(a, c)  # = 1 (same direction)
```

**Intuition:**
- **Positive** dot product → vectors point in similar directions
- **Zero** dot product → vectors are perpendicular (unrelated)
- **Negative** dot product → vectors point in opposite directions

---

## Why This Matters for Embeddings

Here's the key insight that makes semantic search possible:

**If we can represent words as vectors where similar meanings are close together, then finding similar meanings becomes a geometry problem.**

Consider this hypothetical 2D embedding:

```
        "happy"
           *
    "joyful" *     * "ecstatic"



                        * "car"

    "sad" *              * "automobile"
       * "unhappy"
```

In this space:
- "happy", "joyful", and "ecstatic" are close together
- "car" and "automobile" are close together
- "happy" and "car" are far apart

**The magic**: By representing meaning as position, we can use distance to find similarity.

---

## Code: Putting It Together

```python
import math

class Vector:
    def __init__(self, components):
        self.components = components

    def __add__(self, other):
        return Vector([a + b for a, b in zip(self.components, other.components)])

    def magnitude(self):
        return math.sqrt(sum(x**2 for x in self.components))

    def normalize(self):
        mag = self.magnitude()
        return Vector([x / mag for x in self.components])

    def dot(self, other):
        return sum(a * b for a, b in zip(self.components, other.components))

# Example: Two word vectors (simplified 3D)
king = Vector([0.8, 0.6, 0.1])
queen = Vector([0.75, 0.65, 0.2])
apple = Vector([-0.3, 0.1, 0.9])

# Check similarity via dot product of normalized vectors
print(king.normalize().dot(queen.normalize()))  # High (similar concepts)
print(king.normalize().dot(apple.normalize()))  # Low (different concepts)
```

---

## Key Insights

1. **Vectors are just lists of numbers** representing positions in space
2. **More dimensions** allow for more complex representations
3. **Direction matters more than magnitude** for comparing meanings
4. **The dot product** measures how aligned two vectors are
5. **Similar meanings → similar vectors** is the foundation of semantic search

---

## What's Next?

Now that we understand vectors, the next question is: **How do we turn words into vectors?**

We can't just assign random numbers — the vectors need to capture actual meaning. In the next chapter, we'll explore how this remarkable transformation happens.

---

*Continue to [Chapter 2: From Words to Vectors](./02-from-words-to-vectors.md)*
