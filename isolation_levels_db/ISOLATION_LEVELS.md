# Database Isolation Levels - Interactive Learning Guide

## 📚 What Are Isolation Levels?

Isolation levels define how transactions interact with each other when accessing the same data concurrently. They balance between **data consistency** and **performance**.

## 🎯 The Four Standard Isolation Levels

From least to most strict:

1. **READ UNCOMMITTED** - Can read uncommitted changes from other transactions
2. **READ COMMITTED** - Can only read committed changes
3. **REPEATABLE READ** - Ensures same reads within a transaction
4. **SERIALIZABLE** - Full isolation, transactions appear to run sequentially

## 🐛 Common Concurrency Problems

### 1. Dirty Read
Reading **uncommitted** data from another transaction that might be rolled back.

```
Session 1: UPDATE users SET username='new_name' WHERE user_id=1;
Session 2: SELECT username FROM users WHERE user_id=1;  -- Sees 'new_name'
Session 1: ROLLBACK;  -- Oops! Session 2 read data that never existed
```

### 2. Non-Repeatable Read
Reading the **same row twice** in a transaction and getting **different values**.

```
Session 1: SELECT username FROM users WHERE user_id=1;  -- Returns 'john_doe'
Session 2: UPDATE users SET username='jane_doe' WHERE user_id=1; COMMIT;
Session 1: SELECT username FROM users WHERE user_id=1;  -- Returns 'jane_doe' (changed!)
```

### 3. Phantom Read
Reading a **set of rows** twice and getting **different number of rows**.

```
Session 1: SELECT COUNT(*) FROM users WHERE is_verified=TRUE;  -- Returns 5
Session 2: INSERT INTO users (username, is_verified) VALUES ('new_user', TRUE); COMMIT;
Session 1: SELECT COUNT(*) FROM users WHERE is_verified=TRUE;  -- Returns 6 (phantom!)
```

### 4. Lost Update
Two transactions update the same data, and one update is **lost**.

```
Session 1: SELECT likes_count FROM post WHERE post_id=1;  -- Returns 100
Session 2: SELECT likes_count FROM post WHERE post_id=1;  -- Returns 100
Session 1: UPDATE post SET likes_count=101 WHERE post_id=1; COMMIT;
Session 2: UPDATE post SET likes_count=101 WHERE post_id=1; COMMIT;  -- Lost Session 1's update!
```

## 📊 Isolation Levels Comparison

| Isolation Level | Dirty Read | Non-Repeatable Read | Phantom Read | Performance |
|----------------|------------|---------------------|--------------|-------------|
| READ UNCOMMITTED | ✅ Possible | ✅ Possible | ✅ Possible | ⚡️ Fastest |
| READ COMMITTED | ❌ Prevented | ✅ Possible | ✅ Possible | ⚡️⚡️ Fast |
| REPEATABLE READ | ❌ Prevented | ❌ Prevented | ✅ Possible* | ⚡️⚡️⚡️ Slower |
| SERIALIZABLE | ❌ Prevented | ❌ Prevented | ❌ Prevented | ⚡️⚡️⚡️⚡️ Slowest |

*Note: MySQL's InnoDB prevents phantom reads even at REPEATABLE READ level using gap locks.

## 🔍 Detailed Isolation Level Behavior

### READ UNCOMMITTED
- **Lowest isolation**, highest performance
- Can read uncommitted changes from other transactions
- **Use case**: Approximate statistics where accuracy isn't critical
- **Risk**: Dirty reads can lead to incorrect business logic

### READ COMMITTED
- **Default in PostgreSQL** and Oracle
- Only sees committed changes
- Each SELECT gets a fresh snapshot
- **Use case**: Most general-purpose applications
- **Risk**: Non-repeatable reads within a transaction

### REPEATABLE READ
- **Default in MySQL** (InnoDB)
- Ensures same row reads return same values
- Uses snapshot isolation
- **Use case**: Financial calculations, reports requiring consistency
- **Risk**: Phantom reads (except in MySQL InnoDB)

### SERIALIZABLE
- **Strictest isolation**
- Transactions appear to execute sequentially
- Uses range locks to prevent phantoms
- **Use case**: Critical financial transactions, inventory management
- **Risk**: High lock contention, potential deadlocks

## 🔄 MySQL vs PostgreSQL Differences

### MySQL (InnoDB)
```sql
-- Default: REPEATABLE READ
SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE;
```

**Key behaviors:**
- REPEATABLE READ uses **gap locks** (prevents phantom reads)
- Less strict SERIALIZABLE than PostgreSQL
- Better performance for read-heavy workloads

### PostgreSQL
```sql
-- Default: READ COMMITTED
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL READ COMMITTED;
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL SERIALIZABLE;
```

