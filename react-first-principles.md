# React from First Principles
## A Mental Model Approach to Learning React

---

# Preface

This book takes a different approach to teaching React. Instead of jumping straight into syntax and APIs, we'll first understand *why* React exists, *what problems* it solves, and *how* its design decisions flow naturally from those problems.

By the end, you won't just know React—you'll understand it.

---

# Part I: The Problem

## Chapter 1: Why Do We Need React?

### The Fundamental Challenge of User Interfaces

Before we write a single line of React code, let's understand the problem it solves.

A user interface has one job: **keep the screen in sync with the data**.

When your data says "user has 3 unread messages," the screen should show "3". When that changes to 5, the screen should update to "5". Simple, right?

Let's see what this looks like without React:

```javascript
// Our data
let messageCount = 3;

// Initial render
document.getElementById('badge').textContent = messageCount;

// Later, data changes...
messageCount = 5;

// We must manually update the DOM
document.getElementById('badge').textContent = messageCount;
```

This seems manageable. But real applications have hundreds of pieces of data, and each piece might affect multiple parts of the screen. Consider an email app:

```javascript
let emails = [...];
let selectedEmail = null;
let searchQuery = '';
let isComposing = false;
let draftContent = '';
let userSettings = {...};

// When emails change, update:
// - The email list
// - The unread count badge
// - The folder counts
// - The preview pane (if selected email was deleted)

// When selectedEmail changes, update:
// - The highlight in the list
// - The preview pane content
// - The "mark as read" button state
// - The URL

// When searchQuery changes, update:
// - The filtered list
// - The "no results" message visibility
// - The clear button visibility
```

### The Synchronization Problem

This is **the synchronization problem**: keeping the UI in sync with data is exponentially complex as your application grows.

Manual DOM manipulation leads to:

1. **Scattered update logic** - Code to update the DOM is spread everywhere
2. **Missed updates** - Forget to update one place and you have a bug
3. **Inconsistent states** - The UI shows conflicting information
4. **Spaghetti code** - Everything depends on everything else

### The React Solution: Declarative UI

React's insight was revolutionary: **what if we stopped trying to sync the UI with data?**

Instead of writing code that *changes* the UI, we write code that *describes* what the UI should look like for any given data. Then React figures out how to make the DOM match that description.

```javascript
// Instead of: "when X changes, update Y and Z"
// We write: "given this data, the UI looks like this"

function EmailBadge({ count }) {
  return <span className="badge">{count}</span>;
}
```

This is the **declarative** approach. We declare the end state; React handles the transitions.

Think of it like a spreadsheet. You don't write "when A1 changes, update B1". You write `=A1*2` in B1, and the spreadsheet keeps it in sync automatically.

---

## Chapter 2: The Cost of the Old Way

Let's build a simple counter both ways to feel the difference.

### The Imperative Way (Vanilla JavaScript)

```javascript
// HTML: <div id="app"></div>

// Setup
const app = document.getElementById('app');
const button = document.createElement('button');
const display = document.createElement('span');

display.textContent = '0';
button.textContent = 'Increment';

app.appendChild(display);
app.appendChild(button);

// State
let count = 0;

// Behavior
button.addEventListener('click', () => {
  count += 1;
  display.textContent = count; // Manual sync!
});
```

This works, but notice:
- We had to manually create DOM elements
- We had to manually wire up the event listener
- We had to manually update the display when state changed
- The "what it looks like" is tangled with "how to build it"

### The Declarative Way (React)

```javascript
function Counter() {
  const [count, setCount] = useState(0);

  return (
    <div>
      <span>{count}</span>
      <button onClick={() => setCount(count + 1)}>
        Increment
      </button>
    </div>
  );
}
```

Notice:
- We describe what the UI looks like for any value of `count`
- React handles creating and updating DOM elements
- When `count` changes, React automatically re-renders
- The code reads like a description of the UI

### Why This Matters

The imperative approach has **linear complexity for simple UIs, but exponential complexity for complex ones**. The declarative approach has **consistent complexity regardless of UI complexity**.

---

# Part II: The Mental Model

## Chapter 3: Thinking in Components

### What is a Component?

A component is a **function that returns UI**.

