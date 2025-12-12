# Chapter 12: Props and One-Way Data Flow

> *"Complexity is the enemy of clarity."*
> — React's design philosophy

---

## The Flow of Data

In React, data flows in one direction: **down**.

```
      App (state)
       ↓ props
    Header
       ↓ props
   Navigation
       ↓ props
    NavItem
```

Parents pass data to children via props. Children never modify props. Children never push data up to parents directly.

This is called **unidirectional data flow**.

---

## Why One-Way?

### The Alternative: Two-Way Binding

Some frameworks allow two-way binding:

```html
<!-- Hypothetical two-way binding -->
<input value="{{username}}" />

<!-- Changes to input automatically update username -->
<!-- Changes to username automatically update input -->
```

Seems convenient, but consider:

```html
<input value="{{user.profile.name}}" />
<span>Welcome, {{user.profile.name}}</span>

<!-- User types in input -->
<!-- What happens? -->
<!-- - Input updates user.profile.name -->
<!-- - Span reflects new name -->
<!-- - But what if there's validation? -->
<!-- - What if the update should be async? -->
<!-- - What if multiple things depend on user? -->
```

Two-way binding creates invisible connections. Data changes anywhere, effects happen everywhere. Debugging becomes "why did this change?"

### One-Way Makes Causality Clear

```jsx
function Profile({ user, onUpdateName }) {
  return (
    <div>
      <input
        value={user.name}
        onChange={e => onUpdateName(e.target.value)}
      />
      <span>Welcome, {user.name}</span>
    </div>
  );
}
```

The data flow is explicit:
1. User types in input
2. `onChange` fires, calls `onUpdateName`
3. Parent updates state
4. Parent re-renders
5. Profile receives new `user` prop
6. Both input and span show new value

You can trace exactly why anything changed.

---

## Props Are Read-Only

This is a fundamental rule:

```jsx
function BadComponent(props) {
  props.name = 'New Name';  // NO! Never mutate props
  return <div>{props.name}</div>;
}
```

**Why?**

1. **Predictability:** If props could change randomly, you couldn't reason about your component.

2. **Parent ownership:** Props come from the parent. The parent "owns" that data. Modifying it would be reaching up and changing the parent's data.

3. **Immutability enables optimization:** React can check `oldProps === newProps` for quick "did anything change?" checks.

---

## The Props API

Props are the component's interface:

```jsx
// The component defines what it accepts
function Button({ label, onClick, disabled = false, variant = 'primary' }) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className={`btn btn-${variant}`}
    >
      {label}
    </button>
  );
}

// The parent provides values
<Button
  label="Submit"
  onClick={handleSubmit}
  disabled={isLoading}
  variant="secondary"
/>
```

### Destructuring Props

```jsx
// Option 1: Destructure in parameter
function Greeting({ name, age }) {
  return <p>{name} is {age} years old</p>;
}

// Option 2: Use props object
function Greeting(props) {
  return <p>{props.name} is {props.age} years old</p>;
}
```

Both work. Destructuring is more common—it's explicit about what the component uses.

### Default Values

```jsx
function Button({ variant = 'primary', size = 'medium' }) {
  // If variant isn't passed, it defaults to 'primary'
}
```

### The Children Prop

```jsx
function Card({ children, title }) {
  return (
    <div className="card">
      <h2>{title}</h2>
      <div className="card-body">
        {children}
      </div>
    </div>
  );
}

// Usage
<Card title="Welcome">
  <p>This is the card content.</p>
  <button>Click me</button>
</Card>
```

`children` is special—it represents whatever is between the opening and closing tags.

---

## Data Down, Actions Up

If children can't modify props, how do they communicate with parents?

**Pattern:** Children receive functions as props. They call those functions to signal events.

```jsx
function Parent() {
  const [items, setItems] = useState([]);

  const handleAddItem = (item) => {
    setItems([...items, item]);  // Parent updates state
  };

  return (
    <div>
      <ItemList items={items} />
      <AddItemForm onAdd={handleAddItem} />  {/* Pass function down */}
    </div>
  );
}

function AddItemForm({ onAdd }) {
  const [value, setValue] = useState('');

  const handleSubmit = (e) => {
    e.preventDefault();
    onAdd(value);  // Call parent's function
    setValue('');
  };

  return (
    <form onSubmit={handleSubmit}>
      <input value={value} onChange={e => setValue(e.target.value)} />
      <button type="submit">Add</button>
    </form>
  );
}
```

The data flows down (`items`). Actions flow up (`onAdd`).

---

## The Benefits

### Benefit 1: Predictable Updates

State lives in one place. Updates happen in one place. The UI is a pure function of that state.

```jsx
// All the state lives here
function App() {
  const [user, setUser] = useState(null);
  const [posts, setPosts] = useState([]);
  const [theme, setTheme] = useState('light');

  // UI is derived from this state
  return (
    <div className={theme}>
      <UserProfile user={user} onUpdate={setUser} />
      <PostList posts={posts} />
      <ThemeToggle theme={theme} onToggle={setTheme} />
    </div>
  );
}
```

Question: "Why did the user profile change?"
Answer: Because `setUser` was called somewhere.

You always know where to look.

### Benefit 2: Easier Debugging

With one-way flow, you can trace any change:

```
User clicked button
  → onClick handler fired
  → setCount was called
  → App re-rendered
  → Counter received new count prop
  → Counter displayed new number
```

Each step follows from the previous. No mysterious updates.

### Benefit 3: Reusable Components

Components that don't assume where their data comes from are reusable:

```jsx
function Button({ label, onClick }) {
  return <button onClick={onClick}>{label}</button>;
}

// Can be used anywhere
<Button label="Save" onClick={save} />
<Button label="Cancel" onClick={cancel} />
<Button label="Delete" onClick={delete} />
```

The Button doesn't know about the app's state. It just knows about `label` and `onClick`.

---

## When This Feels Cumbersome

One-way flow can feel verbose:

```jsx
// State at App level
// Need to pass props through multiple levels
<App>
  <Layout>
    <Header>
      <UserMenu user={user} />  {/* user passed through 3 levels! */}
    </Header>
  </Layout>
</App>
```

This is called "prop drilling." React provides solutions:
- **Context:** Share values without passing through every level
- **State libraries:** Redux, Zustand, etc.
- **Composition:** Restructure components to reduce depth

We'll discuss lifting state and composition patterns in the next chapters.

---

## Key Takeaways

1. **Data flows down** — Parents pass props to children
2. **Props are read-only** — Never mutate props
3. **Actions flow up** — Children call callback functions to signal events
4. **One-way flow enables clarity** — You can trace any change
5. **Children prop** is for nested content
6. **Prop drilling** can be solved with context or composition

Understanding unidirectional data flow is essential. It's not just a React thing—it's a design philosophy that makes complex UIs manageable.

---

*Next: [Chapter 13: Lifting State Up](./13-lifting-state-up.md)*