**Key behaviors:**
- READ UNCOMMITTED behaves like READ COMMITTED (no dirty reads)
- REPEATABLE READ uses **MVCC** (phantom reads possible)
- SERIALIZABLE uses **SSI** (Serializable Snapshot Isolation)
- More aggressive deadlock detection

## 🧪 Testing Setup

### Prerequisites
1. Have MySQL or PostgreSQL running
2. Load the schema: `mysql_schema.sql` or `postgres_schema.sql`
3. Load seed data: `mysql_seed_data.sql` or `postgres_seed_data.sql`
4. Open **two terminal windows** for concurrent sessions

### Running Tests

**Terminal 1 (Session 1):**
```bash
mysql -u root -p instagram_db
# or
psql -U postgres -d instagram_db
```

**Terminal 2 (Session 2):**
```bash
mysql -u root -p instagram_db
# or
psql -U postgres -d instagram_db
```

Follow the step-by-step instructions in:
- `demo_session1.sql` (run in Terminal 1)
- `demo_session2.sql` (run in Terminal 2)

## 📝 Test Scenarios Included

### Scenario 1: Dirty Read Test
- Demonstrates READ UNCOMMITTED allowing dirty reads
- Shows how uncommitted changes are visible

### Scenario 2: Non-Repeatable Read Test
- Demonstrates READ COMMITTED allowing non-repeatable reads
- Shows how committed changes affect ongoing transactions

### Scenario 3: Phantom Read Test
- Demonstrates phantom reads at different isolation levels
- Shows how new rows appear in range queries

### Scenario 4: Lost Update Prevention
- Demonstrates how SERIALIZABLE prevents lost updates
- Shows lock conflicts and proper error handling

### Scenario 5: Related Tables (users + user_profile)
- Tests concurrent updates on related tables
- Demonstrates foreign key constraints with isolation levels
- Shows how transactions affect 1:1 relationships

## 💡 Best Practices

### When to Use Each Level

**READ UNCOMMITTED:**
- Dashboard statistics
- Approximate counts
- Non-critical analytics

**READ COMMITTED:**
- Web applications
- CRUD operations
- Most business logic

**REPEATABLE READ:**
- Financial reports
- Batch processing
- Data consistency requirements

**SERIALIZABLE:**
- Money transfers
- Inventory updates
- Critical business transactions

### General Guidelines

1. **Start with READ COMMITTED** - Good balance for most apps
2. **Use REPEATABLE READ** for reports requiring consistency
3. **Use SERIALIZABLE** sparingly - only for critical operations
4. **Handle deadlocks** - Implement retry logic
5. **Keep transactions short** - Reduces lock contention
6. **Test your isolation level** - Understand the trade-offs

## 🚨 Common Pitfalls

### 1. Over-using SERIALIZABLE
```sql
-- ❌ Bad: Everything is serializable
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT * FROM users;  -- Doesn't need this level!
```

### 2. Ignoring Deadlocks
```sql
-- ❌ Bad: No error handling
BEGIN;
UPDATE users SET username='new' WHERE user_id=1;
-- Deadlock occurs, transaction fails
```

```sql
-- ✅ Good: Handle deadlocks
BEGIN;
UPDATE users SET username='new' WHERE user_id=1;
-- If deadlock: ROLLBACK and retry
```

### 3. Long-Running Transactions
```sql
-- ❌ Bad: Holding locks too long
BEGIN;
UPDATE users SET is_verified=TRUE WHERE user_id=1;
-- ... lots of business logic ...
-- ... external API calls ...
COMMIT;  -- Locks held for too long!
```

## 🎓 Learning Path

1. **Read this guide** - Understand the concepts
2. **Run Scenario 1** - See dirty reads in action
3. **Run Scenario 2** - Experience non-repeatable reads
4. **Run Scenario 3** - Observe phantom reads
5. **Run Scenario 4** - Handle serialization conflicts
6. **Run Scenario 5** - Test with related tables (users + user_profile)
7. **Experiment** - Try your own scenarios!

## 📚 Additional Resources

- [PostgreSQL Isolation Levels](https://www.postgresql.org/docs/current/transaction-iso.html)
- [MySQL InnoDB Locking](https://dev.mysql.com/doc/refman/8.0/en/innodb-locking.html)
- [ANSI SQL Isolation Levels](https://en.wikipedia.org/wiki/Isolation_(database_systems))

## 🔗 Files in This Tutorial

- `ISOLATION_LEVELS.md` (this file) - Educational guide
- `demo_session1.sql` - Commands for Session 1
- `demo_session2.sql` - Commands for Session 2
- `isolation_tests_mysql.sql` - Complete MySQL test suite
- `isolation_tests_postgres.sql` - Complete PostgreSQL test suite
