# Chapter 13: Lifting State Up

> *"State should live at the lowest common ancestor of the components that need it."*
> — React documentation

---

## The Problem

You have two components that need to share state. Where does the state live?

```jsx
// Two temperature inputs that should stay in sync
function BoilingVerdict({ celsius }) {
  if (celsius >= 100) {
    return <p>The water would boil.</p>;
  }
  return <p>The water would not boil.</p>;
}

function CelsiusInput() {
  const [temperature, setTemperature] = useState('');
  return (
    <input
      value={temperature}
      onChange={e => setTemperature(e.target.value)}
    />
  );
}

function FahrenheitInput() {
  const [temperature, setTemperature] = useState('');
  return (
    <input
      value={temperature}
      onChange={e => setTemperature(e.target.value)}
    />
  );
}
```

Problem: Each input has its own state. They can't stay in sync.

---

## The Solution: Lift State Up

Move the shared state to the closest common ancestor:

```jsx
function Calculator() {
  // State lives in the common parent
  const [temperature, setTemperature] = useState('');
  const [scale, setScale] = useState('c');

  // Conversion functions
  const toCelsius = f => (f - 32) * 5 / 9;
  const toFahrenheit = c => c * 9 / 5 + 32;

  // Derive both values from the single source
  const celsius = scale === 'f' ? toCelsius(parseFloat(temperature)) : temperature;
  const fahrenheit = scale === 'c' ? toFahrenheit(parseFloat(temperature)) : temperature;

  return (
    <div>
      <TemperatureInput
        scale="c"
        temperature={celsius}
        onTemperatureChange={(temp) => {
          setTemperature(temp);
          setScale('c');
        }}
      />
      <TemperatureInput
        scale="f"
        temperature={fahrenheit}
        onTemperatureChange={(temp) => {
          setTemperature(temp);
          setScale('f');
        }}
      />
      <BoilingVerdict celsius={parseFloat(celsius)} />
    </div>
  );
}

function TemperatureInput({ scale, temperature, onTemperatureChange }) {
  return (
    <fieldset>
      <legend>Enter temperature in {scale === 'c' ? 'Celsius' : 'Fahrenheit'}:</legend>
      <input
        value={temperature}
        onChange={e => onTemperatureChange(e.target.value)}
      />
    </fieldset>
  );
}
```

Now there's **one source of truth**. Both inputs display derived values from that source.

---

## The Pattern

```
BEFORE: State in siblings (can't sync)

ComponentA          ComponentB
  [state]             [state]
     ↓                   ↓
   render              render


AFTER: State lifted to parent (synced automatically)

        Parent
         [state]
        ↙     ↘
      ↓         ↓
ComponentA   ComponentB
(props)      (props)
   ↓            ↓
 render       render
```

**Steps:**
1. Identify which components need the same state
2. Find their closest common ancestor
3. Move the state there
4. Pass data down as props
5. Pass update functions down as callbacks

---

## When to Lift State

**Lift when:**
- Two or more components need the same state
- You need to coordinate between components
- The state affects other parts of the tree

**Don't lift when:**
- Only one component uses the state
- State is truly local (hover, focus, input before submit)

---

## A Complete Example

Let's build a shopping cart with multiple components:

```jsx
function ShoppingApp() {
  // All shared state lives here
  const [cart, setCart] = useState([]);

  const addToCart = (product) => {
    setCart([...cart, product]);
  };

  const removeFromCart = (productId) => {
    setCart(cart.filter(item => item.id !== productId));
  };

  const total = cart.reduce((sum, item) => sum + item.price, 0);

  return (
    <div>
      <Header cartCount={cart.length} />
      <ProductList onAddToCart={addToCart} />
      <Cart
        items={cart}
        total={total}
        onRemove={removeFromCart}
      />
    </div>
  );
}

// Child components are "dumb" — they just receive props
function Header({ cartCount }) {
  return (
    <header>
      <h1>Shop</h1>
      <span>Cart: {cartCount} items</span>
    </header>
  );
}

function ProductList({ onAddToCart }) {
  const products = [
    { id: 1, name: 'Widget', price: 25 },
    { id: 2, name: 'Gadget', price: 50 },
  ];

  return (
    <ul>
      {products.map(product => (
        <li key={product.id}>
          {product.name} - ${product.price}
          <button onClick={() => onAddToCart(product)}>
            Add to Cart
          </button>
        </li>
      ))}
    </ul>
  );
}

function Cart({ items, total, onRemove }) {
  return (
    <div>
      <h2>Cart</h2>
      {items.map(item => (
        <div key={item.id}>
          {item.name}
          <button onClick={() => onRemove(item.id)}>Remove</button>
        </div>
      ))}
      <p>Total: ${total}</p>
    </div>
  );
}
```

**Notice:**
- `cart` state lives in `ShoppingApp`
- `Header`, `ProductList`, and `Cart` don't have their own cart state
- All cart-related actions flow through `ShoppingApp`
- The UI is always consistent

---

## The Trade-offs

### Pros
- Single source of truth
- Easier to debug (one place to look)
- Components stay in sync automatically
- Clear data flow

### Cons
- More props to pass
- Parent becomes larger
- Re-renders propagate (can optimize with memo)
- Deep trees = deep prop drilling

---

## Prop Drilling

The classic problem:

```jsx
function App() {
  const [user, setUser] = useState(currentUser);

  return (
    <Layout user={user}>
      <Header user={user}>
        <Navigation user={user}>
          <UserMenu user={user} />  {/* user passed 4 levels! */}
        </Navigation>
      </Header>
    </Layout>
  );
}
```

**Solutions:**

### 1. Component Composition

```jsx
function App() {
  const [user, setUser] = useState(currentUser);

  // Build the tree from the top, passing components as children
  return (
    <Layout>
      <Header>
        <Navigation>
          <UserMenu user={user} />  {/* Created at App level */}
        </Navigation>
      </Header>
    </Layout>
  );
}

function Layout({ children }) {
  return <div className="layout">{children}</div>;
}

function Header({ children }) {
  return <header>{children}</header>;
}
```

Now Layout and Header don't need to know about `user` at all.

### 2. Context (For Truly Global State)

```jsx
const UserContext = React.createContext(null);

function App() {
  const [user, setUser] = useState(currentUser);

  return (
    <UserContext.Provider value={user}>
      <Layout>
        <Header>
          <Navigation>
            <UserMenu />  {/* Gets user from context */}
          </Navigation>
        </Header>
      </Layout>
    </UserContext.Provider>
  );
}

function UserMenu() {
  const user = useContext(UserContext);  // No props needed!
  return <div>{user.name}</div>;
}
```

Context is powerful but use it sparingly—it can make component relationships less clear.

---

## The Decision Framework

When deciding where state should live:

1. **Who needs this state?** List all components.

2. **What's their common ancestor?** The state goes there.

3. **Is it truly shared?** If only one component uses it, keep it there.

4. **Is it deeply nested?** Consider composition or context.

5. **Does it change often?** Frequently-changing state higher up means more re-renders.

---

## Key Takeaways

1. **Lift state to the lowest common ancestor** of components that need it
2. **Single source of truth** prevents sync bugs
3. **Dumb components** (receive props, call callbacks) are easier to understand
4. **Prop drilling** is real — solve with composition or context
5. **Don't over-lift** — local state should stay local

Lifting state is mechanical, but knowing *when* to lift and *how far* is an art. The goal is clarity: can you easily answer "where does this state live?"

---

*Next: [Chapter 14: The Composition Pattern](./14-composition-pattern.md)*
