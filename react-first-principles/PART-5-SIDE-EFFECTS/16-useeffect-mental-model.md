# Chapter 16: The useEffect Mental Model

> *"Effects let your component synchronize with external systems."*
> — React documentation

---

## The Wrong Mental Model

Many developers think of `useEffect` as lifecycle methods:

```jsx
// WRONG mental model
useEffect(() => {
  // componentDidMount + componentDidUpdate
  return () => {
    // componentWillUnmount
  };
}, [deps]);
```

This leads to bugs. Let's build the right mental model.

---

## The Right Mental Model: Synchronization

`useEffect` is for **synchronizing** your component with something external.

```jsx
useEffect(() => {
  // Synchronize document title with component state
  document.title = `You clicked ${count} times`;
}, [count]);
```

Think: "When `count` changes, sync the document title."

Not: "After the component renders, update the document title."

The difference is subtle but crucial.

---

## Each Render Has Its Own Effect

Remember: each render is a snapshot with its own props and state.

```jsx
function Counter() {
  const [count, setCount] = useState(0);

  useEffect(() => {
    setTimeout(() => {
      console.log(`Count is: ${count}`);
    }, 3000);
  }, [count]);

  return (
    <div>
      <p>Count: {count}</p>
      <button onClick={() => setCount(count + 1)}>Increment</button>
    </div>
  );
}
```

If you click the button 3 times quickly:

```
// After 3 seconds, you'll see:
Count is: 0
Count is: 1
Count is: 2
```

Not `Count is: 2` three times. Each effect "captured" the count at the time it was created.

---

## The Synchronization Perspective

Think of your component as keeping things in sync:

```jsx
function ChatRoom({ roomId }) {
  const [messages, setMessages] = useState([]);

  useEffect(() => {
    // "Synchronize connection with roomId"
    const connection = createConnection(roomId);
    connection.on('message', msg => {
      setMessages(m => [...m, msg]);
    });

    return () => {
      // "Clean up when roomId changes or component unmounts"
      connection.disconnect();
    };
  }, [roomId]);

  return <MessageList messages={messages} />;
}
```

The effect says: "Keep a connection open to `roomId`. When `roomId` changes, disconnect from the old room and connect to the new one."

---

## Effects Are Not Events

A common mistake is using effects for event responses:

```jsx
// WRONG: Using effect to respond to button click
function Form() {
  const [submitted, setSubmitted] = useState(false);

  useEffect(() => {
    if (submitted) {
      sendFormData(formData);
    }
  }, [submitted]);

  return (
    <button onClick={() => setSubmitted(true)}>
      Submit
    </button>
  );
}
```

**Problem:** You're using state + effect to do what an event handler should do.

```jsx
// RIGHT: Event handler for event response
function Form() {
  const handleSubmit = () => {
    sendFormData(formData);
  };

  return (
    <button onClick={handleSubmit}>
      Submit
    </button>
  );
}
```

**Rule of thumb:**
- **Event handlers:** Respond to user actions
- **Effects:** Synchronize with external systems

---

## When to Use Effects

### Yes: External System Sync

```jsx
// Sync with browser API
useEffect(() => {
  document.title = title;
}, [title]);

// Sync with subscription
useEffect(() => {
  const sub = source.subscribe(callback);
  return () => sub.unsubscribe();
}, [source]);

// Sync with third-party library
useEffect(() => {
  const map = new MapLibrary(mapRef.current, options);
  return () => map.destroy();
}, [options]);

// Sync with server (data fetching)
useEffect(() => {
  fetchData(id).then(setData);
}, [id]);
```

### No: Computed Values

```jsx
// WRONG: Computing in effect
const [items, setItems] = useState([]);
const [filteredItems, setFilteredItems] = useState([]);

useEffect(() => {
  setFilteredItems(items.filter(i => i.active));
}, [items]);

// RIGHT: Compute during render
const filteredItems = items.filter(i => i.active);
```

### No: Resetting State When Props Change

```jsx
// WRONG: Reset in effect
function Profile({ userId }) {
  const [comment, setComment] = useState('');

  useEffect(() => {
    setComment('');
  }, [userId]);

  // ...
}

// RIGHT: Use key to force remount
<Profile key={userId} userId={userId} />
```

### No: Responding to Events

```jsx
// WRONG: Effect to handle submission
useEffect(() => {
  if (isSubmitting) {
    submitForm();
    setIsSubmitting(false);
  }
}, [isSubmitting]);

// RIGHT: Event handler
const handleSubmit = async () => {
  await submitForm();
};
```

---

## The Effect Lifecycle

```jsx
useEffect(() => {
  // SETUP: Runs after render
  const connection = connect(roomId);

  return () => {
    // CLEANUP: Runs before next effect and on unmount
    connection.disconnect();
  };
}, [roomId]);
```

**Timeline:**

```
Render 1 (roomId = "general")
  → Effect 1 setup: connect to "general"

Render 2 (roomId = "random")
  → Effect 1 cleanup: disconnect from "general"
  → Effect 2 setup: connect to "random"

Unmount
  → Effect 2 cleanup: disconnect from "random"
```

Notice: Cleanup runs *before* the next effect, not just on unmount.

---

## Dependencies Are Not Triggers

The dependency array isn't "when to run." It's "what this effect uses from the component scope."

```jsx
useEffect(() => {
  // This effect uses `userId` and `name`
  saveUser(userId, name);
}, [userId, name]);  // So both must be in deps
```

**Lint rule:** Include everything from scope that the effect uses.

**Why?** So React knows when the effect needs to re-sync.

---

## The Questions to Ask

When writing an effect, ask:

1. **What external system am I syncing with?**
   - Document title? A subscription? A third-party library?

2. **What values does this effect use?**
   - Those are your dependencies.

3. **What needs to be cleaned up?**
   - Subscriptions, timers, connections?

4. **Could this be an event handler instead?**
   - If it's a response to user action, use an event handler.

5. **Could this be computed during render?**
   - If it's derived from props/state, compute it directly.

---

## Key Takeaways

1. **Effects are for synchronization**, not lifecycle
2. **Each render has its own effect** with its own captured values
3. **Effects are not event handlers** — use handlers for user events
4. **Don't compute in effects** — derive during render
5. **Dependencies are what the effect uses**, not "when to run"
6. **Cleanup runs before re-sync and on unmount**

The mental shift: From "do something after render" to "keep this in sync with that."

---

*Next: [Chapter 17: Cleanup and Dependencies](./17-cleanup-and-dependencies.md)*
