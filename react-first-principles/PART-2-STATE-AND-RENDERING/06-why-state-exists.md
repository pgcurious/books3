# Chapter 6: Why State Exists

> *"The only constant is change."*
> — Heraclitus

---

## The Fundamental Question

JavaScript already has variables. Why do we need a special concept called "state" in React?

```javascript
// Why not just this?
let count = 0;

function Counter() {
  return <button onClick={() => count++}>{count}</button>;
}
```

The answer reveals something deep about how React works.

---

## The Problem with Normal Variables

Let's trace what happens with a normal variable:

```jsx
let count = 0;

function Counter() {
  const handleClick = () => {
    count = count + 1;
    console.log('count is now:', count);
  };

  return <button onClick={handleClick}>{count}</button>;
}
```

When you click the button:
1. `count` becomes 1 (console shows "count is now: 1")
2. But the button still shows "0"
3. Click again: `count` becomes 2
4. Button still shows "0"

**Why?** Because React doesn't know `count` changed. It has no reason to call `Counter` again.

---

## Variables vs State: The Core Difference

**A variable** stores a value. Changing it does nothing else.

**State** stores a value *and tells React when it changes*.

```jsx
function Counter() {
  const [count, setCount] = useState(0);

  const handleClick = () => {
    setCount(count + 1);  // Changes value AND triggers re-render
  };

  return <button onClick={handleClick}>{count}</button>;
}
```

`setCount` does two things:
1. Updates the stored value
2. Schedules a re-render of the component

This is why state exists: **React needs to know when to re-render.**

---

## The Rendering Trigger System

Think of React like a sleeping guard. The guard doesn't constantly check if anything changed. Instead, certain events wake it up:

1. **Initial render** — When component first mounts
2. **State change** — When `setState` (or `setX` from `useState`) is called
3. **Props change** — When parent passes different props
4. **Context change** — When a consumed context value changes

**State is a deliberate trigger.** It's not just storing data; it's signaling "something relevant changed, please update."

---

## Why Not Auto-Detect Changes?

Some frameworks automatically detect when any variable changes. Why doesn't React?

### Attempt 1: Watch Everything

```javascript
// Hypothetical auto-watching React
let count = 0;  // React watches this somehow

function Counter() {
  return <button onClick={() => count++}>{count}</button>;
}

// When count changes, React automatically re-renders
```

**Problems:**
- How does React know which variables matter?
- Performance: watching every variable is expensive
- What about nested objects? How deep to watch?
- What about variables in libraries?

### Attempt 2: Proxies

```javascript
// Another hypothetical approach
const state = makeReactive({
  count: 0,
  user: { name: 'Alice' }
});

// Changes to state.count automatically trigger updates
```

**Problems:**
- Complex to implement correctly
- Must use special "reactive" wrappers everywhere
- Mutations are implicit—hard to track causality
- "Why did this update?" becomes hard to answer

### React's Choice: Explicit Over Implicit

React chose explicit state updates:

```jsx
const [count, setCount] = useState(0);
setCount(count + 1);  // Explicit: "I am changing state"
```

**Benefits:**
- Clear causality: `setCount` → re-render
- Predictable: you know exactly what triggers updates
- Debuggable: you can log/breakpoint at the `setCount` call
- Flexible: React can batch, delay, or prioritize updates

The "cost" is a few extra characters. The benefit is a maintainable, debuggable application.

---

## State vs Props

Both state and props can hold data. What's the difference?

### Props: Data Flowing Down

Props are like function arguments—passed from parent to child:

```jsx
function Parent() {
  return <Child name="Alice" age={25} />;
}

function Child({ name, age }) {
  // Child receives but cannot modify props
  return <div>{name} is {age}</div>;
}
```

**Props characteristics:**
- Passed from parent
- Read-only in the receiving component
- Component doesn't control them

### State: Data Living Inside

State is owned and managed by the component itself:

```jsx
function Counter() {
  const [count, setCount] = useState(0);  // Owned here

  return (
    <button onClick={() => setCount(count + 1)}>
      {count}
    </button>
  );
}
```

**State characteristics:**
- Created and owned by the component
- Can be changed by the component
- Persists across re-renders

### The Metaphor

Think of a person:
- **Props** are like their name and eye color—given to them, can't change
- **State** is like their mood—internal, changes based on events

---

## When to Use State

Use state when:

1. **Data changes over time** and the UI should reflect those changes
2. **User interactions** need to be tracked
3. **Async responses** (like API data) need to be stored
4. **Derived from nothing else** — if you can compute it from other state/props, don't store it

### Good Uses of State

```jsx
// User input
const [searchQuery, setSearchQuery] = useState('');

// Toggle states
const [isOpen, setIsOpen] = useState(false);

// Fetched data
const [users, setUsers] = useState([]);

// Form data
const [formData, setFormData] = useState({ email: '', password: '' });
```

### Bad Uses of State

```jsx
// DON'T: Storing derived data
const [todos, setTodos] = useState([...]);
const [completedTodos, setCompletedTodos] = useState(
  todos.filter(t => t.done)  // This can be computed!
);

// DO: Compute during render
const completedTodos = todos.filter(t => t.done);
```

```jsx
// DON'T: Storing props in state (usually)
function Child({ initialValue }) {
  const [value, setValue] = useState(initialValue);
  // If initialValue changes, state won't update!
  // This "mirrors" props, creating sync problems
}

// DO: Use prop directly, or use a key to reset
<Child key={id} initialValue={data} />
```

---

## The useState API

`useState` is deliberately simple:

```jsx
const [value, setValue] = useState(initialValue);
```

- **`value`**: The current state value
- **`setValue`**: Function to update it
- **`initialValue`**: Starting value (used only on first render)

### The Array Destructuring

Why an array, not an object?

```jsx
// Array allows custom naming
const [count, setCount] = useState(0);
const [name, setName] = useState('');
const [items, setItems] = useState([]);

// Object would require consistent keys
const { value: count, setValue: setCount } = useState(0);  // Awkward
```

### Initial Value

The initial value is only used on the **first render**:

```jsx
function Counter({ startAt }) {
  const [count, setCount] = useState(startAt);

  // If startAt changes later, count does NOT update
  // useState(startAt) only runs on mount
}
```

For expensive initial values, pass a function:

```jsx
// DON'T: Runs expensive computation every render
const [data, setData] = useState(expensiveComputation());

// DO: Function only runs on first render
const [data, setData] = useState(() => expensiveComputation());
```

---

## State Is Per-Instance

Each component instance has its own state:

```jsx
function Counter() {
  const [count, setCount] = useState(0);
  return <button onClick={() => setCount(c => c + 1)}>{count}</button>;
}

function App() {
  return (
    <>
      <Counter />  {/* Has its own count */}
      <Counter />  {/* Has its own count */}
      <Counter />  {/* Has its own count */}
    </>
  );
}
```

Clicking one counter doesn't affect the others. State is scoped to the component instance, not the component definition.

---

## Key Takeaways

1. **State exists to trigger re-renders** — Normal variables don't notify React
2. **Explicit over implicit** — `setState` is a deliberate signal
3. **Props flow down, state lives within** — Different purposes, different sources
4. **Don't store what you can compute** — Derive values during render
5. **useState runs on first render** — Initial value is only used once
6. **State is per-instance** — Each component instance has its own state

Understanding why state exists—not just how to use it—is crucial to mastering React.

---

*Next: [Chapter 7: The Rendering Mental Model](./07-rendering-mental-model.md)*