That's it. No magic. A function that takes some input and returns a description of what should appear on screen.

```javascript
function Greeting(props) {
  return <h1>Hello, {props.name}</h1>;
}
```

### Why Functions?

Functions are the most fundamental building block in programming. They:
- Take input (arguments)
- Produce output (return value)
- Are composable (functions can call other functions)
- Are reusable (call the same function with different arguments)

Components inherit all these properties:

```javascript
// Composable - components use other components
function WelcomePage() {
  return (
    <div>
      <Greeting name="Alice" />
      <Greeting name="Bob" />
    </div>
  );
}

// Reusable - same component, different data
<UserCard user={alice} />
<UserCard user={bob} />
<UserCard user={charlie} />
```

### The Component Tree

Your entire application is a tree of components, with each parent component containing child components:

```
App
├── Header
│   ├── Logo
│   └── Navigation
│       ├── NavItem
│       ├── NavItem
│       └── NavItem
├── Main
│   ├── Sidebar
│   └── Content
└── Footer
```

This mirrors how we naturally think about UI: a page *contains* a header and main content; the header *contains* a logo and navigation.

### The Key Insight

**UI is a function of state.**

```
UI = f(state)
```

Given the same state, a component always produces the same UI. This is called being **"pure"** and it's what makes React predictable.

```javascript
// Given the same `user`, this always returns the same UI
function UserProfile({ user }) {
  return (
    <div>
      <img src={user.avatar} />
      <h2>{user.name}</h2>
      <p>{user.bio}</p>
    </div>
  );
}
```

---

## Chapter 4: Why JSX?

### The Strange Syntax

When you first see JSX, it looks wrong:

```javascript
function Button() {
  return <button className="primary">Click me</button>;
}
```

HTML inside JavaScript? This violates everything we learned about separation of concerns!

### Rethinking Separation of Concerns

Traditional web development separated by **technology**: HTML in one file, CSS in another, JavaScript in a third. But this isn't really separation of concerns—it's separation of technologies.

True separation of concerns means separating by **functionality**. A button component has:
- Structure (what elements exist)
- Style (how it looks)
- Behavior (what it does)

These aren't separate concerns—they're all part of "what is a button?" Splitting them across files creates artificial boundaries.

### What JSX Actually Is

JSX is not HTML. It's syntactic sugar for function calls:

```javascript
// This JSX:
<button className="primary">Click me</button>

// Becomes this JavaScript:
React.createElement('button', { className: 'primary' }, 'Click me')
```

JSX is just a more readable way to write `React.createElement` calls. You could write React without JSX:

```javascript
function Button() {
  return React.createElement(
    'button',
    { className: 'primary' },
    'Click me'
  );
}
```

But JSX is easier to read because it mirrors the structure of the output.

### JSX is JavaScript

Because JSX compiles to JavaScript, you can use JavaScript expressions inside it:

```javascript
function Greeting({ user, messageCount }) {
  return (
    <div>
      <h1>Hello, {user.name.toUpperCase()}</h1>
      {messageCount > 0 && (
        <p>You have {messageCount} new messages</p>
      )}
      <ul>
        {user.hobbies.map(hobby => (
          <li key={hobby}>{hobby}</li>
        ))}
      </ul>
    </div>
  );
}
```

The curly braces `{}` create a window back into JavaScript. Anything that evaluates to a value can go inside.

---

## Chapter 5: Why State?

### The Need for Memory

Components need to remember things. A counter needs to remember its count. A form needs to remember what the user typed. A toggle needs to remember if it's on or off.

### What is State?

State is **data that changes over time and affects what the UI shows**.

Not all data is state:
- A component's props aren't state (they come from outside)
- A calculated value isn't state (it's derived from other data)
- A constant isn't state (it doesn't change)

State is specifically data that:
1. Changes over time
2. Is "owned" by the component
3. Triggers a re-render when it changes

### The useState Hook

```javascript
function Counter() {
  const [count, setCount] = useState(0);
  //     ^^^^^  ^^^^^^^^           ^
  //     |      |                  |
  //     |      |                  Initial value
  //     |      Function to update it
  //     Current value

  return (
    <div>
      <p>Count: {count}</p>
      <button onClick={() => setCount(count + 1)}>
        Add
      </button>
    </div>
  );
}
```

