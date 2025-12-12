# Chapter 18: Putting It All Together

> *"The whole is greater than the sum of its parts."*
> — Aristotle

---

## The Complete Picture

We've covered a lot of ground. Let's see how all the pieces connect.

```
┌─────────────────────────────────────────────────────────────┐
│                        Your App                              │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   STATE (Single Source of Truth)                            │
│   ┌──────────────────────────────────────────────────────┐  │
│   │  const [user, setUser] = useState(null);             │  │
│   │  const [posts, setPosts] = useState([]);             │  │
│   │  const [theme, setTheme] = useState('light');        │  │
│   └──────────────────────────────────────────────────────┘  │
│                           │                                  │
│                           ▼                                  │
│   RENDER (Pure Function: UI = f(state))                     │
│   ┌──────────────────────────────────────────────────────┐  │
│   │  return (                                            │  │
│   │    <div className={theme}>                           │  │
│   │      <Header user={user} />                          │  │
│   │      <PostList posts={posts} />                      │  │
│   │    </div>                                            │  │
│   │  );                                                  │  │
│   └──────────────────────────────────────────────────────┘  │
│                           │                                  │
│                           ▼                                  │
│   VIRTUAL DOM (Lightweight Representation)                   │
│   ┌──────────────────────────────────────────────────────┐  │
│   │  { type: 'div', props: { className: 'light', ... }}  │  │
│   └──────────────────────────────────────────────────────┘  │
│                           │                                  │
│                           ▼                                  │
│   RECONCILIATION (Diff & Patch)                             │
│   ┌──────────────────────────────────────────────────────┐  │
│   │  Compare old VDOM to new VDOM                        │  │
│   │  Find minimal changes                                │  │
│   │  Apply to real DOM                                   │  │
│   └──────────────────────────────────────────────────────┘  │
│                           │                                  │
│                           ▼                                  │
│   EFFECTS (After Render, Sync with External World)          │
│   ┌──────────────────────────────────────────────────────┐  │
│   │  useEffect(() => {                                   │  │
│   │    document.title = `${posts.length} posts`;         │  │
│   │    const unsub = subscribe(user.id, setPosts);       │  │
│   │    return () => unsub();                             │  │
│   │  }, [user.id, posts.length]);                        │  │
│   └──────────────────────────────────────────────────────┘  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## A Complete Example

Let's build a small but complete feature: a user profile with editable bio.

```jsx
function ProfilePage({ userId }) {
  // STATE: What we know
  const [user, setUser] = useState(null);
  const [isEditing, setIsEditing] = useState(false);
  const [draftBio, setDraftBio] = useState('');
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState(null);

  // EFFECT: Sync with server
  useEffect(() => {
    let cancelled = false;

    async function loadUser() {
      try {
        const data = await fetchUser(userId);
        if (!cancelled) {
          setUser(data);
          setDraftBio(data.bio);
          setError(null);
        }
      } catch (err) {
        if (!cancelled) {
          setError('Failed to load user');
        }
      }
    }

    loadUser();

    return () => {
      cancelled = true;
    };
  }, [userId]);  // Re-fetch when userId changes

  // EVENT HANDLERS: User interactions
  const handleEditClick = () => {
    setIsEditing(true);
    setDraftBio(user.bio);
  };

  const handleCancelClick = () => {
    setIsEditing(false);
    setDraftBio(user.bio);
  };

  const handleSaveClick = async () => {
    setIsSaving(true);
    try {
      const updated = await updateUserBio(userId, draftBio);
      setUser(updated);
      setIsEditing(false);
    } catch (err) {
      setError('Failed to save');
    } finally {
      setIsSaving(false);
    }
  };

  // RENDER: UI = f(state)
  if (error) {
    return <div className="error">{error}</div>;
  }

  if (!user) {
    return <div className="loading">Loading...</div>;
  }

  return (
    <div className="profile">
      <Avatar src={user.avatar} alt={user.name} />
      <h1>{user.name}</h1>

      {isEditing ? (
        <div className="bio-editor">
          <textarea
            value={draftBio}
            onChange={e => setDraftBio(e.target.value)}
            disabled={isSaving}
          />
          <button onClick={handleSaveClick} disabled={isSaving}>
            {isSaving ? 'Saving...' : 'Save'}
          </button>
          <button onClick={handleCancelClick} disabled={isSaving}>
            Cancel
          </button>
        </div>
      ) : (
        <div className="bio">
          <p>{user.bio}</p>
          <button onClick={handleEditClick}>Edit</button>
        </div>
      )}
    </div>
  );
}
```

**Notice how the principles apply:**

1. **State is minimal:** Just what we can't derive
2. **UI is a pure function:** Given these states, this is what we show
3. **Effects sync with external systems:** Fetching user data
4. **Event handlers for user interactions:** Editing, saving, canceling
5. **One-way data flow:** State down, events up

---

## Tracing the Flow

Let's trace what happens when the user clicks "Edit":

```
1. User clicks "Edit" button
   └── onClick={handleEditClick} fires

