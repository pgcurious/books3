# Chapter 4: Components as Functions

> *"The purpose of abstraction is not to be vague, but to create a new semantic level in which one can be absolutely precise."*
> — Edsger W. Dijkstra

---

## What Is a Component?

Here's the simplest possible definition:

**A component is a function that returns UI.**

```jsx
function Greeting() {
  return <h1>Hello, World!</h1>;
}
```

That's it. Everything else in React builds on this foundation.

---

## Why Functions?

This isn't arbitrary. Functions are the most fundamental abstraction in programming, and they have exactly the properties we need for building UIs.

### Property 1: Input → Output

A function takes inputs and produces outputs.

```jsx
function Greeting({ name }) {
  return <h1>Hello, {name}!</h1>;
}

// Input: { name: "Alice" }
// Output: <h1>Hello, Alice!</h1>

// Input: { name: "Bob" }
// Output: <h1>Hello, Bob!</h1>
```

The UI is determined entirely by the inputs. This is the foundation of predictability.

### Property 2: Composition

Functions can call other functions.

```jsx
function Welcome({ user }) {
  return (
    <div>
      <Greeting name={user.name} />
      <Avatar image={user.avatar} />
    </div>
  );
}
```

Complex UIs are built by composing simple components. Each component is a self-contained unit that doesn't need to know about its context.

### Property 3: Reusability

Define once, use anywhere.

```jsx
function Button({ label, onClick }) {
  return <button onClick={onClick}>{label}</button>;
}

// Use it everywhere
<Button label="Save" onClick={save} />
<Button label="Cancel" onClick={cancel} />
<Button label="Delete" onClick={delete} />
```

The same `Button` component works in any context. It doesn't care where it's used.

### Property 4: Testability

Functions are easy to test—pass inputs, check outputs.

```jsx
// Testing is straightforward
const output = Greeting({ name: 'Test' });
expect(output.props.children).toContain('Test');
```

No need to set up DOM environments, trigger events, or inspect rendered pixels. The component is just a function.

---

## The Evolution of React Components

React components weren't always this simple. Understanding the evolution illuminates the design.

### Era 1: Class Components

The original React used classes:

```jsx
class Greeting extends React.Component {
  render() {
    return <h1>Hello, {this.props.name}!</h1>;
  }
}
```

Classes provided:
- Lifecycle methods (`componentDidMount`, `componentWillUnmount`)
- State management (`this.state`, `this.setState`)
- Instance methods and properties

But classes had problems:
- `this` binding confusion
- Lifecycle methods split related logic
- Hard to reuse stateful logic between components
- Verbose syntax for simple things

### Era 2: Function Components

Initially, function components were "stateless":

```jsx
// "Stateless functional component" — no state, no lifecycle
function Greeting({ name }) {
  return <h1>Hello, {name}!</h1>;
}
```

These were simpler but limited. You still needed classes for state or side effects.

### Era 3: Hooks

In 2019, Hooks changed everything:

```jsx
function Counter() {
  const [count, setCount] = useState(0);

  useEffect(() => {
    document.title = `Count: ${count}`;
  }, [count]);

  return <button onClick={() => setCount(count + 1)}>{count}</button>;
}
```

Hooks let function components:
- Have state (`useState`)
- Run side effects (`useEffect`)
- Reuse stateful logic (custom hooks)

Now the simplest mental model—component as function—applies to *all* components.

---

## The Function Mental Model

Think of rendering your entire app as a function call:

```jsx
UI = f(state)
```

- `state` is all the data in your app
- `f` is your component tree
- `UI` is what appears on screen

When state changes, you "call the function again":

```jsx
// State: { count: 0 }
// UI: <div>0</div>

// State changes to { count: 1 }
// UI: <div>1</div>

// It's like calling the function with new arguments
```

React handles everything between "state changed" and "new UI appears."

---

## What About the Weird Stuff?