### Why Not Just Use Variables?

You might wonder why we can't just use a regular variable:

```javascript
function Counter() {
  let count = 0; // This won't work!

  return (
    <button onClick={() => { count += 1 }}>
      Count: {count}
    </button>
  );
}
```

This fails for two reasons:

1. **No re-render trigger**: Changing `count` doesn't tell React to update the UI
2. **Lost on re-render**: Each time the component renders, `count` is reset to 0

`useState` solves both problems:
- Calling `setCount` tells React "this changed, please re-render"
- React remembers the state value between renders

### The Re-render Cycle

Understanding this cycle is crucial:

1. Component renders with initial state (`count = 0`)
2. User clicks button
3. `setCount(1)` is called
4. React schedules a re-render
5. Component function runs again
6. `useState(0)` returns `1` (the updated value, not the initial value)
7. New UI is calculated
8. React updates the DOM to match

The component function runs every time state changes. React remembers the state; you describe the UI.

---

## Chapter 6: Why Props?

### Components Need to Communicate

A component tree isn't useful if components can't share information. A `UserList` needs to tell each `UserCard` which user to display.

### What Are Props?

Props are **arguments to a component function**.

```javascript
// Regular function with arguments
function greet(name, isExcited) {
  return isExcited ? `HELLO ${name}!!!` : `Hello, ${name}`;
}

// Component function with props (same concept!)
function Greeting({ name, isExcited }) {
  return isExcited
    ? <h1>HELLO {name}!!!</h1>
    : <h1>Hello, {name}</h1>;
}

// Using it
<Greeting name="Alice" isExcited={true} />
```

### Props Flow Down

Data flows **one direction** in React: from parent to child, through props.

```javascript
function App() {
  const user = { name: 'Alice', avatar: '...' };

  return (
    <div>
      <Header user={user} />
      <Profile user={user} />
    </div>
  );
}

function Header({ user }) {
  return <span>Welcome, {user.name}</span>;
}

function Profile({ user }) {
  return <img src={user.avatar} alt={user.name} />;
}
```

This is called **"unidirectional data flow"**. It makes your app predictable: you always know where data comes from.

### Props vs State

| Props | State |
|-------|-------|
| Passed from parent | Created in component |
| Read-only | Can be updated |
| Like function arguments | Like local variables |
| Change triggers re-render | Change triggers re-render |

A helpful way to think about it:
- **Props** are how a parent configures a child
- **State** is how a component tracks information internally

### Lifting State Up

What if two sibling components need to share state? You **lift the state up** to their common parent:

```javascript
function App() {
  // State lives in the parent
  const [selected, setSelected] = useState(null);

  return (
    <div>
      <List
        items={items}
        selected={selected}
        onSelect={setSelected}
      />
      <Details item={selected} />
    </div>
  );
}
```

The parent owns the state and passes it down. Children communicate changes through callback functions passed as props.

---

# Part III: Making Things Happen

## Chapter 7: Why Hooks?

### The Problem Before Hooks

Early React had two ways to write components:
- **Function components**: Simple, but couldn't have state
- **Class components**: Could have state, but complex syntax

```javascript
// Class component (the old way)
class Counter extends React.Component {
  constructor(props) {
    super(props);
    this.state = { count: 0 };
  }

  render() {
    return (
      <button onClick={() => this.setState({ count: this.state.count + 1 })}>
        Count: {this.state.count}
      </button>
    );
  }
}
```

Classes brought problems:
- `this` binding confusion
- Lifecycle methods split related logic
- Hard to share stateful logic between components

### What Hooks Enable

Hooks let function components "hook into" React features:

```javascript
function Counter() {
  const [count, setCount] = useState(0);

  return (
    <button onClick={() => setCount(count + 1)}>
      Count: {count}
    </button>
  );
}
```

Same result, much simpler.

### The Rules of Hooks

Hooks have two rules, and both exist for good reasons:

**1. Only call hooks at the top level**

```javascript
// BAD - in a condition
function Component() {
  if (someCondition) {
    const [count, setCount] = useState(0); // Don't do this!
  }
}

// GOOD - at the top level
function Component() {
  const [count, setCount] = useState(0);
  if (someCondition) {
    // use count here
  }
}
```

