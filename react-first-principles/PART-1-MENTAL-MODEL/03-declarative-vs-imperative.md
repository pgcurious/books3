# Chapter 3: Declarative vs Imperative

> *"Describe the destination, not the journey."*
> — The essence of declarative programming

---

## Two Ways to Give Directions

Imagine you're telling someone how to get to your house.

### The Imperative Way

> "Start at Main Street. Turn left onto Oak Avenue. Go 0.3 miles. Turn right at the gas station. Continue until you see the red mailbox. Turn left. My house is the third one on the right."

You're describing **every step**. The listener follows your instructions exactly. If there's road construction, they're stuck.

### The Declarative Way

> "My address is 123 Maple Lane."

You're describing the **desired end state**. The listener (or their GPS) figures out how to get there. Road construction? They reroute automatically.

---

## The Programming Parallel

### Imperative Code

```javascript
// "Here's how to build a list of users"
const ul = document.createElement('ul');
for (let i = 0; i < users.length; i++) {
  const li = document.createElement('li');
  li.textContent = users[i].name;
  li.addEventListener('click', () => selectUser(users[i].id));
  ul.appendChild(li);
}
document.getElementById('container').appendChild(ul);
```

You're telling the computer:
1. Create an unordered list
2. Loop through users
3. For each user, create a list item
4. Set its text
5. Attach an event listener
6. Append it to the list
7. Append the list to the container

**You control every step.**

### Declarative Code

```jsx
// "Here's what the list should look like"
<ul>
  {users.map(user => (
    <li key={user.id} onClick={() => selectUser(user.id)}>
      {user.name}
    </li>
  ))}
</ul>
```

You're telling the computer:
1. I want an unordered list
2. It should contain a list item for each user
3. Each item shows the user's name and handles clicks

**You describe the end state. React figures out the steps.**

---

## Why This Matters

### Imperative: You Manage Transitions

In imperative programming, you're responsible for getting from state A to state B.

```javascript
// State A: showing 3 users
// State B: showing 2 users (one was deleted)

// YOU must figure out:
// - Which DOM node represents the deleted user?
// - Remove that node
// - Don't touch the others
// - Oh wait, did the indices shift?
// - Are the event listeners still correct?

function removeUser(userId) {
  const li = document.querySelector(`[data-user-id="${userId}"]`);
  if (li) {
    li.parentNode.removeChild(li);
  }
  // Don't forget to update the data too
  users = users.filter(u => u.id !== userId);
}
```

### Declarative: You Describe Snapshots

In declarative programming, you describe what the UI should look like for *any* given state.

```jsx
function UserList({ users }) {
  return (
    <ul>
      {users.map(user => (
        <li key={user.id}>{user.name}</li>
      ))}
    </ul>
  );
}

// State A: users = [alice, bob, charlie]
// React renders: <li>Alice</li><li>Bob</li><li>Charlie</li>

// State B: users = [alice, charlie]
// React renders: <li>Alice</li><li>Charlie</li>

// React figures out: "I need to remove the Bob node"
// You never wrote that logic
```

---

## The Profound Shift

Think about what just happened.

**With imperative code**, you must account for every possible state transition:
- 0 users → 1 user (add one)
- 3 users → 2 users (remove one)
- 2 users → 2 users but different order (reorder)
- 5 users → 5 users but one changed name (update one)
- Empty state → loading state → loaded state → error state (every combination)

For N possible states, you have N² possible transitions. Each one is a potential bug.

**With declarative code**, you describe N states. That's it.

```jsx
function UserList({ users, isLoading, error }) {
  if (isLoading) return <Spinner />;
  if (error) return <Error message={error} />;
  if (users.length === 0) return <Empty />;

  return (
    <ul>
      {users.map(user => <li key={user.id}>{user.name}</li>)}
    </ul>
  );
}
```

This function says: "Here's what to show for any combination of users, isLoading, and error." React handles every transition between these states.

---

## SQL: You Already Know This

If you've written SQL, you've used declarative programming:

```sql
-- Declarative: What do I want?
SELECT name, email FROM users WHERE active = true ORDER BY name;

-- The database figures out:
-- - Which index to use
-- - Whether to do a full table scan
-- - How to sort efficiently
-- - Memory management
-- - Parallel execution
```

You don't write:
```javascript
// Imperative: How do I get it?
const results = [];
for (let i = 0; i < table.length; i++) {
  if (table[i].active === true) {
    results.push({ name: table[i].name, email: table[i].email });
  }
}
results.sort((a, b) => a.name.localeCompare(b.name));
```

SQL is declarative because:
1. **Experts optimized the "how"** — Database engineers spent decades making it fast
2. **Optimization can improve** — New database version? Faster queries, no code changes
3. **Intent is clear** — Reading SQL tells you *what* you want, not *how* you're getting it

React brings these same benefits to UI development.

---

## The React Insight

Here's what React's creators realized:

**Building UIs is fundamentally about describing what should be on screen for any given state.**

The transitions between states are:
1. **Tedious** — Mostly mechanical work
2. **Error-prone** — Easy to forget edge cases
3. **Optimizable** — Can be made fast by framework authors
4. **Unchanging** — The "how to diff and update" doesn't depend on your specific app

So why make every developer solve the same problem?

---

## Declarative Unlocks Optimization

When you describe *what* you want instead of *how* to get it, you create room for optimization.

### Batching

```javascript
// Imperative: Each line triggers a DOM update
element1.textContent = 'Hello';   // Browser: update, layout, paint
element2.textContent = 'World';   // Browser: update, layout, paint
element3.style.color = 'red';     // Browser: update, layout, paint
```

```jsx
// Declarative: React batches updates
setGreeting('Hello');
setSubject('World');
setColor('red');
// React: Update all three, then ONE layout, ONE paint
```

### Skipping Unnecessary Work

```jsx
function App({ user, theme }) {
  return (
    <div className={theme}>
      <Header user={user} />      {/* Only re-render if user changed */}
      <Sidebar theme={theme} />   {/* Only re-render if theme changed */}
      <Content />                  {/* Never re-render if props don't change */}
    </div>
  );
}
```

React can skip re-rendering components when their inputs haven't changed. In imperative code, you'd have to build this optimization yourself.

### Concurrent Rendering

React 18 introduced concurrent features that let React:
- Start rendering an update
- Pause in the middle if something more urgent happens
- Resume later

This is only possible because React controls the "how." If you were imperatively modifying the DOM, pausing mid-update would leave the UI in a broken state.

---

## The Cost of Declarative

Nothing is free. Declarative programming trades:

**What you give up:**
- Direct control over DOM operations
- Ability to make micro-optimizations
- (Sometimes) predictability of exactly when things update

**What you gain:**
- Automatic state-to-UI synchronization
- Ability to reason about UI as a function of state
- Framework-level optimizations
- Fewer bugs from forgotten update logic

For 99% of UI work, this trade-off is massively positive.

---

## The Mental Model Shift

Stop thinking about **what to change** when state updates.

Start thinking about **what the screen should look like** for any given state.

```jsx
// Don't think: "When loading finishes, I need to hide the spinner
//              and show the data and update the count..."

// Think: "For these inputs, here's the output"
function DataView({ isLoading, data, error }) {
  if (isLoading) return <Spinner />;
  if (error) return <Error error={error} />;
  return <DataTable data={data} />;
}
```

This function is a **pure mapping from state to UI**. Given the same inputs, it always returns the same output. React handles everything else.

---

## Key Takeaways

1. **Imperative** = "Here's how to update things step by step"
2. **Declarative** = "Here's what I want. You figure out how."
3. **React is declarative**: You describe the UI for any state; React handles updates
4. **This eliminates N² transition bugs**: You only describe N states, not N² transitions
5. **Declarative enables optimization**: Batching, memoization, concurrent rendering
6. **The mental shift**: Stop thinking "what do I change?" Start thinking "what should it look like?"

---

*Next: [Chapter 4: Components as Functions](./04-components-as-functions.md)*
