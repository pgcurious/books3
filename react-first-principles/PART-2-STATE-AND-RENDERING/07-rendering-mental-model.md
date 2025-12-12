# Chapter 7: The Rendering Mental Model

> *"Rendering is not DOM mutation. Rendering is asking your components what they want to show."*
> — Dan Abramov

---

## What "Render" Actually Means

The word "render" is overloaded. Let's be precise.

In React, "rendering" means **calling your component function**.

```jsx
function Greeting({ name }) {
  console.log('Greeting rendered');  // This runs during "render"
  return <h1>Hello, {name}</h1>;
}
```

Rendering is *not* the same as updating the DOM. React renders (calls your functions) to figure out what the DOM *should* look like. Then, separately, it updates the DOM to match.

---

## The Two Phases

React's work happens in two distinct phases:

### Phase 1: Render Phase

**What happens:** React calls your component functions.

```jsx
function App() {
  return (
    <div>
      <Header />      {/* React calls Header() */}
      <Content />     {/* React calls Content() */}
      <Footer />      {/* React calls Footer() */}
    </div>
  );
}
```

**Result:** A tree of React elements (often called "virtual DOM")

```javascript
// What React has after rendering:
{
  type: 'div',
  props: {
    children: [
      { type: Header, props: {} },
      { type: Content, props: {} },
      { type: Footer, props: {} }
    ]
  }
}
```

**Key insight:** No DOM is touched yet. This is pure computation.

### Phase 2: Commit Phase

**What happens:** React updates the actual DOM to match the render result.

```javascript
// React compares new tree to old tree
// Finds differences
// Applies minimal DOM mutations
document.getElementById('header').textContent = 'New Title';
```

**Key insight:** Only necessary updates are applied. If nothing changed, the DOM isn't touched.

---

## Why Two Phases?

This separation is powerful:

### Reason 1: Computation is Cheap, DOM is Expensive

JavaScript objects are fast to create and compare. DOM operations are slow.

```javascript
// Fast: Creating JavaScript objects
const element = { type: 'div', props: { className: 'box' } };

// Slow: Creating/modifying DOM nodes
const div = document.createElement('div');
div.className = 'box';
document.body.appendChild(div);
```

By doing all the "figuring out" in JavaScript first, React minimizes expensive DOM work.

### Reason 2: Batching

Multiple state updates can be batched into one commit:

```jsx
function handleClick() {
  setCount(count + 1);
  setName('Alice');
  setActive(true);

  // React batches these: one render, one commit
  // Not: render-commit-render-commit-render-commit
}
```

### Reason 3: Interruptibility

The render phase can be interrupted (in concurrent mode):

```jsx
// React starts rendering a huge list
// User clicks a button
// React can pause the list render
// Handle the click first
// Resume the list render later
```

This is only possible because rendering doesn't touch the DOM. You can safely abandon incomplete render work.

---

## When Does React Render?

React re-renders a component when:

### 1. Initial Mount

```jsx
// First time component appears
ReactDOM.render(<App />, document.getElementById('root'));
// App and all its children render
```

### 2. State Change

```jsx
function Counter() {
  const [count, setCount] = useState(0);

  // Calling setCount triggers a render of Counter
  return <button onClick={() => setCount(count + 1)}>{count}</button>;
}
```

### 3. Parent Renders

When a parent renders, all children render too (by default):

```jsx
function Parent() {
  const [count, setCount] = useState(0);

  // When Parent re-renders, Child re-renders too
  return (
    <div>
      <p>{count}</p>
      <Child />  {/* Re-renders even though no props changed */}
    </div>
  );
}
```

**This surprises people.** Child re-rendering doesn't mean Child's DOM changes—that depends on the commit phase finding differences.

### 4. Context Change

```jsx
const ThemeContext = React.createContext('light');

function App() {
  const [theme, setTheme] = useState('light');

  return (
    <ThemeContext.Provider value={theme}>
      <Page />
    </ThemeContext.Provider>
  );
}

function DeepChild() {
  const theme = useContext(ThemeContext);
  // When theme changes, DeepChild re-renders
  return <div className={theme}>...</div>;
}
```

---

## The Render Tree

When React renders, it renders a **tree**, not individual components:

```
App renders
├── Header renders
├── Sidebar renders
│   ├── NavItem renders
│   ├── NavItem renders
│   └── NavItem renders
├── Content renders
│   └── Article renders
└── Footer renders
```

If you update state in `App`, the entire tree re-renders. But this doesn't mean the entire DOM is rebuilt—only components whose *output* changed will cause DOM mutations.

---

## Renders Are Cheap (Usually)

A common misconception: "Too many renders are bad."

**Reality:** Renders are JavaScript function calls. They're fast.

```jsx
// This is just calling functions
function App() {
  return <div><Header /><Content /><Footer /></div>;
}

// It's like:
function app() {
  return { children: [header(), content(), footer()] };
}

// Function calls are fast
```

**What's expensive:**
- DOM mutations (minimized by diffing)
- Slow code inside components
- Re-rendering huge lists without virtualization

**What's usually fine:**
- A component re-rendering
- Re-computing derived state
- Creating new element objects

Don't optimize renders until you measure a real problem.

---

## A Complete Example

Let's trace rendering through a realistic example:

```jsx
function App() {
  const [count, setCount] = useState(0);

  console.log('App render');

  return (
    <div>
      <Header />
      <Counter count={count} setCount={setCount} />
      <Footer />
    </div>
  );
}

function Header() {
  console.log('Header render');
  return <h1>My App</h1>;
}

function Counter({ count, setCount }) {
  console.log('Counter render');
  return (
    <button onClick={() => setCount(count + 1)}>
      Count: {count}
    </button>
  );
}

function Footer() {
  console.log('Footer render');
  return <footer>2024</footer>;
}
```

**Initial mount:**
```
App render
Header render
Counter render
Footer render
```

**After clicking button:**
```
App render       // State changed here
Header render    // Child of App, so re-renders
Counter render   // Child of App, so re-renders
Footer render    // Child of App, so re-renders
```

**But the DOM?** Only the button text (`Count: 0` → `Count: 1`) actually changes. Header and Footer re-rendered but their output was identical, so React doesn't touch their DOM.

---

## The Mental Model

Think of rendering like this:

1. **Something triggers a render** (state change, props change, etc.)
2. **React calls your function** with current props/state
3. **Your function returns JSX** describing what to show
4. **React compares** new output to previous output
5. **React commits** only the differences to the DOM

The key insight: **Re-rendering is React asking "what should this look like now?"** It's not "update everything."

---

## Key Takeaways

1. **Rendering = calling your component function**, not updating DOM
2. **Two phases**: Render (compute) and Commit (update DOM)
3. **Triggers**: Initial mount, state change, parent re-render, context change
4. **Re-renders are cheap** — Don't optimize prematurely
5. **DOM updates are minimal** — React only commits actual differences
6. **Children re-render with parents** — By default, the whole subtree re-renders

---

*Next: [Chapter 8: When React Re-renders](./08-when-react-rerenders.md)*