**Why?** React identifies hooks by their order. If you call hooks conditionally, the order changes between renders, and React gets confused about which state belongs to which `useState` call.

**2. Only call hooks from React functions**

```javascript
// BAD - in a regular function
function notAComponent() {
  const [count, setCount] = useState(0); // Don't do this!
}

// GOOD - in a component or custom hook
function MyComponent() {
  const [count, setCount] = useState(0); // Fine!
}
```

**Why?** Hooks need React's internal bookkeeping to work. Regular functions don't have access to that.

### Common Hooks

**useState** - Remember a value

```javascript
const [value, setValue] = useState(initialValue);
```

**useEffect** - Do something after render

```javascript
useEffect(() => {
  // Runs after component renders
  document.title = `Count: ${count}`;
}, [count]); // Only re-run if count changes
```

**useRef** - Reference a value without triggering re-render

```javascript
const inputRef = useRef(null);
// Later: inputRef.current.focus()
```

**useContext** - Access shared data without passing props

```javascript
const theme = useContext(ThemeContext);
```

---

## Chapter 8: Why useEffect?

### Side Effects

Most of what a component does is pure: given props and state, return UI. But sometimes you need to do things *outside* this flow:

- Fetch data from an API
- Update the document title
- Set up a subscription
- Measure DOM elements
- Write to local storage

These are **side effects**—things that affect the world outside the component.

### The Problem with Side Effects

Where do side effects go? Not in the render:

```javascript
function Profile({ userId }) {
  // BAD - This runs on every render!
  fetch(`/api/users/${userId}`)
    .then(res => res.json())
    .then(user => setUser(user));

  return <div>{user?.name}</div>;
}
```

This creates an infinite loop: fetch sets state, state change triggers re-render, re-render triggers fetch, fetch sets state...

### useEffect to the Rescue

`useEffect` lets you run side effects **after** render, with control over **when** they run:

```javascript
function Profile({ userId }) {
  const [user, setUser] = useState(null);

  useEffect(() => {
    // This runs after render
    fetch(`/api/users/${userId}`)
      .then(res => res.json())
      .then(user => setUser(user));
  }, [userId]); // Only re-run if userId changes

  return <div>{user?.name}</div>;
}
```

### The Dependency Array

The second argument to `useEffect` controls when the effect runs:

```javascript
// No dependency array - runs after EVERY render
useEffect(() => {
  console.log('Rendered!');
});

// Empty array - runs ONCE after first render
useEffect(() => {
  console.log('Mounted!');
}, []);

// With dependencies - runs when dependencies change
useEffect(() => {
  console.log(`userId changed to ${userId}`);
}, [userId]);
```

### Cleanup

Some effects need cleanup. Subscriptions need to be cancelled, timers need to be cleared:

```javascript
useEffect(() => {
  const subscription = dataSource.subscribe(handleChange);

  // Return a cleanup function
  return () => {
    subscription.unsubscribe();
  };
}, [dataSource]);
```

The cleanup function runs:
- Before the effect runs again (if dependencies changed)
- When the component unmounts

### Mental Model: Synchronization

Think of `useEffect` as **synchronizing your component with something external**:

```javascript
// Sync document title with count
useEffect(() => {
  document.title = `Count: ${count}`;
}, [count]);

// Sync with browser event
useEffect(() => {
  window.addEventListener('resize', handleResize);
  return () => window.removeEventListener('resize', handleResize);
}, []);

// Sync with server data
useEffect(() => {
  fetchUser(userId).then(setUser);
}, [userId]);
```

---

## Chapter 9: Why the Virtual DOM?

### The Performance Problem

Remember our core equation: `UI = f(state)`. Every time state changes, we calculate new UI.

The naive approach would be:
1. State changes
2. Re-calculate entire UI
3. Throw away the old DOM
4. Build entirely new DOM

But DOM operations are slow. Rebuilding everything on every change would be unusable.

### The Virtual DOM Solution

React's insight: **don't touch the real DOM more than necessary**.

The Virtual DOM is a lightweight JavaScript representation of the UI:

