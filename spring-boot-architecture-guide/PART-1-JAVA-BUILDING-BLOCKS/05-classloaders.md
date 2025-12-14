# Chapter 5: ClassLoaders—The Hidden Engine

> *"The class loader is among the most underappreciated and misunderstood components of the Java platform."*
> — Venkat Subramaniam

---

## The Problem: Where Do Classes Come From?

We've used `Class.forName("com.example.User")` to load classes dynamically. But have you wondered: where does the JVM find that class? How does it know where to look?

When you write:

```java
User user = new User();
```

The JVM needs to:
1. Find the compiled `User.class` file
2. Read the bytecode
3. Transform it into a runtime `Class` object
4. Use that `Class` object to create instances

This process is called **class loading**, and it's performed by **ClassLoaders**.

---

## What ClassLoaders Do

A ClassLoader is responsible for:

1. **Finding** class files (from disk, network, memory, anywhere)
2. **Loading** the bytecode into memory
3. **Defining** the class (creating the `Class` object)
4. **Linking** the class (verification, preparation, resolution)
5. **Initializing** static fields and blocks

Every class in Java is loaded by *some* ClassLoader. Even `java.lang.String`.

---

## The ClassLoader Hierarchy

Java uses a hierarchical ClassLoader system:

```
┌─────────────────────────────────────┐
│     Bootstrap ClassLoader           │  Loads core Java classes
│     (native code, not Java)         │  (java.lang.*, java.util.*, etc.)
└────────────────┬────────────────────┘
                 │ parent
┌────────────────▼────────────────────┐
│     Platform ClassLoader            │  Loads platform/extension classes
│     (Java 9+, was Extension CL)     │  (javax.*, etc.)
└────────────────┬────────────────────┘
                 │ parent
┌────────────────▼────────────────────┐
│     Application ClassLoader         │  Loads your application classes
│     (System ClassLoader)            │  (from classpath)
└────────────────┬────────────────────┘
                 │ parent
┌────────────────▼────────────────────┐
│     Custom ClassLoaders             │  Framework/application specific
│     (Spring, Tomcat, etc.)          │  (from JARs, URLs, etc.)
└─────────────────────────────────────┘
```

### Parent-First Delegation

When a ClassLoader is asked to load a class, it follows **parent-first delegation**:

```java
protected Class<?> loadClass(String name) {
    // 1. Check if already loaded
    Class<?> c = findLoadedClass(name);
    if (c != null) return c;

    // 2. Delegate to parent first
    if (parent != null) {
        try {
            c = parent.loadClass(name);
            return c;
        } catch (ClassNotFoundException e) {
            // Parent couldn't load it, we'll try ourselves
        }
    }

    // 3. Try to load ourselves
    return findClass(name);
}
```

This ensures:
- Core classes like `String` are always loaded by Bootstrap ClassLoader
- You can't accidentally shadow core classes with malicious versions
- Classes are loaded consistently across the application

---

## Why Frameworks Need Custom ClassLoaders

Parent-first delegation works great for simple applications, but frameworks need more:

### 1. Loading from Multiple Sources

An application server like Tomcat needs to load:
- Server classes from one location
- Each web application from its own directory
- Shared libraries from another location

### 2. Isolation Between Applications

Two web applications might use different versions of the same library:
- App1 uses Jackson 2.10
- App2 uses Jackson 2.15

Without isolation, only one version could exist in the JVM.

### 3. Hot Reloading

During development, you want to change code and see results without restarting. This requires:
- Unloading old class definitions
- Loading new class definitions

This is only possible with custom ClassLoaders because:
- A class can only be loaded once per ClassLoader
- But you can create a *new* ClassLoader and load the class again

---

## Building a Custom ClassLoader

Let's build a simple ClassLoader that loads classes from a specific directory:

```java
public class DirectoryClassLoader extends ClassLoader {
    private final Path classesDir;

    public DirectoryClassLoader(Path classesDir, ClassLoader parent) {
        super(parent);
        this.classesDir = classesDir;
    }

    @Override
    protected Class<?> findClass(String name) throws ClassNotFoundException {
        // Convert class name to file path
        // com.example.User -> com/example/User.class
        String fileName = name.replace('.', '/') + ".class";
        Path classFile = classesDir.resolve(fileName);

        if (!Files.exists(classFile)) {
            throw new ClassNotFoundException(name);
        }

        try {
            // Read the bytecode
            byte[] bytecode = Files.readAllBytes(classFile);

            // Define the class
            return defineClass(name, bytecode, 0, bytecode.length);

        } catch (IOException e) {
            throw new ClassNotFoundException(name, e);
        }
    }
}
```

Usage:

```java
// Load classes from a specific directory
Path pluginDir = Paths.get("/plugins/my-plugin/classes");
ClassLoader pluginLoader = new DirectoryClassLoader(pluginDir, getClass().getClassLoader());

// Load a class from that directory
Class<?> pluginClass = pluginLoader.loadClass("com.plugin.MyPlugin");
Object plugin = pluginClass.getDeclaredConstructor().newInstance();
```

---

## How Spring Boot Uses ClassLoaders

Spring Boot creates executable JARs with a special structure:

```
my-app.jar
├── BOOT-INF/
│   ├── classes/           # Your application classes
│   └── lib/               # Dependency JARs (nested!)
│       ├── spring-core-5.3.0.jar
│       ├── jackson-core-2.12.0.jar
│       └── ...
├── META-INF/
│   └── MANIFEST.MF
└── org/springframework/boot/loader/
    ├── JarLauncher.class
    ├── LaunchedURLClassLoader.class
    └── ...
```

The challenge: standard Java can't read JARs inside JARs.

Spring Boot's solution:

```java
// Spring Boot's launcher (simplified)
public class JarLauncher {
    public static void main(String[] args) {
        // 1. Create special ClassLoader that understands nested JARs
        ClassLoader classLoader = new LaunchedURLClassLoader(
            getNestedJarURLs()  // URLs pointing into BOOT-INF/lib/*.jar
        );

        // 2. Load the main application class with this ClassLoader
        Class<?> mainClass = classLoader.loadClass("com.example.MyApplication");

        // 3. Invoke main method
        Method mainMethod = mainClass.getMethod("main", String[].class);
        mainMethod.invoke(null, new Object[]{args});
    }
}
```

The `LaunchedURLClassLoader`:
- Reads from nested JARs
- Handles classpath scanning across nested structures
- Enables the "fat JAR" deployment model

---

## ClassLoader and Class Identity

Here's a crucial insight: **a class's identity includes its ClassLoader**.

```java
ClassLoader loader1 = new DirectoryClassLoader(path, parent);
ClassLoader loader2 = new DirectoryClassLoader(path, parent);

Class<?> class1 = loader1.loadClass("com.example.User");
Class<?> class2 = loader2.loadClass("com.example.User");

class1 == class2;  // false! Different ClassLoaders = different classes
class1.equals(class2);  // false!
```

Even though it's the same bytecode, same fully qualified name, **they are different classes** because they were loaded by different ClassLoaders.

This has real implications:

```java
Object user1 = class1.newInstance();
Object user2 = class2.newInstance();

// This throws ClassCastException!
User u = (User) user1;  // If 'User' was loaded by a different ClassLoader
```

This is often the cause of mysterious `ClassCastException` in application servers and OSGi environments.

---

## Classpath Scanning: Finding Classes

Frameworks need to find classes without knowing their names in advance. This is **classpath scanning**.

### The Challenge

There's no standard Java API to "list all classes in a package." The classpath is a collection of directories and JARs, and Java only loads classes on demand.

### The Solution: Resource Scanning

```java
public List<Class<?>> findClassesInPackage(String packageName) {
    List<Class<?>> classes = new ArrayList<>();
    String path = packageName.replace('.', '/');

    // Get all locations where this package might exist
    Enumeration<URL> resources = getClass().getClassLoader()
        .getResources(path);

    while (resources.hasMoreElements()) {
        URL resource = resources.nextElement();

        if (resource.getProtocol().equals("file")) {
            // It's a directory
            File directory = new File(resource.toURI());
            for (File file : directory.listFiles()) {
                if (file.getName().endsWith(".class")) {
                    String className = packageName + "." +
                        file.getName().replace(".class", "");
                    classes.add(Class.forName(className));
                }
            }
        } else if (resource.getProtocol().equals("jar")) {
            // It's inside a JAR - need to read JAR entries
            // ... more complex handling
        }
    }

    return classes;
}
```

