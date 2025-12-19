# Chapter 41: Two-Phase Commit—Distributed Transactions

## All-or-Nothing Across Multiple Systems

---

> *"Two-Phase Commit: everyone agrees, or everyone backs out."*
> — Database Fundamentals

---

## The Frustration

You're transferring money between two banks:

```
Bank A: Debit $100 from Alice
Bank B: Credit $100 to Bob

What if Bank A succeeds but Bank B fails?
Alice loses $100. Bob gets nothing. Money vanishes.
```

You need atomicity across systems: either both succeed or both fail.

## The Insight: Coordinate the Commit

Two-Phase Commit (2PC) splits the commit into two phases:

### Phase 1: Prepare (Voting)

```
Coordinator → Participant A: "Prepare to commit"
Coordinator → Participant B: "Prepare to commit"

Participant A: Checks if it CAN commit
              Logs to disk
              Locks resources
              → "Yes, I can commit"

Participant B: Checks if it CAN commit
              Logs to disk
              Locks resources
              → "Yes, I can commit"
```

### Phase 2: Commit (Decision)

```
All said yes?

Coordinator → Participant A: "Commit"
Coordinator → Participant B: "Commit"

Participant A: Commits and releases locks
Participant B: Commits and releases locks
```

Or if anyone said no:

```
Coordinator → Participant A: "Abort"
Coordinator → Participant B: "Abort"

Everyone rolls back.
```

## The State Machine

```
                    INITIAL
                       │
              ┌────────┴────────┐
              │  Prepare sent   │
              ▼                 ▼
         ┌────────┐        ┌────────┐
         │ VOTED  │        │ ABORTED│
         │  YES   │        └────────┘
         └────┬───┘
              │ (all voted yes)
              ▼
         ┌────────┐
         │COMMITTED│
         └────────┘
```

## The Blocking Problem

What if the coordinator crashes after receiving votes but before sending commit?

```
Phase 1:
Participant A: "Yes" → waiting...
Participant B: "Yes" → waiting...
Coordinator: *crashes*

Participants are stuck!
- Can't commit (might abort)
- Can't abort (might commit)
- Resources locked indefinitely
```

This is the blocking problem. 2PC is a blocking protocol.

### Recovery Options

**Coordinator Recovery**:
```
Coordinator restarts, reads log
Continues from where it left off
Participants finally get decision
```

**Participant Timeout**:
```
After timeout, ask other participants
If any committed → commit
If any aborted → abort
If all uncertain → stay blocked
```

## 2PC in Practice

### Database Systems

```sql
-- XA Transactions (eXtended Architecture)
XA START 'txn-123';
UPDATE accounts SET balance = balance - 100 WHERE id = 1;
XA END 'txn-123';
XA PREPARE 'txn-123';
-- Coordinator decides...
XA COMMIT 'txn-123';
```

### Message Queues

```
Transactional outbox pattern:
1. Write to database
2. Write to outbox table
3. Message broker reads outbox
4. All in one transaction
```

## Three-Phase Commit

Attempts to solve the blocking problem:

```
Phase 1: CanCommit?
Phase 2: PreCommit (tentative decision)
Phase 3: DoCommit (final)
```

3PC is non-blocking but:
- More messages
- Still fails in network partitions
- Rarely used in practice

## Saga Pattern: Alternative to 2PC

Instead of distributed locking, use compensating transactions:

```
Forward transactions:
T1: Reserve flight
T2: Reserve hotel
T3: Charge credit card

If T3 fails:
C2: Cancel hotel (compensating)
C1: Cancel flight (compensating)
```

No distributed locks. Eventually consistent. More complex application logic.

## 2PC vs Saga

| Aspect | 2PC | Saga |
|--------|-----|------|
| Consistency | Strong | Eventual |
| Locking | Yes (blocking) | No |
| Latency | Higher | Lower |
| Complexity | Protocol | Application |
| Failure handling | Coordinator | Compensation |

## The Tradeoffs

| Decision | What We Got | What We Gave Up |
|----------|-------------|-----------------|
| Two phases | Atomicity | Blocking possibility |
| Coordinator | Simple protocol | Single point of failure |
| Locking | Isolation | Performance |
| Synchronous | Consistency | Availability |

## The Principle

> **Two-Phase Commit provides distributed atomicity by separating the vote (can you commit?) from the action (do it). This coordination has a cost: blocking, latency, and coordinator dependency.**

Use 2PC when you absolutely need distributed transactions. Consider sagas when eventual consistency is acceptable.

---

## Summary

- 2PC ensures all-or-nothing across distributed participants
- Phase 1: Voting (can commit?)
- Phase 2: Decision (commit or abort)
- Blocking problem: coordinator crash leaves participants stuck
- 3PC attempts to solve blocking but adds complexity
- Sagas offer non-blocking alternative with compensations

---

*For consensus among replicas, Paxos and Raft provide stronger guarantees.*