```javascript
// Virtual DOM (plain JavaScript objects)
{
  type: 'div',
  props: { className: 'container' },
  children: [
    { type: 'h1', props: {}, children: ['Hello'] },
    { type: 'p', props: {}, children: ['World'] }
  ]
}
```

### Reconciliation

When state changes:

1. React creates a new virtual DOM tree
2. React compares it to the previous virtual DOM tree
3. React calculates the minimal set of changes needed
4. React applies only those changes to the real DOM

```
Old Virtual DOM          New Virtual DOM
     div                      div
    /   \                    /   \
   h1    p       →          h1    p
   |     |                  |     |
"Hello" "World"          "Hello" "React"
                                   ↑
                            Only this changed!
```

React updates just the text node that changed, not the entire tree.

### Why This Matters

This is why React can use the declarative approach without sacrificing performance. You write code as if you're rebuilding everything on every change, but React is smart about what actually changes in the DOM.

### Keys Help React Track Changes

When rendering lists, React needs help identifying which items changed:

```javascript
// Without keys - React can't track individual items
{items.map(item => <li>{item.name}</li>)}

// With keys - React knows which item is which
{items.map(item => <li key={item.id}>{item.name}</li>)}
```

Keys should be:
- **Stable**: Don't change between renders
- **Unique**: Different for each sibling
- **Predictable**: Same for the same item

Using array indices as keys is often wrong because indices don't stay with items when the array changes.

---

# Part IV: Patterns and Practices

## Chapter 10: Composition Over Configuration

### The Power of Composition

React's component model naturally supports composition—building complex things from simple things:

```javascript
// Simple, focused components
function Avatar({ user, size }) {
  return <img src={user.avatar} width={size} height={size} />;
}

function UserInfo({ user }) {
  return (
    <div>
      <strong>{user.name}</strong>
      <span>{user.role}</span>
    </div>
  );
}

// Composed into something more complex
function UserCard({ user }) {
  return (
    <div className="card">
      <Avatar user={user} size={64} />
      <UserInfo user={user} />
    </div>
  );
}
```

### The Children Prop

Components can accept other components as children:

```javascript
function Card({ title, children }) {
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
  <Button>Click me</Button>
</Card>
```

This is incredibly powerful. `Card` doesn't need to know what its contents will be—it just provides structure.

### Slots Pattern

For more complex layouts, you can pass multiple component sections:

```javascript
function Layout({ header, sidebar, children }) {
  return (
    <div className="layout">
      <header>{header}</header>
      <aside>{sidebar}</aside>
      <main>{children}</main>
    </div>
  );
}

// Usage
<Layout
  header={<Navigation />}
  sidebar={<Menu />}
>
  <Article />
</Layout>
```

### Why Composition?

Composition lets you:
- Build complex UIs from simple pieces
- Reuse components in different contexts
- Avoid prop drilling (passing props through many levels)
- Keep components focused and testable

---

## Chapter 11: Derived State and Computation

### Don't Duplicate State

A common mistake is storing derived values in state:

```javascript
// BAD - duplicated/derived state
function FilteredList({ items }) {
  const [filter, setFilter] = useState('');
  const [filteredItems, setFilteredItems] = useState(items);

  const handleFilterChange = (newFilter) => {
    setFilter(newFilter);
    setFilteredItems(items.filter(i => i.name.includes(newFilter)));
  };

  // ... what if items prop changes? Bug!
}
```

### Calculate During Render

If you can calculate a value from existing state or props, do it during render:

```javascript
// GOOD - derived during render
function FilteredList({ items }) {
  const [filter, setFilter] = useState('');

  // Calculated fresh on every render
  const filteredItems = items.filter(i =>
    i.name.includes(filter)
  );

  return (/* ... */);
}
```

### useMemo for Expensive Calculations

If the calculation is expensive, use `useMemo` to cache it:

```javascript
function FilteredList({ items }) {
  const [filter, setFilter] = useState('');

  // Only recalculate when items or filter change
  const filteredItems = useMemo(() => {
    return items.filter(i => i.name.includes(filter));
  }, [items, filter]);

  return (/* ... */);
}
```

### The Single Source of Truth

Every piece of data should have one authoritative source:
- Props? Comes from parent
- State? Owned by this component
- Derived? Calculated from props or state