"But functions run once and return. How does my component update over time?"

This is where the mental model needs nuance.

### Renders Are Function Calls

Every time React "renders" a component, it's calling your function:

```jsx
function Counter({ initialValue }) {
  const [count, setCount] = useState(initialValue);

  console.log('Counter called with count:', count);

  return <button onClick={() => setCount(count + 1)}>{count}</button>;
}

// When mounted: "Counter called with count: 0"
// After click:   "Counter called with count: 1"
// After click:   "Counter called with count: 2"
```

Your function is called multiple times over the component's lifetime. Each call is a "render."

### State Persists Between Calls

`useState` gives you a value that persists across renders:

```jsx
function Counter() {
  // React remembers this value between renders
  const [count, setCount] = useState(0);

  // Each render, count is the current value
  return <button onClick={() => setCount(count + 1)}>{count}</button>;
}
```

How does React remember? It maintains a linked list of state values for each component instance. `useState` returns the "current" value for that slot.

### Each Render Is a Snapshot

Here's a crucial insight:

```jsx
function Counter() {
  const [count, setCount] = useState(0);

  const handleClick = () => {
    setCount(count + 1);
    console.log(count);  // Still logs the OLD count
  };

  return <button onClick={handleClick}>{count}</button>;
}
```

Why? Because `count` is a constant for this render. It's not a live binding that changes. It's the value `count` had when this function was called.

Think of it as:

```jsx
// First render
function Counter() {
  const count = 0;  // For this render, count IS 0
  // ...
}

// Second render
function Counter() {
  const count = 1;  // For this render, count IS 1
  // ...
}
```

Each render is a self-contained snapshot with its own values.

---

## The Power of This Model

This simple model—components are functions that return UI—enables powerful patterns:

### Pattern 1: Transformation

Components can transform data before displaying it:

```jsx
function FormattedDate({ timestamp }) {
  const date = new Date(timestamp);
  const formatted = date.toLocaleDateString();
  return <span>{formatted}</span>;
}
```

### Pattern 2: Conditional Rendering

Functions can return different outputs based on conditions:

```jsx
function Greeting({ isLoggedIn, userName }) {
  if (isLoggedIn) {
    return <h1>Welcome back, {userName}!</h1>;
  }
  return <h1>Please sign in</h1>;
}
```

### Pattern 3: List Rendering

Functions can generate multiple elements:

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

### Pattern 4: Composition

Components contain other components:

```jsx
function App() {
  return (
    <Layout>
      <Header />
      <Sidebar />
      <Content>
        <Article />
        <Comments />
      </Content>
      <Footer />
    </Layout>
  );
}
```

---

## Why Not Templates?

Some frameworks use templates:

```html
<!-- Vue template -->
<template>
  <div v-if="isLoading">Loading...</div>
  <div v-else>{{ data }}</div>
</template>
```

React uses JavaScript directly:

```jsx
function DataView({ isLoading, data }) {
  if (isLoading) return <div>Loading...</div>;
  return <div>{data}</div>;
}
```

**React's approach:**
- Uses full power of JavaScript (loops, conditions, variables)
- No special template syntax to learn
- IDE support, type checking, and refactoring work out of the box
- Components are just functions—all function patterns apply

**The trade-off:**
- Templates can be analyzed statically for optimization
- Templates enforce separation of logic and presentation
- JSX can feel unfamiliar at first

React chose expressiveness and JavaScript integration over template constraints.

---

## Key Takeaways

1. **Components are functions** that take props and return UI
2. **Each render is a function call** with the current props and state
3. **State persists between calls** via `useState`
4. **Each render is a snapshot** with its own values
5. **Functions compose** — complex UIs built from simple components
6. **JavaScript's full power** is available — no template limitations

Understanding components as functions is the foundation. Everything else in React builds on this idea.

---

*Next: [Chapter 5: The UI as a Function of State](./05-ui-as-function-of-state.md)*
