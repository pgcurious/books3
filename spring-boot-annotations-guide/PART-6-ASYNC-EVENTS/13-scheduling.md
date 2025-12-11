# Scheduling & Cron

## Running Tasks on a Schedule

---

## Overview

| Annotation | Purpose |
|------------|---------|
| `@EnableScheduling` | Enable scheduled task execution |
| `@Scheduled` | Mark method to run on schedule |
| `@Schedules` | Multiple schedules on one method |

---

## @EnableScheduling - Enable Scheduling

### Basic Setup

```java
@Configuration
@EnableScheduling
public class SchedulingConfig {
    // Scheduling is now enabled
}

// Or on main class
@SpringBootApplication
@EnableScheduling
public class Application { }
```

### With Custom Scheduler

```java
@Configuration
@EnableScheduling
public class SchedulingConfig implements SchedulingConfigurer {

    @Override
    public void configureTasks(ScheduledTaskRegistrar taskRegistrar) {
        ThreadPoolTaskScheduler scheduler = new ThreadPoolTaskScheduler();
        scheduler.setPoolSize(5);
        scheduler.setThreadNamePrefix("Scheduled-");
        scheduler.initialize();
        taskRegistrar.setTaskScheduler(scheduler);
    }
}
```

---

## @Scheduled - Fixed Rate

### Run Every X Milliseconds

```java
@Component
public class ScheduledTasks {

    // Every 5 seconds (from start of previous execution)
    @Scheduled(fixedRate = 5000)
    public void runEvery5Seconds() {
        log.info("Fixed rate task - {}", LocalDateTime.now());
    }

    // Using Duration string (Spring 5.3+)
    @Scheduled(fixedRateString = "PT5S")  // 5 seconds
    public void runWithDuration() { }

    // From property
    @Scheduled(fixedRateString = "${task.rate:5000}")
    public void runFromProperty() { }
}
```

### Initial Delay

```java
@Component
public class ScheduledTasks {

    // Wait 10s after startup, then every 5s
    @Scheduled(fixedRate = 5000, initialDelay = 10000)
    public void runWithInitialDelay() {
        log.info("Task running");
    }

    // Using strings
    @Scheduled(
        fixedRateString = "${task.rate}",
        initialDelayString = "${task.initialDelay}"
    )
    public void configurable() { }
}
```

---

## @Scheduled - Fixed Delay

### Run X Milliseconds After Previous Completes

```java
@Component
public class ScheduledTasks {

    // Wait 5s after previous execution COMPLETES
    @Scheduled(fixedDelay = 5000)
    public void runWithFixedDelay() {
        log.info("Starting task");
        performSlowOperation();  // Takes 3 seconds
        log.info("Task complete");
        // Next execution starts 5s after this point
    }
}
```

### Fixed Rate vs Fixed Delay

```java
// Fixed Rate: Every 5 seconds, regardless of execution time
// If task takes 3s: runs at 0s, 5s, 10s, 15s...
// If task takes 7s: runs at 0s, 7s (late!), 12s (late!)...
@Scheduled(fixedRate = 5000)
public void fixedRate() { }

// Fixed Delay: 5 seconds AFTER previous completion
// If task takes 3s: runs at 0s, 8s (3+5), 16s (8+3+5)...
// If task takes 7s: runs at 0s, 12s (7+5), 24s (12+7+5)...
@Scheduled(fixedDelay = 5000)
public void fixedDelay() { }
```

---

## @Scheduled - Cron Expressions

### Basic Cron

```java
@Component
public class ScheduledTasks {

    // Every day at midnight
    @Scheduled(cron = "0 0 0 * * *")
    public void runAtMidnight() { }

    // Every hour at minute 0
    @Scheduled(cron = "0 0 * * * *")
    public void runEveryHour() { }

    // Every 15 minutes
    @Scheduled(cron = "0 */15 * * * *")
    public void runEvery15Minutes() { }

    // Monday to Friday at 9 AM
    @Scheduled(cron = "0 0 9 * * MON-FRI")
    public void runWeekdaysAt9AM() { }
}
```

### Cron Expression Format

```
┌───────────── second (0-59)
│ ┌───────────── minute (0-59)
│ │ ┌───────────── hour (0-23)
│ │ │ ┌───────────── day of month (1-31)
│ │ │ │ ┌───────────── month (1-12 or JAN-DEC)
│ │ │ │ │ ┌───────────── day of week (0-7 or SUN-SAT, 0 and 7 are Sunday)
│ │ │ │ │ │
* * * * * *
```

### Common Cron Examples

```java
// Every second
@Scheduled(cron = "* * * * * *")

// Every minute
@Scheduled(cron = "0 * * * * *")

// Every hour
@Scheduled(cron = "0 0 * * * *")

// Every day at midnight
@Scheduled(cron = "0 0 0 * * *")

// Every day at 6 AM
@Scheduled(cron = "0 0 6 * * *")

// Every Monday at 9 AM
@Scheduled(cron = "0 0 9 * * MON")

// First day of every month at midnight
@Scheduled(cron = "0 0 0 1 * *")

// Every 30 minutes
@Scheduled(cron = "0 */30 * * * *")

// Every 5 minutes during business hours (9 AM - 5 PM)
@Scheduled(cron = "0 */5 9-17 * * MON-FRI")

// At 10:15 AM on the 15th of every month
@Scheduled(cron = "0 15 10 15 * *")

// Last day of every month at 11 PM
@Scheduled(cron = "0 0 23 L * *")  // L = last day
```

