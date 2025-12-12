# Chapter 5: The UI as a Function of State

> *"UI = f(state)"*
> — The most important equation in React

---

## The Core Equation

If you remember one thing from this entire book, remember this:

```
UI = f(state)
```

- **UI** is what appears on screen
- **state** is all the data your application knows about
- **f** is your component tree—the function that transforms state into UI

This equation is the heart of React. Everything else is implementation details.

---

## What Does This Mean?

### The UI Is Derived

Your UI is not an independent thing you manage. It's **derived** from state.

```jsx
// The state
const state = {
  user: { name: 'Alice', avatar: 'alice.jpg' },
  messages: [
    { id: 1, text: 'Hello', from: 'Bob' },
    { id: 2, text: 'Hi there!', from: 'Alice' }
  ],
  isLoading: false
};

// The function (simplified)
function App({ state }) {
  return (
    <div>
      <Header user={state.user} />
      <MessageList messages={state.messages} />
      {state.isLoading && <Spinner />}
    </div>
  );
}

// UI is the result of applying f to state
const ui = App({ state });
```

You don't update the UI. You update the state, and the UI automatically follows.

### Same State → Same UI

Given identical state, your components should return identical UI. Every time.

```jsx
function Counter({ count }) {
  return <div>{count}</div>;
}

// If count is 5, this ALWAYS returns <div>5</div>
// Not sometimes <div>5</div> and sometimes <div>6</div>
// The output is determined entirely by the input
```

This property is called **referential transparency** or **purity**. It's what makes React predictable.

### State Is the Single Source of Truth

There's only ONE place where truth lives: state.

The DOM is just a *reflection* of state—a projection, like a shadow on the wall. You don't reshape the shadow; you move the object casting it.

---

## Why This Model Is Powerful

### Power 1: Predictability

```jsx
// If you know the state, you know the UI
// No hidden variables, no mystery state in DOM elements
// Debugging becomes: "What's the state? What UI should that produce?"
```

### Power 2: Time Travel

If UI = f(state), then:
- Saving state gives you snapshots of your app
- Replaying state recreates past UIs
- This enables Redux DevTools, undo/redo, debugging

```jsx
// Record state over time
const history = [
  { count: 0 },  // t=0
  { count: 1 },  // t=1
  { count: 2 },  // t=2
];

// "Time travel" by rendering any historical state
render(<Counter count={history[1].count} />);  // Shows: 1
```

### Power 3: Server Rendering

Since UI = f(state):
- Run `f(state)` on the server
- Serialize the result as HTML
- Send to client
- Client "hydrates" with JavaScript

No special server logic needed—it's just calling your function.

### Power 4: Testing

```jsx
// Testing is trivial
// Input → Output, nothing else to consider

function Button({ disabled, label }) {
  return <button disabled={disabled}>{label}</button>;
}

// Test
expect(Button({ disabled: true, label: 'Submit' }))
  .toEqual(<button disabled={true}>Submit</button>);
```

---

## What Is "State"?

State is any data that:
1. Changes over time
2. Affects what appears on screen

### Types of State

**UI State:** Current tab, modal open/closed, input values

```jsx
const [activeTab, setActiveTab] = useState('home');
const [isModalOpen, setIsModalOpen] = useState(false);
const [searchQuery, setSearchQuery] = useState('');
```

**Server/Cache State:** Data from your backend

```jsx
const [user, setUser] = useState(null);
const [messages, setMessages] = useState([]);
const [isLoading, setIsLoading] = useState(true);
```

**Form State:** Current form values and validation

```jsx
const [formData, setFormData] = useState({
  email: '',
  password: '',
  errors: {}
});
```

**URL State:** Current route, query parameters

```jsx
// Often managed by a router
const { pathname, searchParams } = useLocation();
```

### Where State Lives

State should live as close as possible to where it's used, but high enough to be shared by all components that need it.

```
         App (owns: user, theme)
        /   \
     Header  Main
    (uses:   |
     user)   |
           Content (owns: messages)
            /   \
    MessageList  MessageForm
    (uses:       (updates:
     messages)    messages)
```