Never have two pieces of state that must be kept in sync—one should be derived from the other.

---

## Chapter 12: Managing Complex State

### When useState Isn't Enough

For complex state with multiple related values, `useState` can get messy:

```javascript
function Form() {
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [errors, setErrors] = useState({});
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isSubmitted, setIsSubmitted] = useState(false);

  // Lots of state to coordinate!
}
```

### useReducer for Complex State

`useReducer` centralizes state update logic:

```javascript
function formReducer(state, action) {
  switch (action.type) {
    case 'SET_FIELD':
      return { ...state, [action.field]: action.value };
    case 'SET_ERRORS':
      return { ...state, errors: action.errors };
    case 'SUBMIT_START':
      return { ...state, isSubmitting: true };
    case 'SUBMIT_SUCCESS':
      return { ...state, isSubmitting: false, isSubmitted: true };
    default:
      return state;
  }
}

function Form() {
  const [state, dispatch] = useReducer(formReducer, {
    name: '',
    email: '',
    errors: {},
    isSubmitting: false,
    isSubmitted: false,
  });

  const handleSubmit = () => {
    dispatch({ type: 'SUBMIT_START' });
    // ...
  };
}
```

### When to Use useReducer

Choose `useReducer` when:
- State has multiple related values
- Updates depend on previous state
- State transitions have complex logic
- You want to centralize and test state logic

Stick with `useState` when:
- State is a single value
- Updates are simple
- State changes are independent

---

## Chapter 13: Context - Avoiding Prop Drilling

### The Problem

Sometimes many components need the same data:

```javascript
function App() {
  const [theme, setTheme] = useState('light');

  return (
    <Layout theme={theme}>
      <Header theme={theme}>
        <Navigation theme={theme}>
          <Button theme={theme}>Click</Button>
        </Navigation>
      </Header>
    </Layout>
  );
}
```

Passing `theme` through every component is tedious and fragile.

### Context to the Rescue

Context provides a way to share values without explicit passing:

```javascript
// Create context
const ThemeContext = createContext('light');

// Provide value at the top
function App() {
  const [theme, setTheme] = useState('light');

  return (
    <ThemeContext.Provider value={theme}>
      <Layout>
        <Header>
          <Navigation>
            <Button>Click</Button>
          </Navigation>
        </Header>
      </Layout>
    </ThemeContext.Provider>
  );
}

// Consume anywhere below
function Button({ children }) {
  const theme = useContext(ThemeContext);
  return <button className={theme}>{children}</button>;
}
```

### When to Use Context

Good uses:
- Theme (light/dark mode)
- Current user
- Language/locale
- UI state (sidebar open/closed)

Bad uses:
- Frequently changing data (causes re-renders)
- Data only needed by a few nearby components
- As a replacement for proper state management

### Context + Reducer Pattern

For global state, combine context with reducer:

```javascript
const StateContext = createContext();
const DispatchContext = createContext();

function AppProvider({ children }) {
  const [state, dispatch] = useReducer(reducer, initialState);

  return (
    <StateContext.Provider value={state}>
      <DispatchContext.Provider value={dispatch}>
        {children}
      </DispatchContext.Provider>
    </StateContext.Provider>
  );
}

// Custom hooks for clean access
function useAppState() {
  return useContext(StateContext);
}

function useAppDispatch() {
  return useContext(DispatchContext);
}
```

---

# Part V: Building Real Applications

## Chapter 14: Data Fetching Patterns

### The Basic Pattern

```javascript
function UserProfile({ userId }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    setLoading(true);
    setError(null);

    fetch(`/api/users/${userId}`)
      .then(res => {
        if (!res.ok) throw new Error('Failed to fetch');
        return res.json();
      })
      .then(data => {
        setUser(data);
        setLoading(false);
      })
      .catch(err => {
        setError(err.message);
        setLoading(false);
      });
  }, [userId]);

  if (loading) return <Spinner />;
  if (error) return <Error message={error} />;
  return <Profile user={user} />;
}
```

### Extract to Custom Hook

This pattern repeats, so extract it:

