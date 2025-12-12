# Chapter 17: Cleanup and Dependencies

> *"Always clean up after yourself."*
> — Your mother, and also React

---

## Why Cleanup Matters

Effects often create things that persist: subscriptions, timers, connections. If you don't clean them up:

- Memory leaks
- Zombie listeners firing on unmounted components
- Multiple subscriptions stacking up
- Unexpected behavior

```jsx
// WITHOUT CLEANUP: Memory leak
function BadComponent({ userId }) {
  useEffect(() => {
    const ws = new WebSocket(`/users/${userId}`);
    ws.onmessage = (event) => {
      // Handle message
    };
    // WebSocket stays open forever!
  }, [userId]);
}

// WITH CLEANUP: Properly managed
function GoodComponent({ userId }) {
  useEffect(() => {
    const ws = new WebSocket(`/users/${userId}`);
    ws.onmessage = (event) => {
      // Handle message
    };

    return () => {
      ws.close();  // Clean up when userId changes or component unmounts
    };
  }, [userId]);
}
```

---

## When Cleanup Runs

Cleanup runs in two scenarios:

### 1. Before Re-running the Effect

```jsx
function Chat({ roomId }) {
  useEffect(() => {
    console.log(`Connecting to ${roomId}`);
    return () => console.log(`Disconnecting from ${roomId}`);
  }, [roomId]);
}

// roomId changes from "general" to "random":
// "Disconnecting from general"  ← cleanup from previous effect
// "Connecting to random"        ← setup for new effect
```

### 2. On Unmount

```jsx
// Component unmounts:
// "Disconnecting from random"  ← cleanup runs
```

**Key insight:** React always runs cleanup before running a new effect. This ensures you never have two effects active simultaneously.

---

## Common Cleanup Patterns

### Timers

```jsx
useEffect(() => {
  const timer = setInterval(() => {
    setSeconds(s => s + 1);
  }, 1000);

  return () => clearInterval(timer);
}, []);
```

### Event Listeners

```jsx
useEffect(() => {
  const handleResize = () => setWidth(window.innerWidth);
  window.addEventListener('resize', handleResize);

  return () => window.removeEventListener('resize', handleResize);
}, []);
```

### Subscriptions

```jsx
useEffect(() => {
  const unsubscribe = store.subscribe(() => {
    setData(store.getState());
  });

  return unsubscribe;
}, []);
```

### Fetch Requests

```jsx
useEffect(() => {
  let cancelled = false;

  async function fetchData() {
    const response = await fetch(`/api/data/${id}`);
    const data = await response.json();

    if (!cancelled) {
      setData(data);
    }
  }

  fetchData();

  return () => {
    cancelled = true;  // Prevent state update after unmount
  };
}, [id]);
```

Modern approach with AbortController:

```jsx
useEffect(() => {
  const controller = new AbortController();

  fetch(`/api/data/${id}`, { signal: controller.signal })
    .then(res => res.json())
    .then(setData)
    .catch(err => {
      if (err.name !== 'AbortError') {
        setError(err);
      }
    });

  return () => controller.abort();
}, [id]);
```

---

## Dependencies Deep Dive

### What Are Dependencies?

Dependencies are values from the component scope that the effect uses:

```jsx
function SearchResults({ query, category }) {
  const [results, setResults] = useState([]);

  useEffect(() => {
    // This effect uses `query` and `category`
    fetch(`/search?q=${query}&cat=${category}`)
      .then(res => res.json())
      .then(setResults);
  }, [query, category]);  // Both must be listed
}
```

### The Exhaustive Rule

Every value from the component scope used inside the effect should be in the dependencies.

