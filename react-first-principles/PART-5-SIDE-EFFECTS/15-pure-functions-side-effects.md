# Chapter 15: Pure Functions and Side Effects

> *"A function should do one thing, and do it well."*
> — Unix philosophy

---

## What Is a Pure Function?

A pure function:

1. **Given the same inputs, always returns the same output**
2. **Has no side effects** — doesn't modify anything outside itself

```javascript
// PURE: Same input → same output, no side effects
function add(a, b) {
  return a + b;
}

add(2, 3);  // Always 5
add(2, 3);  // Always 5
add(2, 3);  // Always 5

// IMPURE: Output depends on external state
let tax = 0.1;
function calculateTotal(price) {
  return price + (price * tax);  // Depends on external `tax`
}

// IMPURE: Modifies external state (side effect)
let count = 0;
function increment() {
  count++;  // Changes something outside the function
}
```

---

## Why Purity Matters in React

React's rendering model assumes your components are pure functions:

```jsx
function Greeting({ name }) {
  return <h1>Hello, {name}</h1>;
}
```

**Same props → Same output.** This is why React works:

- React can skip re-rendering if props haven't changed
- React can render in any order
- React can pause and resume rendering
- React can discard incomplete renders
- React can call your component multiple times

If components weren't pure, none of this would be safe.

---

## Side Effects: The Impure Reality

But real applications need side effects:

- Fetching data from APIs
- Subscribing to events
- Manipulating the DOM directly
- Logging
- Setting timers
- Writing to localStorage

These are all **side effects** — things that affect the world outside your function.

```jsx
// This component is IMPURE
function BadComponent({ userId }) {
  // Side effect during render!
  fetch(`/api/users/${userId}`);

  // Side effect during render!
  document.title = 'Loading...';

  return <div>Loading...</div>;
}
```

**Problems:**
- Fetch fires on every render (including React's test renders in StrictMode)
- Document title changes happen at unpredictable times
- No cleanup when component unmounts
- Can't be aborted if userId changes before request completes

---

## The React Solution: useEffect

React provides `useEffect` to handle side effects safely:

```jsx
function GoodComponent({ userId }) {
  const [user, setUser] = useState(null);

  useEffect(() => {
    // Side effect in the RIGHT place
    fetch(`/api/users/${userId}`)
      .then(res => res.json())
      .then(data => setUser(data));
  }, [userId]);  // Only run when userId changes

  if (!user) return <div>Loading...</div>;
  return <div>{user.name}</div>;
}
```

**Key insight:** Rendering is pure. Effects are impure. They're separated.

---

## The Mental Model

Think of rendering in two phases:

### Phase 1: Render (Pure)

```jsx
function Component({ data }) {
  // This part should be pure:
  // - Calculate values
  // - Create JSX
  // - Return output
  const processed = processData(data);
  return <div>{processed}</div>;
}
```

Rules during render:
- No fetching
- No subscriptions
- No DOM manipulation
- No timers
- No logging (for side effects)

### Phase 2: Effect (Impure)

```jsx
function Component({ data }) {
  useEffect(() => {
    // This part can be impure:
    // - Fetch data
    // - Subscribe to events
    // - Modify DOM
    // - Set timers
    console.log('Component mounted');
    document.title = data.title;
  }, [data]);

  return <div>{data.content}</div>;
}
```

Effects run *after* render, when the DOM has been updated.

---

## What Counts as a Side Effect?

### Side Effects (Use useEffect)

```jsx
// Fetching data
useEffect(() => {
  fetchUser(userId).then(setUser);
}, [userId]);

// Subscriptions
useEffect(() => {
  const subscription = events.subscribe(handleEvent);
  return () => subscription.unsubscribe();
}, []);

// Manual DOM changes
useEffect(() => {
  inputRef.current.focus();
}, []);

// Timers
useEffect(() => {
  const timer = setInterval(tick, 1000);
  return () => clearInterval(timer);
}, []);

// Logging for analytics
useEffect(() => {
  analytics.pageView(page);
}, [page]);
```

### NOT Side Effects (OK during render)

```jsx
// Creating objects
const user = { name: props.firstName + ' ' + props.lastName };

// Filtering/mapping
const activeItems = items.filter(item => item.active);

// Calculations
const total = items.reduce((sum, item) => sum + item.price, 0);

// Conditional logic
if (isLoading) return <Spinner />;
```

These are pure computations — they don't affect the outside world.

---

## Rules of useEffect

### Rule 1: Effects Run After Render

```jsx
function Component() {
  console.log('1. Render');

  useEffect(() => {
    console.log('2. Effect');
  });

  return <div>Hello</div>;
}

// Output:
// 1. Render
// 2. Effect
```

React renders, commits to DOM, then runs effects.

### Rule 2: Dependencies Control When Effects Run

```jsx
// Run on EVERY render
useEffect(() => {
  console.log('Every render');
});

// Run ONCE on mount
useEffect(() => {
  console.log('Only on mount');
}, []);  // Empty array = no dependencies

// Run when userId changes
useEffect(() => {
  console.log('userId changed:', userId);
}, [userId]);  // Run when userId changes
```

### Rule 3: Return a Cleanup Function

```jsx
useEffect(() => {
  // Setup
  const subscription = source.subscribe();

  // Cleanup (runs before next effect and on unmount)
  return () => {
    subscription.unsubscribe();
  };
}, [source]);
```

---

## A Common Mistake

```jsx
// WRONG: Reading state that updates in the effect
function BadCounter() {
  const [count, setCount] = useState(0);

  useEffect(() => {
    const timer = setInterval(() => {
      setCount(count + 1);  // `count` is always 0!
    }, 1000);
    return () => clearInterval(timer);
  }, []);  // Empty deps means `count` is captured once

  return <div>{count}</div>;
}
```

**Problem:** The effect closes over `count = 0`. It never sees updated values.

**Solution 1:** Add count to dependencies (but then timer resets every second):
```jsx
useEffect(() => { ... }, [count]);
```

**Solution 2:** Use functional update:
```jsx
useEffect(() => {
  const timer = setInterval(() => {
    setCount(c => c + 1);  // Uses current value, not closed-over value
  }, 1000);
  return () => clearInterval(timer);
}, []);
```

---

## The Philosophy

Separating pure rendering from impure effects is powerful:

1. **Predictability:** Render is always deterministic
2. **Testability:** You can test rendering without mocking fetch
3. **Optimization:** React can safely re-run renders
4. **Debugging:** Effects are isolated, with clear timing

Think of it as: "Tell me what to show" (render) vs "Tell me what to do" (effect).

---

## Key Takeaways

1. **Pure functions** return same output for same input, no side effects
2. **React rendering should be pure** — no effects during render
3. **useEffect is for side effects** — runs after render
4. **Effects run after commit** — DOM is ready
5. **Dependencies control timing** — empty = once, values = when they change
6. **Cleanup prevents leaks** — return a function to clean up
7. **Watch for stale closures** — use functional updates when needed

Understanding the pure/impure boundary is essential. It's why React can be fast, predictable, and concurrent.

---

*Next: [Chapter 16: The useEffect Mental Model](./16-useeffect-mental-model.md)*