---

## The Rendering Mental Model

When state changes, React:

1. **Calls your function** with the new state
2. **Compares** the new result to the old result
3. **Updates** only the parts of the DOM that differ

```jsx
// State: { count: 0 }
function App() {
  const [count, setCount] = useState(0);
  return <div><span>{count}</span></div>;
}
// Result: <div><span>0</span></div>

// After setCount(1)
// State: { count: 1 }
// React calls App() again
// Result: <div><span>1</span></div>

// React compares:
//   <div><span>0</span></div>  (old)
//   <div><span>1</span></div>  (new)

// React updates: Just the text node inside <span>
```

You never tell React "update the span." You just describe what the UI should look like for count=1, and React figures out the minimal DOM operations.

---

## Breaking the Mental Model (and Why Not To)

### Anti-Pattern: Reading from DOM

```jsx
// DON'T DO THIS
function BadComponent() {
  const handleClick = () => {
    // Reading "truth" from DOM instead of state
    const currentValue = document.getElementById('input').value;
    // Now we have two sources of truth
  };
}
```

The DOM should be a *reflection* of state, not a *source* of state. When you read from the DOM, you're breaking `UI = f(state)`.

### Anti-Pattern: Direct DOM Manipulation

```jsx
// DON'T DO THIS
function BadComponent() {
  const handleClick = () => {
    // Mutating DOM directly
    document.getElementById('counter').textContent = '5';
    // React doesn't know about this!
    // State and UI are now out of sync
  };
}
```

If you manipulate the DOM directly, React's model breaks. On the next render, React will overwrite your changes—or worse, get confused about the current state.

### Anti-Pattern: Derived State

```jsx
// DON'T DO THIS
function BadComponent({ items }) {
  // Storing derived data as state
  const [filteredItems, setFilteredItems] = useState(items.filter(i => i.active));

  // Now you have to keep filteredItems in sync with items
  // Two sources of truth!
}

// DO THIS
function GoodComponent({ items }) {
  // Derive during render
  const filteredItems = items.filter(i => i.active);

  // No sync needed—filteredItems is always correct
}
```

Don't store what you can compute. State should be the minimal representation from which everything else derives.

---

## The Formula in Practice

Let's trace a complete example:

```jsx
function TodoApp() {
  // State: the minimal data we need
  const [todos, setTodos] = useState([]);
  const [filter, setFilter] = useState('all');

  // Derived: computed from state, not stored
  const filteredTodos = todos.filter(todo => {
    if (filter === 'active') return !todo.done;
    if (filter === 'done') return todo.done;
    return true;
  });

  const remainingCount = todos.filter(t => !t.done).length;

  // UI: pure function of state and derived values
  return (
    <div>
      <h1>Todos ({remainingCount} remaining)</h1>

      <FilterButtons
        current={filter}
        onChange={setFilter}
      />

      <TodoList
        todos={filteredTodos}
        onToggle={id => setTodos(todos.map(t =>
          t.id === id ? { ...t, done: !t.done } : t
        ))}
      />

      <AddTodo
        onAdd={text => setTodos([
          ...todos,
          { id: Date.now(), text, done: false }
        ])}
      />
    </div>
  );
}
```

Notice:
- **State is minimal:** Just `todos` and `filter`
- **Everything else is derived:** `filteredTodos`, `remainingCount`
- **UI is a function:** Given any `todos` and `filter`, the UI is deterministic
- **Updates go through state:** `setTodos` and `setFilter`, never direct DOM manipulation

---

## Key Takeaways

1. **UI = f(state)** is React's fundamental equation
2. **UI is derived from state**, not independently managed
3. **Same state always produces same UI** (referential transparency)
4. **State is the single source of truth** — DOM is just a reflection
5. **Don't store what you can compute** — derive during render
6. **Don't read from or write to DOM directly** — it breaks the model

This mental model is your North Star. When confused, return to it: "What's the state? What UI should that state produce?"

---

*Next: [Chapter 6: Why State Exists](../PART-2-STATE-AND-RENDERING/06-why-state-exists.md)*
