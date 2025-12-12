# Chapter 8: When React Re-renders

> *"Premature optimization is the root of all evil."*
> — Donald Knuth

---

## The Rules of Re-rendering

Understanding when React re-renders is crucial. Not for optimization (yet), but for building correct mental models.

### Rule 1: A Component Re-renders When Its State Changes

```jsx
function Counter() {
  const [count, setCount] = useState(0);

  // setCount(newValue) triggers a re-render of Counter
  return <button onClick={() => setCount(count + 1)}>{count}</button>;
}
```

This is the most obvious case. You change state, the component re-renders.

### Rule 2: A Component Re-renders When Its Parent Re-renders

```jsx
function Parent() {
  const [count, setCount] = useState(0);

  return (
    <div>
      <button onClick={() => setCount(count + 1)}>Increment</button>
      <Child />  {/* Re-renders every time Parent re-renders */}
    </div>
  );
}

function Child() {
  console.log('Child rendered');
  return <div>I am a child</div>;
}
```

**This surprises people.** Child has no props, no state, nothing changing—yet it re-renders.

**Why?** React's default assumption is: if the parent changed, the child might need to change too. It's a safe default.

### Rule 3: Context Changes Trigger Re-renders

```jsx
const ThemeContext = React.createContext('light');

function App() {
  const [theme, setTheme] = useState('light');

  return (
    <ThemeContext.Provider value={theme}>
      <DeepComponent />  {/* Re-renders when theme changes */}
    </ThemeContext.Provider>
  );
}

function DeepComponent() {
  const theme = useContext(ThemeContext);
  return <div className={theme}>Content</div>;
}
```

Any component that calls `useContext` will re-render when the context value changes.

---

## What Does NOT Trigger Re-renders

### Changing Local Variables

```jsx
function Broken() {
  let count = 0;

  return (
    <button onClick={() => {
      count++;  // Changes, but React doesn't know
      console.log(count);  // Shows updated value
    }}>
      {count}  {/* Always shows 0 */}
    </button>
  );
}
```

Local variables don't trigger re-renders. React only reacts to `useState`, `useReducer`, and context changes.

### Mutating State Directly

```jsx
function AlsoBroken() {
  const [user, setUser] = useState({ name: 'Alice', age: 25 });

  return (
    <button onClick={() => {
      user.age = 26;  // MUTATES the existing object
      setUser(user);  // Same reference, React thinks nothing changed
    }}>
      Age: {user.age}
    </button>
  );
}
```

React uses reference equality to detect changes. If you mutate an object and pass the same reference to `setState`, React sees "same object" and may skip the re-render.

**Always create new references:**

```jsx
function Fixed() {
  const [user, setUser] = useState({ name: 'Alice', age: 25 });

  return (
    <button onClick={() => {
      setUser({ ...user, age: 26 });  // NEW object with updated age
    }}>
      Age: {user.age}
    </button>
  );
}
```

### Passing Same Props

```jsx
function Parent() {
  const [count, setCount] = useState(0);
  const data = { value: 'constant' };  // NEW object every render

  return <Child data={data} />;  // Child re-renders even though "data" looks the same
}
```

Wait, this DOES trigger re-renders! But the data looks the same?

The issue: `{ value: 'constant' } !== { value: 'constant' }`. Each render creates a new object. Different reference = different props.

```jsx
// To truly prevent re-renders, memoize the value:
function Parent() {
  const [count, setCount] = useState(0);
  const data = useMemo(() => ({ value: 'constant' }), []);  // Same reference always

  return <MemoizedChild data={data} />;
}

const MemoizedChild = React.memo(Child);
```

---

## The Rendering Cascade

Let's trace a realistic example:

```jsx
function App() {
  const [user, setUser] = useState({ name: 'Alice' });

  return (
    <div>
      <Header user={user} />
      <Sidebar />
      <Main>
        <Profile user={user} onUpdate={setUser} />
        <Feed />
      </Main>
    </div>
  );
}
```

