# Chapter 14: The Composition Pattern

> *"Composition over inheritance."*
> — Software design principle

---

## What Is Composition?

Composition means building complex things from simpler things.

In React, this means: **Build complex components from simpler components.**

```jsx
// Simple components
function Avatar({ src, alt }) {
  return <img className="avatar" src={src} alt={alt} />;
}

function Name({ children }) {
  return <span className="name">{children}</span>;
}

function Bio({ children }) {
  return <p className="bio">{children}</p>;
}

// Composed into something more complex
function UserCard({ user }) {
  return (
    <div className="user-card">
      <Avatar src={user.avatar} alt={user.name} />
      <Name>{user.name}</Name>
      <Bio>{user.bio}</Bio>
    </div>
  );
}
```

Each piece is simple. Together, they create something useful.

---

## Why Composition?

### The Alternative: Inheritance

In object-oriented programming, you might extend a base class:

```jsx
// NOT how React works
class Button extends BaseButton {
  render() {
    return <button className="primary">{this.props.label}</button>;
  }
}

class DangerButton extends Button {
  render() {
    // Override parent's render
    return <button className="danger">{this.props.label}</button>;
  }
}
```

**Problems:**
- Deep hierarchies become hard to understand
- Changes to base class affect all descendants
- You can only inherit from one class
- State and behavior get tangled

### Composition Is More Flexible

```jsx
function Button({ variant = 'primary', children, ...props }) {
  return (
    <button className={`btn btn-${variant}`} {...props}>
      {children}
    </button>
  );
}

// Use it directly with different variants
<Button variant="primary">Save</Button>
<Button variant="danger">Delete</Button>
<Button variant="secondary" disabled>Cancel</Button>
```

No class hierarchy. Just configure the component for your use case.

---

## Containment: The Children Pattern

The most fundamental composition pattern: components can contain other components.

```jsx
function Card({ children }) {
  return <div className="card">{children}</div>;
}

function App() {
  return (
    <Card>
      <h1>Title</h1>
      <p>Content goes here</p>
      <button>Action</button>
    </Card>
  );
}
```

**Why this is powerful:**

```jsx
// Card doesn't know or care what's inside
// It provides structure, children provide content

<Card>
  <UserProfile user={user} />
</Card>

<Card>
  <ShoppingCart items={items} />
</Card>

<Card>
  <LoginForm onSubmit={handleLogin} />
</Card>
```

The Card component is reusable because it's *generic*.

---

## Named Slots

Sometimes you need multiple "holes" in your component:

```jsx
function Layout({ header, sidebar, children }) {
  return (
    <div className="layout">
      <header>{header}</header>
      <aside>{sidebar}</aside>
      <main>{children}</main>
    </div>
  );
}

function App() {
  return (
    <Layout
      header={<Navigation />}
      sidebar={<Menu items={menuItems} />}
    >
      <ArticleList articles={articles} />
    </Layout>
  );
}
```

Now `Layout` has three slots: `header`, `sidebar`, and `children`. The parent decides what goes in each.

---

## Specialization

Create specialized versions of generic components:

```jsx
// Generic
function Dialog({ title, message, children }) {
  return (
    <div className="dialog">
      <h1>{title}</h1>
      <p>{message}</p>
      {children}
    </div>
  );
}

// Specialized
function WelcomeDialog() {
  return (
    <Dialog
      title="Welcome!"
      message="Thank you for visiting our spacecraft."
    />
  );
}

function AlertDialog({ message, onClose }) {
  return (
    <Dialog title="Alert" message={message}>
      <button onClick={onClose}>OK</button>
    </Dialog>
  );
}

function ConfirmDialog({ message, onConfirm, onCancel }) {
  return (
    <Dialog title="Confirm" message={message}>
      <button onClick={onCancel}>Cancel</button>
      <button onClick={onConfirm}>OK</button>
    </Dialog>
  );
}
```

`WelcomeDialog`, `AlertDialog`, and `ConfirmDialog` are specialized versions of `Dialog`. No inheritance needed.

---

## Render Props

Components can accept functions as children:

```jsx
function MouseTracker({ children }) {
  const [position, setPosition] = useState({ x: 0, y: 0 });

  useEffect(() => {
    const handleMouseMove = (e) => {
      setPosition({ x: e.clientX, y: e.clientY });
    };
    window.addEventListener('mousemove', handleMouseMove);
    return () => window.removeEventListener('mousemove', handleMouseMove);
  }, []);

  // Call children as a function, passing data
  return children(position);
}

// Usage
function App() {
  return (
    <MouseTracker>
      {(position) => (
        <div>
          Mouse is at ({position.x}, {position.y})
        </div>
      )}
    </MouseTracker>
  );
}
```

The parent controls what to render; the child provides data. This is called a "render prop."

---

## Compound Components

Components that work together as a unit:

```jsx
function Tabs({ children, defaultTab }) {
  const [activeTab, setActiveTab] = useState(defaultTab);

  return (
    <TabContext.Provider value={{ activeTab, setActiveTab }}>
      {children}
    </TabContext.Provider>
  );
}

function TabList({ children }) {
  return <div className="tab-list">{children}</div>;
}

function Tab({ id, children }) {
  const { activeTab, setActiveTab } = useContext(TabContext);
  return (
    <button
      className={activeTab === id ? 'active' : ''}
      onClick={() => setActiveTab(id)}
    >
      {children}
    </button>
  );
}

function TabPanel({ id, children }) {
  const { activeTab } = useContext(TabContext);
  return activeTab === id ? <div>{children}</div> : null;
}

// Usage — feels natural, like HTML
<Tabs defaultTab="tab1">
  <TabList>
    <Tab id="tab1">First</Tab>
    <Tab id="tab2">Second</Tab>
  </TabList>
  <TabPanel id="tab1">First content</TabPanel>
  <TabPanel id="tab2">Second content</TabPanel>
</Tabs>
```

The components (`Tabs`, `Tab`, `TabPanel`) share state implicitly via context. The API is clean.

---

## Solving Prop Drilling with Composition

Remember the prop drilling problem?

```jsx
// Without composition — props passed through every level
<App user={user}>
  <Layout user={user}>
    <Header user={user}>
      <UserMenu user={user} />
    </Header>
  </Layout>
</App>
```

**With composition:**

```jsx
function App({ user }) {
  // Build the pieces at the top
  const userMenu = <UserMenu user={user} />;
  const header = <Header>{userMenu}</Header>;
  const layout = <Layout header={header}>{/* main content */}</Layout>;

  return layout;
}

function Layout({ header, children }) {
  return (
    <div>
      {header}
      <main>{children}</main>
    </div>
  );
}

function Header({ children }) {
  return <header>{children}</header>;
}
```

Now `Layout` and `Header` don't need to know about `user`. They just render whatever they're given.

---

## When to Use What

**Use `children` when:**
- Component is a container/wrapper
- You want maximum flexibility in what goes inside

**Use named props when:**
- You have multiple distinct slots
- The component has a specific structure

**Use render props when:**
- The child needs data from the wrapper
- You want to invert control

**Use compound components when:**
- You're building a "family" of related components
- The parts share implicit state

---

## The Philosophy

Composition is about:

1. **Separation of concerns** — Each component does one thing
2. **Reusability** — Generic components work in many contexts
3. **Flexibility** — Parents control children's content
4. **Clarity** — Structure is visible in JSX

Favor composition over:
- Inheritance (extending components)
- Configuration (endless prop options)
- Context-for-everything (hidden dependencies)

---

## Key Takeaways

1. **Composition = building complex from simple**
2. **Children prop** allows containment
3. **Named slots** provide multiple insertion points
4. **Specialization** creates specific versions of generic components
5. **Render props** let children provide data to parents' render logic
6. **Compound components** work as a cohesive unit
7. **Composition solves prop drilling** by letting you build UI pieces at the top level

Composition is React's answer to the flexibility problem. Master it, and your components become building blocks that can be assembled in ways you never anticipated.

---

*Next: [Chapter 15: Pure Functions and Side Effects](../PART-5-SIDE-EFFECTS/15-pure-functions-side-effects.md)*
