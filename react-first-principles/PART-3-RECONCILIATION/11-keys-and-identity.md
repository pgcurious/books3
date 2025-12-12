# Chapter 11: Keys and Identity

> *"Identity is a strange thing."*
> — The Ship of Theseus paradox

---

## The Fundamental Question

When does React consider two elements to be "the same"?

This question has profound implications for:
- Which DOM nodes are reused vs recreated
- Which component instances persist vs reset
- Which state is preserved vs destroyed

---

## Identity Without Keys

By default, React uses **position** to identify elements:

```jsx
function App() {
  const [showFirst, setShowFirst] = useState(true);

  return (
    <div>
      {showFirst && <Counter />}  {/* Position 0 */}
      <Counter />                  {/* Position 1 or 0? */}
    </div>
  );
}
```

**When showFirst is true:**
```
Position 0: Counter (first)
Position 1: Counter (second)
```

**When showFirst becomes false:**
```
Position 0: Counter (second, but React thinks it's first!)
```

React sees: "There's a Counter at position 0. Update it."

The second Counter inherits the first Counter's state, because React identifies them by position, not by your intention.

---

## Keys Create Explicit Identity

Keys tell React: "This is who this element IS, regardless of position."

```jsx
function App() {
  const [showFirst, setShowFirst] = useState(true);

  return (
    <div>
      {showFirst && <Counter key="first" />}
      <Counter key="second" />
    </div>
  );
}
```

**When showFirst becomes false:**
- React: "Where's key='first'?" → Removed, destroy it
- React: "Where's key='second'?" → Still here, keep it

Now the second Counter keeps its own state.

---

## The Four Uses of Keys

### Use 1: List Items (The Obvious One)

```jsx
function TodoList({ todos }) {
  return (
    <ul>
      {todos.map(todo => (
        <li key={todo.id}>{todo.text}</li>
      ))}
    </ul>
  );
}
```

Keys help React efficiently update lists when items are added, removed, or reordered.

### Use 2: Resetting Component State

Sometimes you WANT state to reset:

```jsx
function ChatRoom({ recipientId }) {
  // Problem: switching recipients keeps the same MessageInput
  // The draft message from Alice shows when you switch to Bob
  return (
    <div>
      <MessageInput />
    </div>
  );
}

// Solution: key forces remount
function ChatRoom({ recipientId }) {
  return (
    <div>
      <MessageInput key={recipientId} />
    </div>
  );
}
// Switching recipients creates a NEW MessageInput instance
```

### Use 3: Preserving Identity Across Moves

```jsx
function App() {
  const [position, setPosition] = useState('left');

  return (
    <div>
      {position === 'left' && (
        <div className="left">
          <VideoPlayer key="main-video" />
        </div>
      )}
      {position === 'right' && (
        <div className="right">
          <VideoPlayer key="main-video" />
        </div>
      )}
    </div>
  );
}
// Same key = React preserves the instance
// Video playback continues when moving from left to right
```

### Use 4: Forcing Re-creation

```jsx
function Form() {
  const [version, setVersion] = useState(0);

  return (
    <div>
      <button onClick={() => setVersion(v => v + 1)}>
        Reset Form
      </button>
      <ComplexForm key={version} />
    </div>
  );
}
// Clicking "Reset Form" increments version
// Different key = new ComplexForm instance
// All form state is cleared
```

---

## Key Anti-Patterns

### Anti-Pattern 1: Math.random() as Key

```jsx
// NEVER DO THIS
{items.map(item => (
  <Item key={Math.random()} data={item} />
))}

// Every render generates new keys
// React thinks ALL items are new
// Destroys and recreates everything
// Terrible performance, loses all state
```

### Anti-Pattern 2: Index as Key (Usually)

```jsx
// RISKY
{items.map((item, index) => (
  <Item key={index} data={item} />
))}
```

**Problems when items can be reordered, inserted, or deleted:**
- Input focus/selection lost
- Animation glitches
- State applied to wrong items

**Index keys are OK when:**
- List is static (never reorders)
- Items have no state or identity
- List is never filtered or sorted

When in doubt, use stable IDs.

### Anti-Pattern 3: Composite Keys with Changing Parts

```jsx
// PROBLEMATIC
{items.map((item, index) => (
  <Item key={`${item.type}-${index}`} data={item} />
))}

// If item.type or index changes, key changes
// React treats it as a new element
```

### Anti-Pattern 4: Non-Unique Keys

```jsx
// React will warn, and behavior is undefined
{items.map(item => (
  <Item key={item.category} data={item} />
  // Multiple items might have same category!
))}
```

Keys must be unique among siblings.

---

## Where Keys Are Evaluated

Keys exist at the parent level, not the child level:

```jsx
// Key belongs to the map's perspective
function Parent() {
  return items.map(item => (
    <Child key={item.id} data={item} />
    // Key is Parent's way of tracking Child instances
  ));
}

function Child({ data }) {
  // Child doesn't know or care about its key
  // Key is not passed as a prop
  console.log(props.key);  // undefined!
}
```

If you need the ID inside the child, pass it explicitly:

```jsx
<Child key={item.id} id={item.id} data={item} />
```

---

## Keys and Reconciliation Deep Dive

Let's trace exactly what happens:

```jsx
// Render 1
<ul>
  <li key="a">Apple</li>
  <li key="b">Banana</li>
  <li key="c">Cherry</li>
</ul>

// Render 2: Cherry moved to front
<ul>
  <li key="c">Cherry</li>
  <li key="a">Apple</li>
  <li key="b">Banana</li>
</ul>
```

**React's process:**

1. Build a map of old children: `{ a: <li>Apple</li>, b: <li>Banana</li>, c: <li>Cherry</li> }`

2. Walk through new children:
   - Position 0, key="c": Found in old map, reuse
   - Position 1, key="a": Found in old map, reuse
   - Position 2, key="b": Found in old map, reuse

3. DOM operations: Move nodes to match new order

**Without keys:**

1. Compare by position:
   - Position 0: "Apple" → "Cherry" (update text)
   - Position 1: "Banana" → "Apple" (update text)
   - Position 2: "Cherry" → "Banana" (update text)

2. DOM operations: Three text updates

With keys: 3 moves (cheap).
Without keys: 3 text updates (also cheap in this case, but state would be wrong).

---

## The Mental Model

Think of keys as **names** for elements:

- Without keys: "The first child, the second child..."
- With keys: "Alice, Bob, Charlie..."

When you say "Alice moved from position 1 to position 3," that's meaningful.
When you say "The first child is now different," you're describing replacement, not movement.

---

## Key Takeaways

1. **Keys create identity** — They tell React "this IS this element"
2. **Position is default identity** — Without keys, React uses order
3. **Use stable, unique IDs** — Not indices, not random values
4. **Keys can reset state** — Different key = new instance
5. **Keys enable efficient updates** — Moves instead of recreations
6. **Keys exist at the parent level** — Not passed as props to child

Understanding keys deeply means understanding how React sees your component tree—not as code, but as a living structure with persistent identities.

---

*Next: [Chapter 12: Props and One-Way Data Flow](../PART-4-DATA-FLOW/12-props-one-way-flow.md)*