When `setUser` is called in `Profile`:

```
1. App re-renders (state changed)
   2. Header re-renders (parent re-rendered)
   3. Sidebar re-renders (parent re-rendered)
   4. Main re-renders (parent re-rendered)
      5. Profile re-renders (parent re-rendered)
      6. Feed re-renders (parent re-rendered)
```

**Everything re-renders**, even though only `Header` and `Profile` actually use the `user` data.

---

## Should You Care?

**Usually, no.**

React is fast. Re-rendering a component that produces identical output is cheap. The expensive part—DOM mutations—only happens when output differs.

### When Re-renders Are Fine

```jsx
// This is totally fine
function App() {
  const [theme, setTheme] = useState('light');

  return (
    <div className={theme}>
      <Header />     {/* Re-renders when theme changes, but so what? */}
      <Content />    {/* 50 components deep, still fast */}
      <Footer />
    </div>
  );
}
```

### When Re-renders Become a Problem

```jsx
// This might be a problem
function VerySlowList({ items }) {
  return (
    <div>
      {items.map(item => (
        <VeryExpensiveComponent key={item.id} data={item} />
      ))}
    </div>
  );
}

// If VeryExpensiveComponent takes 5ms to render
// And you have 100 items
// That's 500ms of blocking work
// Users notice delays > 100ms
```

---

## The React.memo Escape Hatch

When re-renders ARE a problem, `React.memo` helps:

```jsx
const MemoizedComponent = React.memo(function MyComponent({ name }) {
  console.log('Rendering');
  return <div>{name}</div>;
});

function Parent() {
  const [count, setCount] = useState(0);

  return (
    <div>
      <button onClick={() => setCount(count + 1)}>
        Count: {count}
      </button>
      <MemoizedComponent name="Alice" />  {/* Won't re-render */}
    </div>
  );
}
```

`React.memo` wraps a component and skips re-rendering if props haven't changed (shallow comparison).

### But Be Careful

```jsx
function Parent() {
  const [count, setCount] = useState(0);

  // This creates a NEW function every render
  const handleClick = () => console.log('clicked');

  // This creates a NEW object every render
  const style = { color: 'red' };

  return (
    // memo is useless here—props are new references every time
    <MemoizedComponent onClick={handleClick} style={style} />
  );
}
```

For `memo` to work, props must have stable references:

```jsx
function Parent() {
  const [count, setCount] = useState(0);

  // useCallback: same function reference across renders
  const handleClick = useCallback(() => console.log('clicked'), []);

  // useMemo: same object reference across renders
  const style = useMemo(() => ({ color: 'red' }), []);

  return (
    <MemoizedComponent onClick={handleClick} style={style} />
  );
}
```

---

## The Optimization Mindset

Don't start with optimization. Start with correctness.

### The Process

1. **Build it correctly** — Make it work
2. **Measure** — Use React DevTools Profiler to find actual bottlenecks
3. **Optimize specifically** — Apply `memo`/`useMemo`/`useCallback` where profiler shows problems

### Common Mistake

```jsx
// Over-optimized code
const MemoizedEverything = React.memo(({ data }) => {
  const processedData = useMemo(() => process(data), [data]);
  const handleClick = useCallback(() => onClick(data.id), [data.id]);

  return <div onClick={handleClick}>{processedData}</div>;
});
```

This code is harder to read, and the optimizations might not help at all. Measure first.

---

## Key Takeaways

1. **State change** → component re-renders
2. **Parent re-renders** → children re-render (by default)
3. **Context change** → consumers re-render
4. **Mutations are invisible** — always create new references
5. **Re-renders are usually fine** — React is fast
6. **Measure before optimizing** — use React DevTools Profiler
7. **React.memo** is the escape hatch for expensive components

---

*Next: [Chapter 9: The Virtual DOM](../PART-3-RECONCILIATION/09-virtual-dom.md)*