### Cron with Timezone

```java
@Scheduled(cron = "0 0 9 * * *", zone = "America/New_York")
public void runAt9AMNewYork() { }

@Scheduled(cron = "0 0 9 * * *", zone = "Europe/London")
public void runAt9AMLondon() { }

@Scheduled(cron = "0 0 9 * * *", zone = "Asia/Tokyo")
public void runAt9AMTokyo() { }
```

### Cron from Properties

```properties
# application.properties
task.cron=0 0 9 * * MON-FRI
```

```java
@Scheduled(cron = "${task.cron}")
public void configurableCron() { }

// With default
@Scheduled(cron = "${task.cron:0 0 0 * * *}")
public void withDefault() { }
```

---

## @Schedules - Multiple Schedules

```java
@Component
public class MultiScheduledTask {

    @Schedules({
        @Scheduled(cron = "0 0 9 * * MON-FRI"),  // Weekdays at 9 AM
        @Scheduled(cron = "0 0 12 * * SAT,SUN")  // Weekends at noon
    })
    public void runOnMultipleSchedules() {
        log.info("Running scheduled task");
    }
}
```

---

## Conditional Scheduling

### Disable with Property

```java
@Component
public class ScheduledTasks {

    // "-" disables the schedule
    @Scheduled(cron = "${task.cron:-}")
    public void conditionalTask() { }
}
```

```properties
# To disable
task.cron=-

# To enable
task.cron=0 0 9 * * *
```

### Profile-Based Scheduling

```java
@Component
@Profile("!test")  // Don't run in test profile
public class ScheduledTasks {

    @Scheduled(fixedRate = 60000)
    public void productionOnlyTask() { }
}
```

---

## Scheduled Task Patterns

### With Locking (Distributed Systems)

```java
@Component
public class ScheduledTasks {

    private final LockProvider lockProvider;

    @Scheduled(cron = "0 0 * * * *")
    @SchedulerLock(name = "hourlyTask", lockAtMostFor = "PT50M", lockAtLeastFor = "PT5M")
    public void hourlyTaskWithLock() {
        // Only one instance runs in a cluster
    }
}

// ShedLock configuration
@Configuration
public class ShedLockConfig {

    @Bean
    public LockProvider lockProvider(DataSource dataSource) {
        return new JdbcTemplateLockProvider(
            JdbcTemplateLockProvider.Configuration.builder()
                .withJdbcTemplate(new JdbcTemplate(dataSource))
                .usingDbTime()
                .build()
        );
    }
}
```

### Error Handling

```java
@Component
@Slf4j
public class ResilientScheduledTask {

    @Scheduled(fixedRate = 60000)
    public void taskWithErrorHandling() {
        try {
            performTask();
        } catch (TransientException e) {
            log.warn("Transient error, will retry next run: {}", e.getMessage());
        } catch (Exception e) {
            log.error("Unexpected error in scheduled task", e);
            alertService.notify("Scheduled task failed", e);
        }
    }
}
```

### Progress Logging

```java
@Component
@Slf4j
public class LongRunningTask {

    @Scheduled(cron = "0 0 2 * * *")  // 2 AM daily
    public void dataProcessingTask() {
        log.info("Starting data processing task");
        Instant start = Instant.now();

        try {
            int processed = processAllRecords();

            Duration duration = Duration.between(start, Instant.now());
            log.info("Completed processing {} records in {}", processed, duration);
        } catch (Exception e) {
            Duration duration = Duration.between(start, Instant.now());
            log.error("Task failed after {}: {}", duration, e.getMessage(), e);
            throw e;
        }
    }
}
```

### Preventing Overlap

```java
@Component
public class NonOverlappingTask {

    private final AtomicBoolean running = new AtomicBoolean(false);

    @Scheduled(fixedRate = 5000)
    public void taskThatShouldNotOverlap() {
        if (!running.compareAndSet(false, true)) {
            log.warn("Previous execution still running, skipping");
            return;
        }

        try {
            performLongTask();
        } finally {
            running.set(false);
        }
    }
}
```

---

## Programmatic Scheduling

### TaskScheduler

```java
@Service
public class DynamicScheduler {

    private final TaskScheduler taskScheduler;
    private final Map<String, ScheduledFuture<?>> scheduledTasks = new ConcurrentHashMap<>();

    public void scheduleTask(String taskId, Runnable task, String cron) {
        ScheduledFuture<?> future = taskScheduler.schedule(
            task,
            new CronTrigger(cron)
        );
        scheduledTasks.put(taskId, future);
    }

    public void cancelTask(String taskId) {
        ScheduledFuture<?> future = scheduledTasks.get(taskId);
        if (future != null) {
            future.cancel(false);
            scheduledTasks.remove(taskId);
        }
    }

    public void scheduleOneTime(Runnable task, Instant when) {
        taskScheduler.schedule(task, when);
    }
}
```

---

## Key Takeaways

1. **@EnableScheduling required** to activate @Scheduled
2. **fixedRate vs fixedDelay** - from start vs from completion
3. **Cron expressions** for complex schedules
4. **Use zone parameter** for timezone-specific schedules
5. **Disable with "-"** cron value
6. **Use locking** (ShedLock) in distributed systems
7. **Handle exceptions** - scheduled tasks should not throw

---

*Next: [Event-Driven Architecture](./14-events.md)*