Spring's `ClassPathScanningCandidateComponentProvider` does this with extensive optimizations:
- Uses ASM to read class metadata without loading classes
- Caches scan results
- Handles nested JARs, OSGi bundles, etc.

---

## Thread Context ClassLoader

Sometimes code needs to load classes but doesn't know which ClassLoader to use. Java provides a solution: the **Thread Context ClassLoader**.

```java
// Get current thread's context ClassLoader
ClassLoader tcl = Thread.currentThread().getContextClassLoader();

// Set it (typically done by frameworks/containers)
Thread.currentThread().setContextClassLoader(myClassLoader);
```

Why is this needed?

```java
// Core Java class needs to load application-specific class
// java.sql.DriverManager needs to find database drivers
// But DriverManager is loaded by Bootstrap ClassLoader
// Bootstrap ClassLoader can't see application classpath!

// Solution: use Thread Context ClassLoader
ClassLoader tcl = Thread.currentThread().getContextClassLoader();
Class<?> driverClass = tcl.loadClass("com.mysql.jdbc.Driver");
```

Frameworks set the Thread Context ClassLoader so that:
- SPI (Service Provider Interface) mechanisms work
- Serialization can find classes
- JNDI lookups work correctly

---

## ClassLoader Leaks

A common problem in long-running applications: **ClassLoader leaks**.

```java
while (true) {
    // Hot reload: create new ClassLoader
    ClassLoader loader = new DirectoryClassLoader(path, parent);
    Class<?> pluginClass = loader.loadClass("Plugin");
    Object plugin = pluginClass.newInstance();

    // Use the plugin...

    // "Unload" by discarding references
    plugin = null;
    pluginClass = null;
    loader = null;

    // Force GC
    System.gc();

    // But the ClassLoader might NOT be garbage collected!
}
```

ClassLoader leaks occur when something holds a reference to:
- A class loaded by that ClassLoader
- An instance of such a class
- The ClassLoader itself

Common culprits:
- ThreadLocal variables holding class instances
- Cached class references
- Registered shutdown hooks
- Static fields

---

## Modern Java: Modules and ClassLoaders

Java 9+ introduced the module system (JPMS), which interacts with ClassLoaders:

```java
// Each module has a ClassLoader
Module myModule = MyClass.class.getModule();
ClassLoader moduleLoader = myModule.getClassLoader();

// Modules control visibility
// Even with reflection, you can't access unexported packages
// (unless you use --add-opens)
```

This creates friction with frameworks that rely on reflection. Spring has adapted, but older frameworks may require workarounds.

---

## Putting It Together: Spring Boot Startup

When Spring Boot starts:

1. **JVM starts** with `java -jar app.jar`

2. **JarLauncher.main()** executes (from Bootstrap ClassLoader)

3. **LaunchedURLClassLoader created** with nested JARs

4. **Your @SpringBootApplication class loaded** by LaunchedURLClassLoader

5. **SpringApplication.run() executes**

6. **Component scanning** uses ClassLoader.getResources() to find classes

7. **Each @Component class is loaded** by LaunchedURLClassLoader

8. **Bean instances created** using reflection

All of this relies on ClassLoaders working correctly.

---

## Key Takeaways

1. **ClassLoaders find and load classes** into the JVM
2. **Hierarchical delegation** ensures core classes are loaded consistently
3. **Custom ClassLoaders** enable isolation, hot reloading, and special loading strategies
4. **Class identity includes ClassLoader** — same bytecode, different ClassLoader = different class
5. **Classpath scanning** lets frameworks discover classes at runtime
6. **Thread Context ClassLoader** enables SPI and framework integration
7. **ClassLoader leaks** are a real problem in long-running applications

---

*Next: [Chapter 6: Bytecode and Proxies](./06-bytecode-proxies.md)*