```javascript
function useFetch(url) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    let cancelled = false;

    setLoading(true);
    fetch(url)
      .then(res => res.json())
      .then(data => {
        if (!cancelled) {
          setData(data);
          setLoading(false);
        }
      })
      .catch(err => {
        if (!cancelled) {
          setError(err.message);
          setLoading(false);
        }
      });

    return () => { cancelled = true; };
  }, [url]);

  return { data, loading, error };
}

// Usage
function UserProfile({ userId }) {
  const { data: user, loading, error } = useFetch(`/api/users/${userId}`);

  if (loading) return <Spinner />;
  if (error) return <Error message={error} />;
  return <Profile user={user} />;
}
```

### Race Conditions

Notice the `cancelled` flag. Without it:

1. User views profile A
2. Fetch A starts
3. User switches to profile B
4. Fetch B starts
5. Fetch A completes → shows user A
6. Fetch B completes → shows user B
7. Or: A completes after B → shows wrong user!

The cleanup function prevents stale responses from updating state.

### Libraries

For production apps, use established libraries like:
- **TanStack Query** (React Query)
- **SWR**
- **RTK Query**

They handle caching, deduplication, background updates, and much more.

---

## Chapter 15: Forms and Controlled Components

### Controlled vs Uncontrolled

In HTML, form elements maintain their own state. In React, we have a choice:

**Uncontrolled**: Let the DOM handle state

```javascript
function Form() {
  const inputRef = useRef();

  const handleSubmit = (e) => {
    e.preventDefault();
    console.log(inputRef.current.value);
  };

  return (
    <form onSubmit={handleSubmit}>
      <input ref={inputRef} />
      <button type="submit">Submit</button>
    </form>
  );
}
```

**Controlled**: React owns the state

```javascript
function Form() {
  const [value, setValue] = useState('');

  const handleSubmit = (e) => {
    e.preventDefault();
    console.log(value);
  };

  return (
    <form onSubmit={handleSubmit}>
      <input
        value={value}
        onChange={(e) => setValue(e.target.value)}
      />
      <button type="submit">Submit</button>
    </form>
  );
}
```

### Why Controlled Components?

