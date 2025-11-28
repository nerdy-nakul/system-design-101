-- ============================================
-- QUICK REFERENCE: Isolation Levels Cheat Sheet
-- ============================================

-- ============================================
-- SETTING ISOLATION LEVELS
-- ============================================

-- MySQL:
SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;  -- Default
SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE;

-- PostgreSQL:
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL READ COMMITTED;  -- Default
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL SERIALIZABLE;

-- Check current level:
-- MySQL:
SELECT @@transaction_isolation;

-- PostgreSQL:
SHOW transaction_isolation;

-- ============================================
-- TRANSACTION COMMANDS
-- ============================================

-- MySQL:
START TRANSACTION;
-- or
BEGIN;
COMMIT;
ROLLBACK;

-- PostgreSQL:
BEGIN;
COMMIT;
ROLLBACK;

-- ============================================
-- LOCKING HINTS
-- ============================================

-- Lock row for update (both MySQL and PostgreSQL):
SELECT * FROM users WHERE user_id = 1 FOR UPDATE;

-- PostgreSQL-specific:
SELECT * FROM users WHERE user_id = 1 FOR UPDATE NOWAIT;  -- Fail if locked
SELECT * FROM users WHERE user_id = 1 FOR UPDATE SKIP LOCKED;  -- Skip locked rows
SELECT * FROM users WHERE user_id = 1 FOR SHARE;  -- Shared lock (allow other reads)

-- ============================================
-- COMMON PATTERNS
-- ============================================

-- Pattern 1: Safe Counter Increment
BEGIN;
SELECT likes_count FROM post WHERE post_id = 1 FOR UPDATE;
UPDATE post SET likes_count = likes_count + 1 WHERE post_id = 1;
COMMIT;

-- Pattern 2: Update Related Tables
BEGIN;
UPDATE users SET username = 'new_name' WHERE user_id = 1;
UPDATE user_profile SET full_name = 'New Name' WHERE user_id = 1;
COMMIT;

-- Pattern 3: Conditional Update
BEGIN;
SELECT is_verified FROM users WHERE user_id = 1 FOR UPDATE;
-- Check condition in application
UPDATE users SET is_verified = TRUE WHERE user_id = 1;
COMMIT;

-- Pattern 4: Batch Processing (REPEATABLE READ)
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN;
-- Process multiple rows with consistent snapshot
SELECT * FROM users WHERE is_verified = FALSE;
-- ... process ...
UPDATE users SET is_verified = TRUE WHERE user_id IN (...);
COMMIT;

-- ============================================
-- ISOLATION LEVEL QUICK COMPARISON
-- ============================================

/*
┌─────────────────┬─────────────┬────────────────────┬──────────────┬─────────────┐
│ Isolation Level │ Dirty Read  │ Non-Repeatable Read│ Phantom Read │ Performance │
├─────────────────┼─────────────┼────────────────────┼──────────────┼─────────────┤
│ READ UNCOMMITTED│ ✅ Possible │ ✅ Possible        │ ✅ Possible  │ ⚡️ Fastest  │
│ READ COMMITTED  │ ❌ Prevented│ ✅ Possible        │ ✅ Possible  │ ⚡️⚡️ Fast   │
│ REPEATABLE READ │ ❌ Prevented│ ❌ Prevented       │ ⚠️ Varies*   │ ⚡️⚡️⚡️ Slow │
│ SERIALIZABLE    │ ❌ Prevented│ ❌ Prevented       │ ❌ Prevented │ ⚡️⚡️⚡️⚡️ Slowest│
└─────────────────┴─────────────┴────────────────────┴──────────────┴─────────────┘

* MySQL InnoDB: Prevented (gap locks)
* PostgreSQL: Prevented (snapshot isolation)
*/

-- ============================================
-- WHEN TO USE EACH LEVEL
-- ============================================

/*
READ UNCOMMITTED:
  ✓ Dashboard statistics
  ✓ Approximate counts
  ✗ Business logic
  ✗ Financial data

READ COMMITTED:
  ✓ Web applications
  ✓ CRUD operations
  ✓ Most business logic
  ✗ Reports requiring consistency

REPEATABLE READ:
  ✓ Financial reports
  ✓ Batch processing
  ✓ Data exports
  ✗ High-concurrency writes

SERIALIZABLE:
  ✓ Money transfers
  ✓ Inventory updates
  ✓ Critical transactions
  ✗ High-throughput systems
*/

-- ============================================
-- ERROR HANDLING
-- ============================================

-- MySQL Deadlock:
/*
ERROR 1213 (40001): Deadlock found when trying to get lock; 
try restarting transaction
*/

-- PostgreSQL Serialization Error:
/*
ERROR: could not serialize access due to concurrent update
ERROR: could not serialize access due to read/write dependencies among transactions
*/

-- Application Retry Logic (Pseudocode):
/*
max_retries = 3
for attempt in 1..max_retries:
    try:
        BEGIN
        -- your transaction
        COMMIT
        break
    catch DeadlockError or SerializationError:
        ROLLBACK
        if attempt < max_retries:
            sleep(random(0.1, 0.5) * attempt)  # Exponential backoff
            continue
        else:
            raise
*/

-- ============================================
-- DEBUGGING QUERIES
-- ============================================

-- MySQL: Show running transactions
SELECT * FROM information_schema.innodb_trx;

-- MySQL: Show locks
SELECT * FROM performance_schema.data_locks;

-- MySQL: Show lock waits
SELECT * FROM performance_schema.data_lock_waits;

-- PostgreSQL: Show running transactions
SELECT * FROM pg_stat_activity WHERE state = 'active';

-- PostgreSQL: Show locks
SELECT * FROM pg_locks;

-- PostgreSQL: Show blocking queries
SELECT 
    blocked_locks.pid AS blocked_pid,
    blocked_activity.usename AS blocked_user,
    blocking_locks.pid AS blocking_pid,
    blocking_activity.usename AS blocking_user,
    blocked_activity.query AS blocked_statement,
    blocking_activity.query AS blocking_statement
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks 
    ON blocking_locks.locktype = blocked_locks.locktype
    AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
    AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
    AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
    AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
    AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
    AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
    AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
    AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
    AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
    AND blocking_locks.pid != blocked_locks.pid
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;

-- ============================================
-- TESTING SETUP
-- ============================================

-- Open two terminal windows:

-- Terminal 1:
-- mysql -u root -p instagram_db
-- or
-- psql -U postgres -d instagram_db

-- Terminal 2:
-- mysql -u root -p instagram_db
-- or
-- psql -U postgres -d instagram_db

-- Then run:
-- Terminal 1: demo_session1.sql
-- Terminal 2: demo_session2.sql

-- ============================================
-- KEY TAKEAWAYS
-- ============================================

/*
1. Default Levels:
   - MySQL: REPEATABLE READ
   - PostgreSQL: READ COMMITTED

2. Most Common Choice:
   - READ COMMITTED for web apps
   - REPEATABLE READ for reports
   - SERIALIZABLE for critical ops

3. Always Use FOR UPDATE:
   - When incrementing counters
   - When updating based on current value
   - When enforcing business rules

4. Keep Transactions Short:
   - Acquire locks late
   - Release locks early
   - Avoid external calls in transactions

5. Handle Errors:
   - Implement retry logic
   - Use exponential backoff
   - Log serialization failures

6. Test Your Assumptions:
   - Run the demo scripts
   - Understand your database's behavior
   - Measure performance impact
*/
