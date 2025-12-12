# Chapter 10: The Diffing Algorithm

> *"Make the common case fast."*
> — Butler Lampson

---

## The Problem

We have two trees—the old Virtual DOM and the new one. We need to find the differences.

The theoretical problem is: "Given two trees, find the minimum edit operations to transform one into the other."

**Bad news:** The optimal algorithm for this is O(n³). For a tree with 1000 nodes, that's 1,000,000,000 operations. Unacceptable.

**Good news:** React doesn't need the optimal solution. It needs a *good enough* solution that's fast.

---

## React's Heuristics

React uses two assumptions to reduce O(n³) to O(n):

### Heuristic 1: Different Types Mean Different Trees

If a node changes from one type to another, React assumes the entire subtree is different.

```jsx
// Before
<div>
  <Counter />
</div>

// After
<span>
  <Counter />
</span>
```

React doesn't try to reuse anything. It destroys the `<div>` and its entire subtree (including the `Counter` state), then builds the `<span>` subtree from scratch.

**Why this works:** In practice, converting a `<div>` to a `<span>` rarely preserves semantic meaning. The children probably mean something different too.

### Heuristic 2: Keys Identify Elements Across Renders

For lists of elements, React uses `key` props to match old and new elements:

```jsx
// Before
<ul>
  <li key="a">Alice</li>
  <li key="b">Bob</li>
</ul>

// After
<ul>
  <li key="b">Bob</li>      {/* Moved, not recreated */}
  <li key="a">Alice</li>    {/* Moved, not recreated */}
  <li key="c">Charlie</li>  {/* New */}
</ul>
```

Keys tell React: "This element in the new tree corresponds to this element in the old tree."

Without keys, React compares by position—which breaks badly when items are reordered.

---

## The Algorithm Step by Step

### Step 1: Compare Root Nodes

```jsx
// Same type? Recurse into children
<div className="old"> → <div className="new">
// Update className, keep element, check children

// Different type? Replace entire subtree
<div>...</div> → <span>...</span>
// Destroy div subtree, create span subtree
```

### Step 2: Compare Element Attributes

```jsx
// Before
<div className="before" style={{ color: 'red' }} />

// After
<div className="after" style={{ color: 'blue' }} />

// React updates: className and style.color
// DOM operations:
element.className = 'after';
element.style.color = 'blue';
```

Only changed attributes are updated.

### Step 3: Recurse on Children

For component elements:

```jsx
// Before
<Profile userId={1} />

// After
<Profile userId={2} />

// Same component type, so:
// 1. Keep the existing Profile instance
// 2. Update its props
// 3. Re-render Profile with new props
```

For DOM elements with children, React uses one of two strategies:

**Without keys (index-based):**

```jsx
// Before
<ul>
  <li>Alice</li>    {/* index 0 */}
  <li>Bob</li>      {/* index 1 */}
</ul>

// After
<ul>
  <li>Bob</li>      {/* index 0 - compared to old index 0 */}
  <li>Alice</li>    {/* index 1 - compared to old index 1 */}
</ul>

// React sees:
// index 0: "Alice" → "Bob" (update text)
// index 1: "Bob" → "Alice" (update text)

// Two DOM updates, even though we just swapped
```

**With keys:**

```jsx
// Before
<ul>
  <li key="a">Alice</li>
  <li key="b">Bob</li>
</ul>

// After
<ul>
  <li key="b">Bob</li>
  <li key="a">Alice</li>
</ul>

// React sees:
// key="a": still exists, just moved
// key="b": still exists, just moved

// DOM operations: move nodes (no text updates)
```

---

## Why Keys Matter

### The Index Key Problem

This common mistake causes subtle bugs:

```jsx
function TodoList({ todos }) {
  return (
    <ul>
      {todos.map((todo, index) => (
        <li key={index}>  {/* DON'T DO THIS */}
          <input type="checkbox" checked={todo.done} />
          {todo.text}
        </li>
      ))}
    </ul>
  );
}
```

**What happens when you delete the first todo:**

```
Before:                          After:
key=0: [ ] Buy milk              key=0: [x] Walk dog      (was key=1)
key=1: [x] Walk dog              key=1: [ ] Call mom      (was key=2)
key=2: [ ] Call mom

React compares by key:
- key=0 old content → key=0 new content (different)
- key=1 old content → key=1 new content (different)
- key=2 existed, now doesn't (remove)
```

React updates the *content* of positions 0 and 1, then removes position 2. If `input` elements have their own DOM state (checked status, focus, selection), **that state stays with the position, not the data**.

Result: The checkbox states are wrong. The user checked "Walk dog", but now "Buy milk" is deleted and "Walk dog" is unchecked.

### The Correct Approach

Use stable, unique identifiers:

```jsx
function TodoList({ todos }) {
  return (
    <ul>
      {todos.map(todo => (
        <li key={todo.id}>  {/* Stable unique ID */}
          <input type="checkbox" checked={todo.done} />
          {todo.text}
        </li>
      ))}
    </ul>
  );
}
```

Now React correctly matches elements across renders:

```
Before:                          After:
key="a": [ ] Buy milk            (removed)
key="b": [x] Walk dog            key="b": [x] Walk dog
key="c": [ ] Call mom            key="c": [ ] Call mom

React: key="a" is gone, keep "b" and "c" as-is
```

---

## Component Identity

Keys also affect component state:

```jsx
function Chat({ recipientId }) {
  return <MessageInput key={recipientId} />;
}
```

**Without key:** Switching recipients keeps the same `MessageInput` instance. State (like draft message) persists across recipient changes.

**With key:** Each recipient gets a fresh `MessageInput`. State resets when recipient changes.

Keys aren't just for lists—they're for controlling when React considers two elements "the same."

---

## The Reconciliation Trade-offs

React's algorithm optimizes for common cases:

**Fast cases:**
- Same component type, different props → update props
- Same element type, different attributes → update attributes
- Keyed lists with additions/removals → add/remove nodes

**Slow cases:**
- Different component types → destroy and recreate subtree
- Unkeyed list reorder → update every item
- Key changes → treat as new element

Understanding these helps you structure your code for performance:

```jsx
// SLOW: Type changes, destroys subtree
{isLoggedIn ? <AuthenticatedApp /> : <LoginScreen />}

// If both are complex, consider:
{isLoggedIn ? <App view="authenticated" /> : <App view="login" />}
// Same component type, so state can be preserved if needed
```

---

## The Big Picture

React's diffing algorithm is a pragmatic compromise:

1. **Not optimal** — O(n) instead of O(n³)
2. **Based on heuristics** — Assumes developers give good hints (keys)
3. **Optimizes common cases** — Most UI updates are small changes
4. **Fails gracefully** — Worst case is unnecessary work, not incorrectness

The algorithm is clever, but the real cleverness is recognizing that "good enough, fast" beats "optimal, slow."

---

## Key Takeaways

1. **O(n) algorithm** using two heuristics: type comparison and keys
2. **Different types = different trees** — subtree is destroyed
3. **Keys match elements** across renders in lists
4. **Index keys cause bugs** — use stable IDs
5. **Keys control identity** — same key = same component instance
6. **Optimize for common cases** — small updates to existing structure

---

*Next: [Chapter 11: Keys and Identity](./11-keys-and-identity.md)*