With controlled components:
- You always know the current value (it's in state)
- You can transform input (e.g., force uppercase)
- You can validate on every keystroke
- You can disable submit until valid
- Multiple components can reference the same state

### Form Pattern

```javascript
function ContactForm() {
  const [form, setForm] = useState({
    name: '',
    email: '',
    message: ''
  });
  const [errors, setErrors] = useState({});

  const handleChange = (e) => {
    const { name, value } = e.target;
    setForm(prev => ({ ...prev, [name]: value }));
    // Clear error when user starts typing
    if (errors[name]) {
      setErrors(prev => ({ ...prev, [name]: null }));
    }
  };

  const validate = () => {
    const newErrors = {};
    if (!form.name) newErrors.name = 'Name is required';
    if (!form.email) newErrors.email = 'Email is required';
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    if (validate()) {
      // Submit form
    }
  };

  return (
    <form onSubmit={handleSubmit}>
      <input
        name="name"
        value={form.name}
        onChange={handleChange}
      />
      {errors.name && <span className="error">{errors.name}</span>}

      {/* ... more fields ... */}

      <button type="submit">Send</button>
    </form>
  );
}
```

---

## Chapter 16: Performance Thinking

### React is Fast by Default

Before optimizing, understand that:
- Virtual DOM diffing is efficient
- Most apps don't need optimization
- Premature optimization causes complexity

### When to Optimize

Optimize when you **measure** a problem. Use React DevTools Profiler to identify slow renders.

### Preventing Unnecessary Renders

**React.memo** - Skip re-render if props haven't changed:

```javascript
const ExpensiveComponent = React.memo(function ExpensiveComponent({ data }) {
  // Complex rendering
});
```

**useCallback** - Stable function references:

```javascript
function Parent() {
  // Without useCallback, handleClick is new every render
  const handleClick = useCallback(() => {
    console.log('Clicked');
  }, []);

  return <Child onClick={handleClick} />;
}
```

**useMemo** - Cache expensive calculations:

```javascript
function List({ items, filter }) {
  const filtered = useMemo(
    () => items.filter(complexFilter),
    [items, filter]
  );
}
```

### The Rules of Optimization

1. **Don't optimize prematurely**
2. **Measure first** - Use DevTools
3. **Optimize the slow parts** - Not everything
4. **Consider the tradeoffs** - Memoization has cost too

---

# Part VI: The Big Picture

## Chapter 17: React's Philosophy

### Declarative Over Imperative

React chose the declarative paradigm: describe what, not how. This choice flows through everything:

- JSX describes structure
- Components describe UI for given state
- Effects describe synchronization needs

### Composition Over Inheritance

React components compose, they don't inherit. You build complex UIs by combining simple components, not by extending base classes.

### Explicit Data Flow

Data flows explicitly through props. When you see a component, you know where its data comes from. No hidden dependencies, no action at a distance.

### Immutability

React assumes immutability. You don't modify state; you replace it:

```javascript
// Wrong - mutating
state.items.push(newItem);
setState(state);

// Right - replacing
setState({ ...state, items: [...state.items, newItem] });
```

This enables React's change detection and makes state changes predictable.

### Learn Once, Write Anywhere

React's core concepts (components, props, state) apply everywhere:
- React DOM for web
- React Native for mobile
- React Three Fiber for 3D
- Ink for CLI

Learn the mental model once; apply it anywhere.

---

## Chapter 18: Where to Go From Here

### Essential Next Steps

1. **Build something real** - The best way to learn is by doing. Build a todo app, then a blog, then something you actually need.

2. **Learn React Router** - Most apps need multiple pages. React Router is the standard solution.

3. **Learn a state management solution** - For larger apps, consider Zustand, Redux Toolkit, or Jotai.

4. **Learn a data fetching library** - TanStack Query or SWR will save you immense time.

5. **Learn TypeScript** - Type safety catches bugs before they happen and improves developer experience.

### The Learning Path

```
First Principles (this book)
         ↓
Build Simple Projects
         ↓
React Router + Data Fetching
         ↓
State Management
         ↓
Testing
         ↓
Advanced Patterns
         ↓
Performance Optimization
```

### Final Thoughts

React is a tool for building user interfaces. It's not magic—it's a set of well-designed abstractions that make UI development more predictable.

The core ideas fit in your head:
- **Components** are functions that return UI
- **Props** flow down from parent to child
- **State** triggers re-renders when it changes
- **Effects** handle synchronization with the outside world

Everything else builds on these foundations.

Now go build something.

---

# Appendix: Quick Reference

## Component Structure

```javascript
function ComponentName({ prop1, prop2 }) {
  // 1. Hooks
  const [state, setState] = useState(initialValue);
  const computed = useMemo(() => /* ... */, [deps]);

  useEffect(() => {
    // Side effects
    return () => { /* cleanup */ };
  }, [deps]);

  // 2. Event handlers
  const handleClick = () => {
    setState(newValue);
  };

  // 3. Render
  return (
    <div>
      {/* JSX */}
    </div>
  );
}
```

## Common Hooks

| Hook | Purpose |
|------|---------|
| `useState` | Component state |
| `useEffect` | Side effects |
| `useContext` | Access context |
| `useReducer` | Complex state logic |
| `useCallback` | Stable function reference |
| `useMemo` | Cached calculation |
| `useRef` | Mutable reference |

## JSX Rules

- Return a single root element (or use `<>...</>`)
- Close all tags (`<img />` not `<img>`)
- Use `className` not `class`
- Use `htmlFor` not `for`
- Use camelCase for event handlers (`onClick` not `onclick`)
- Use `{}` for JavaScript expressions

## Event Handling

```javascript
// Events
<button onClick={handleClick}>
<input onChange={handleChange}>
<form onSubmit={handleSubmit}>

// With parameters
<button onClick={() => handleDelete(id)}>

// Prevent default
const handleSubmit = (e) => {
  e.preventDefault();
  // ...
};
```

## Conditional Rendering

```javascript
// If/else
{condition ? <A /> : <B />}

// Only if true
{condition && <A />}

// Multiple conditions
{status === 'loading' && <Spinner />}
{status === 'error' && <Error />}
{status === 'success' && <Content />}
```

## List Rendering

```javascript
{items.map(item => (
  <Item key={item.id} data={item} />
))}
```

---

*End of React from First Principles*