```jsx
// WRONG: Missing dependency
useEffect(() => {
  const timer = setInterval(() => {
    setCount(count + 1);  // Uses `count`
  }, 1000);
  return () => clearInterval(timer);
}, []);  // `count` not listed!

// CORRECT: All deps listed (but timer resets each time)
useEffect(() => {
  const timer = setInterval(() => {
    setCount(count + 1);
  }, 1000);
  return () => clearInterval(timer);
}, [count]);

// BETTER: Functional update doesn't need `count` in scope
useEffect(() => {
  const timer = setInterval(() => {
    setCount(c => c + 1);  // Uses previous value, not scope
  }, 1000);
  return () => clearInterval(timer);
}, []);  // No dependencies needed!
```

### Reference Equality Matters

```jsx
function Parent() {
  const options = { showHeader: true };  // NEW object every render

  return <Child options={options} />;
}

function Child({ options }) {
  useEffect(() => {
    initializeWidget(options);
  }, [options]);  // Runs EVERY render because options is always new!
}
```

**Solutions:**

```jsx
// Solution 1: Memoize in parent
function Parent() {
  const options = useMemo(() => ({ showHeader: true }), []);
  return <Child options={options} />;
}

// Solution 2: List specific properties
function Child({ options }) {
  useEffect(() => {
    initializeWidget(options);
  }, [options.showHeader]);  // Only care about this property
}

// Solution 3: Move object inside effect
function Child({ showHeader }) {
  useEffect(() => {
    const options = { showHeader };
    initializeWidget(options);
  }, [showHeader]);
}
```

---

## Dependency Gotchas

### Functions as Dependencies

```jsx
// PROBLEM: Function recreated every render
function Component({ id }) {
  const fetchData = () => {
    return fetch(`/data/${id}`);
  };

  useEffect(() => {
    fetchData().then(setData);
  }, [fetchData]);  // New function every render = infinite loop!
}

// SOLUTION 1: Move function inside effect
useEffect(() => {
  const fetchData = () => fetch(`/data/${id}`);
  fetchData().then(setData);
}, [id]);

// SOLUTION 2: useCallback
const fetchData = useCallback(() => {
  return fetch(`/data/${id}`);
}, [id]);

useEffect(() => {
  fetchData().then(setData);
}, [fetchData]);
```

### Props That Are Objects or Arrays

```jsx
// PROBLEM: Parent passes new array each render
<Child items={items.filter(i => i.active)} />

// In Child:
useEffect(() => {
  processItems(items);
}, [items]);  // Runs every render!

// SOLUTION: Memoize in parent
const activeItems = useMemo(
  () => items.filter(i => i.active),
  [items]
);
<Child items={activeItems} />
```

---

## Empty Dependencies: The Mount-Only Pattern

```jsx
useEffect(() => {
  // Runs once on mount
  analytics.pageView();
}, []);
```

**This is appropriate when:**
- You intentionally want to run only once
- The effect doesn't use any values that change
- You're syncing with something constant

**Be careful:** If your effect uses props or state, an empty dependency array means it captures stale values.

---

## The Linter Is Your Friend

The `eslint-plugin-react-hooks` lint rule enforces dependency correctness.

```jsx
// Lint error: React Hook useEffect has a missing dependency: 'count'
useEffect(() => {
  document.title = `Count: ${count}`;
}, []);
```

**Don't suppress it without understanding why:**

```jsx
// BAD: Suppressing without thought
// eslint-disable-next-line react-hooks/exhaustive-deps
useEffect(() => { ... }, []);

// GOOD: Restructure to satisfy the linter
```

The linter catches real bugs. If it's complaining, investigate.

---

## Key Takeaways

1. **Cleanup prevents leaks** — Always clean up timers, subscriptions, connections
2. **Cleanup runs before re-sync** — Not just on unmount
3. **List all dependencies** — Everything from scope used in the effect
4. **Reference equality matters** — Same value !== same reference
5. **Functional updates avoid dependencies** — `setX(x => x + 1)` doesn't need `x` in deps
6. **Trust the linter** — It catches real bugs

Cleanup and dependencies are where effect bugs live. Master them, and your effects become reliable.

---

*Next: [Chapter 18: Putting It All Together](../PART-6-SYNTHESIS/18-putting-it-together.md)*