2. handleEditClick runs
   └── setIsEditing(true)
   └── setDraftBio(user.bio)

3. State changes trigger re-render
   └── ProfilePage() is called with new state

4. Render produces new VDOM
   └── isEditing is true, so <textarea> branch renders

5. React diffs old and new VDOM
   └── <p>{user.bio}</p> → <textarea value={draftBio}>
   └── "Edit" button → "Save" and "Cancel" buttons

6. React commits changes to DOM
   └── Replace p with textarea
   └── Replace button with two buttons

7. Effects run (none triggered in this case)

8. User sees the edit form
```

Every step is predictable. You can trace the exact causality.

---

## Common Patterns in Full Context

### Loading States

```jsx
function DataComponent({ id }) {
  const [data, setData] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    setIsLoading(true);
    setError(null);

    fetchData(id)
      .then(setData)
      .catch(setError)
      .finally(() => setIsLoading(false));
  }, [id]);

  if (isLoading) return <Spinner />;
  if (error) return <Error message={error.message} />;
  return <DataDisplay data={data} />;
}
```

### Form Handling

```jsx
function ContactForm({ onSubmit }) {
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    message: ''
  });

  const handleChange = (e) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    onSubmit(formData);
  };

  return (
    <form onSubmit={handleSubmit}>
      <input name="name" value={formData.name} onChange={handleChange} />
      <input name="email" value={formData.email} onChange={handleChange} />
      <textarea name="message" value={formData.message} onChange={handleChange} />
      <button type="submit">Send</button>
    </form>
  );
}
```

### Conditional Rendering

```jsx
function Dashboard({ user, notifications, settings }) {
  return (
    <div>
      {/* Boolean condition */}
      {user.isAdmin && <AdminPanel />}

      {/* Ternary for either/or */}
      {user.isLoggedIn ? <UserMenu user={user} /> : <LoginButton />}

      {/* Null/undefined check */}
      {notifications && <NotificationBadge count={notifications.length} />}

      {/* Complex conditions as functions */}
      {renderContent()}
    </div>
  );

  function renderContent() {
    if (settings.maintenanceMode) return <MaintenancePage />;
    if (!user.hasAccess) return <AccessDenied />;
    return <MainContent />;
  }
}
```

---

## The Architecture Emerges

When you apply these principles consistently, architecture emerges naturally:

```
src/
├── components/
│   ├── ui/           # Presentational (pure, no state)
│   │   ├── Button.jsx
│   │   ├── Card.jsx
│   │   └── Input.jsx
│   └── features/     # Feature components (state + effects)
│       ├── UserProfile.jsx
│       ├── PostList.jsx
│       └── CommentThread.jsx
├── hooks/            # Reusable stateful logic
│   ├── useUser.js
│   ├── usePosts.js
│   └── useForm.js
└── utils/            # Pure functions
    ├── formatDate.js
    └── validation.js
```

**UI components:** Pure, receive props, render UI
**Feature components:** Manage state and effects, compose UI components
**Custom hooks:** Extract and reuse stateful logic
**Utils:** Pure functions for data transformation

---

## Key Takeaways

1. **State is the source of truth** — Everything else derives from it
2. **Render is a pure function** — Same state = same UI
3. **Effects sync with the outside world** — After render, clean up before re-sync
4. **Events trigger state changes** — The only way UI updates
5. **Data flows one way** — Down through props, up through callbacks
6. **Architecture emerges from principles** — You don't force it

When you understand these principles, you're not following rules—you're reasoning from fundamentals.

---

*Next: [Chapter 19: The React Mindset](./19-react-mindset.md)*
