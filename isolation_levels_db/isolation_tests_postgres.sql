-- ============================================
-- PostgreSQL Isolation Level Test Suite
-- ============================================
-- Complete test scenarios for all isolation levels
-- Database: instagram_db
-- Run these tests in TWO separate PostgreSQL sessions

-- ============================================
-- TEST 1: READ UNCOMMITTED - Behaves Like READ COMMITTED
-- ============================================
-- PostgreSQL doesn't support true READ UNCOMMITTED
-- It behaves like READ COMMITTED (no dirty reads)

-- SESSION 1:
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
BEGIN;
SELECT user_id, username FROM users WHERE user_id = 1;
-- WAIT for Session 2 to update (but not commit)
-- Then read again:
SELECT user_id, username FROM users WHERE user_id = 1;  -- Won't see uncommitted change!
COMMIT;

-- SESSION 2:
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
BEGIN;
UPDATE users SET username = 'uncommitted_change' WHERE user_id = 1;
-- DON'T COMMIT YET - let Session 1 read
-- Then rollback:
ROLLBACK;

-- EXPECTED RESULT:
-- Session 1 does NOT see uncommitted changes (PostgreSQL prevents dirty reads)

-- ============================================
-- TEST 2: READ COMMITTED - Non-Repeatable Read
-- ============================================
-- Demonstrates same query returning different results

-- SESSION 1:
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL READ COMMITTED;
BEGIN;
SELECT user_id, username, email FROM users WHERE user_id = 2;
-- Note the values
-- WAIT for Session 2 to update and commit
-- Then read again:
SELECT user_id, username, email FROM users WHERE user_id = 2;  -- Different values!
COMMIT;

-- SESSION 2:
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL READ COMMITTED;
BEGIN;
UPDATE users SET username = 'changed_user', email = 'changed@example.com' WHERE user_id = 2;
COMMIT;  -- Commit immediately

-- EXPECTED RESULT:
-- Session 1's second SELECT returns different values (NON-REPEATABLE READ)

-- ============================================
-- TEST 3: REPEATABLE READ - Consistent Reads
-- ============================================
-- Demonstrates consistent reads within a transaction

-- SESSION 1:
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN;
SELECT user_id, username FROM users WHERE user_id = 3;
-- WAIT for Session 2 to update and commit
-- Then read again:
SELECT user_id, username FROM users WHERE user_id = 3;  -- Same values!
COMMIT;
-- Read after commit:
SELECT user_id, username FROM users WHERE user_id = 3;  -- Now sees new values

-- SESSION 2:
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN;
UPDATE users SET username = 'updated_in_session2' WHERE user_id = 3;
COMMIT;

-- EXPECTED RESULT:
-- Session 1's second SELECT (before commit) returns same values
-- After commit, Session 1 sees the new values

-- ============================================
-- TEST 4: REPEATABLE READ - Phantom Reads Possible
-- ============================================
-- PostgreSQL REPEATABLE READ can have phantom reads (unlike MySQL)

-- SESSION 1:
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN;
SELECT COUNT(*) FROM users WHERE is_verified = TRUE;
SELECT user_id, username FROM users WHERE is_verified = TRUE ORDER BY user_id;
-- WAIT for Session 2 to insert and commit
-- Then count again:
SELECT COUNT(*) FROM users WHERE is_verified = TRUE;  -- Same count!
SELECT user_id, username FROM users WHERE is_verified = TRUE ORDER BY user_id;  -- Same rows!
COMMIT;
-- After commit:
SELECT COUNT(*) FROM users WHERE is_verified = TRUE;  -- Now sees new row

-- SESSION 2:
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN;
INSERT INTO users (username, email, password_hash, is_verified) 
VALUES ('new_verified_user', 'newuser@example.com', '$2b$10$test', TRUE);
COMMIT;

-- EXPECTED RESULT:
-- Session 1 doesn't see the new row (snapshot isolation)
-- But technically phantom reads are possible with certain queries

-- ============================================
-- TEST 5: SERIALIZABLE - Serialization Failure
-- ============================================
-- PostgreSQL SERIALIZABLE uses SSI (Serializable Snapshot Isolation)

-- SESSION 1:
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN;
SELECT * FROM users WHERE user_id = 4;  -- Creates predicate lock
-- WAIT - Session 2 will try to update
SELECT pg_sleep(5);  -- Wait 5 seconds
COMMIT;

-- SESSION 2:
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN;
UPDATE users SET username = 'serializable_update' WHERE user_id = 4;
COMMIT;  -- May get serialization error

-- EXPECTED RESULT:
-- One transaction may fail with: ERROR: could not serialize access

-- ============================================
-- TEST 6: SERIALIZABLE - Write Skew Prevention
-- ============================================
-- Demonstrates how SERIALIZABLE prevents write skew

-- SESSION 1:
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN;
SELECT COUNT(*) FROM users WHERE is_verified = TRUE;  -- Suppose count is 4
-- Business rule: must have at least 3 verified users
-- WAIT for Session 2 to also check
-- Try to unverify a user:
UPDATE users SET is_verified = FALSE WHERE user_id = 1;
COMMIT;

-- SESSION 2:
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN;
SELECT COUNT(*) FROM users WHERE is_verified = TRUE;  -- Also sees 4
-- Business rule: must have at least 3 verified users
-- Try to unverify a different user:
UPDATE users SET is_verified = FALSE WHERE user_id = 2;
COMMIT;  -- Will fail with serialization error

-- EXPECTED RESULT:
-- One session gets: ERROR: could not serialize access due to read/write dependencies

-- ============================================
-- TEST 7: Lost Update Prevention with FOR UPDATE
-- ============================================
-- Demonstrates proper way to prevent lost updates

-- SESSION 1:
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN;
SELECT likes_count FROM post WHERE post_id = 1 FOR UPDATE;  -- Lock the row
-- Increment:
UPDATE post SET likes_count = likes_count + 1 WHERE post_id = 1;
SELECT pg_sleep(3);  -- Simulate processing
COMMIT;

-- SESSION 2:
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN;
SELECT likes_count FROM post WHERE post_id = 1 FOR UPDATE;  -- BLOCKS!
-- Will wait for Session 1
-- Then increment:
UPDATE post SET likes_count = likes_count + 1 WHERE post_id = 1;
COMMIT;

-- EXPECTED RESULT:
-- Both increments are preserved (no lost update)

-- ============================================
-- TEST 8: Concurrent Updates on Related Tables
-- ============================================
-- Demonstrates updating users + user_profile together

-- SESSION 1:
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN;
UPDATE users SET username = 'session1_update' WHERE user_id = 5;
UPDATE user_profile SET full_name = 'Session 1 Name' WHERE user_id = 5;
SELECT pg_sleep(3);
COMMIT;

-- SESSION 2:
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN;
UPDATE users SET username = 'session2_update' WHERE user_id = 5;  -- BLOCKS!
UPDATE user_profile SET full_name = 'Session 2 Name' WHERE user_id = 5;
COMMIT;

-- EXPECTED RESULT:
-- Session 2 blocks until Session 1 commits
-- Last writer wins (Session 2's changes are final)

-- ============================================
-- TEST 9: Deadlock Scenario
-- ============================================
-- Demonstrates how deadlocks can occur

-- SESSION 1:
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN;
UPDATE users SET username = 'lock_user1' WHERE user_id = 1;  -- Lock user 1
SELECT pg_sleep(2);  -- Wait
UPDATE users SET username = 'lock_user2' WHERE user_id = 2;  -- Try to lock user 2
COMMIT;

-- SESSION 2:
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN;
UPDATE users SET username = 'lock_user2_s2' WHERE user_id = 2;  -- Lock user 2
SELECT pg_sleep(2);  -- Wait
UPDATE users SET username = 'lock_user1_s2' WHERE user_id = 1;  -- Try to lock user 1 - DEADLOCK!
COMMIT;

-- EXPECTED RESULT:
-- PostgreSQL detects deadlock and rolls back one transaction
-- ERROR: deadlock detected

-- ============================================
-- TEST 10: FOR UPDATE NOWAIT
-- ============================================
-- PostgreSQL-specific: fail immediately if row is locked

-- SESSION 1:
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN;
SELECT * FROM users WHERE user_id = 4 FOR UPDATE;
SELECT pg_sleep(5);  -- Hold the lock
COMMIT;

-- SESSION 2:
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN;
SELECT * FROM users WHERE user_id = 4 FOR UPDATE NOWAIT;  -- Fails immediately!
COMMIT;

-- EXPECTED RESULT:
-- Session 2 gets: ERROR: could not obtain lock on row

-- ============================================
-- TEST 11: FOR UPDATE SKIP LOCKED
-- ============================================
-- PostgreSQL-specific: skip locked rows

-- SESSION 1:
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN;
SELECT * FROM users WHERE user_id IN (1, 2, 3) FOR UPDATE;  -- Lock users 1,2,3
SELECT pg_sleep(5);
COMMIT;

-- SESSION 2:
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN;
-- Skip locked rows, only get unlocked ones:
SELECT * FROM users WHERE user_id IN (1, 2, 3, 4, 5) FOR UPDATE SKIP LOCKED;
-- Will only return users 4 and 5
COMMIT;

-- EXPECTED RESULT:
-- Session 2 only sees unlocked rows (4 and 5)

-- ============================================
-- TEST 12: Advisory Locks
-- ============================================
-- PostgreSQL-specific: application-level locks

-- SESSION 1:
SELECT pg_advisory_lock(123);  -- Acquire advisory lock
SELECT pg_sleep(5);
SELECT pg_advisory_unlock(123);  -- Release lock

-- SESSION 2:
SELECT pg_advisory_lock(123);  -- BLOCKS until Session 1 releases
SELECT 'Got the lock!';
SELECT pg_advisory_unlock(123);

-- EXPECTED RESULT:
-- Session 2 waits for Session 1 to release the advisory lock

-- ============================================
-- TEST 13: MVCC Demonstration
-- ============================================
-- Shows PostgreSQL's Multi-Version Concurrency Control

-- SESSION 1:
BEGIN;
SELECT xmin, xmax, user_id, username FROM users WHERE user_id = 1;
-- Note the xmin (transaction ID that created this version)
-- WAIT for Session 2
SELECT xmin, xmax, user_id, username FROM users WHERE user_id = 1;
COMMIT;

-- SESSION 2:
BEGIN;
UPDATE users SET username = 'mvcc_test' WHERE user_id = 1;
COMMIT;

-- EXPECTED RESULT:
-- Session 1 sees same xmin (old version) until it commits
-- After commit, new transaction sees new xmin

-- ============================================
-- CLEANUP QUERIES
-- ============================================
-- Reset data after tests

-- Reset users
UPDATE users SET username = 'john_doe', email = 'john@example.com', is_verified = TRUE WHERE user_id = 1;
UPDATE users SET username = 'jane_smith', email = 'jane@example.com', is_verified = TRUE WHERE user_id = 2;
UPDATE users SET username = 'mike_wilson', email = 'mike@example.com', is_verified = TRUE WHERE user_id = 3;
UPDATE users SET username = 'sarah_jones', email = 'sarah@example.com', is_verified = TRUE WHERE user_id = 4;
UPDATE users SET username = 'alex_brown', email = 'alex@example.com', is_verified = FALSE WHERE user_id = 5;

-- Reset profiles
UPDATE user_profile SET full_name = 'John Doe', bio = 'Photography enthusiast 📷 | Travel lover ✈️' WHERE user_id = 1;
UPDATE user_profile SET full_name = 'Jane Smith', bio = 'Fashion blogger 👗 | Style icon' WHERE user_id = 2;
UPDATE user_profile SET full_name = 'Mike Wilson', bio = 'Fitness coach 💪 | Healthy lifestyle' WHERE user_id = 3;
UPDATE user_profile SET full_name = 'Sarah Jones', bio = 'Food blogger 🍕 | Recipe creator' WHERE user_id = 4;
UPDATE user_profile SET full_name = 'Alex Brown', bio = 'Tech enthusiast | Gamer 🎮' WHERE user_id = 5;

-- Delete any test users
DELETE FROM user_profile WHERE user_id > 5;
DELETE FROM users WHERE user_id > 5;

-- Reset isolation level to default
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- ============================================
-- VERIFICATION QUERIES
-- ============================================
-- Check current state

SHOW default_transaction_isolation;
SHOW transaction_isolation;

SELECT u.user_id, u.username, u.email, u.is_verified, p.full_name 
FROM users u 
JOIN user_profile p ON u.user_id = p.user_id 
ORDER BY u.user_id;

-- ============================================
-- 🎓 KEY LEARNINGS - PostgreSQL Specific
-- ============================================
/*
1. READ UNCOMMITTED:
   - PostgreSQL treats it as READ COMMITTED
   - No dirty reads are possible
   - Different from MySQL

2. READ COMMITTED:
   - Default isolation level in PostgreSQL
   - Each statement gets a fresh snapshot
   - Allows non-repeatable reads
   - Good for most applications

3. REPEATABLE READ:
   - Uses MVCC (Multi-Version Concurrency Control)
   - Prevents dirty and non-repeatable reads
   - Phantom reads are prevented via snapshot isolation
   - Different from MySQL's gap locking approach

4. SERIALIZABLE:
   - Uses SSI (Serializable Snapshot Isolation)
   - More strict than MySQL
   - Can throw serialization errors
   - Requires retry logic in application

5. PostgreSQL-Specific Features:
   - FOR UPDATE NOWAIT - fail immediately if locked
   - FOR UPDATE SKIP LOCKED - skip locked rows
   - Advisory locks - application-level locking
   - MVCC - visible via xmin/xmax columns

6. Best Practices:
   - Default READ COMMITTED is good for most cases
   - Use REPEATABLE READ for reports
   - Use SERIALIZABLE sparingly (handle errors)
   - Use FOR UPDATE for critical updates
   - Implement retry logic for serialization errors

7. Error Handling:
   - Handle "could not serialize access" errors
   - Handle "deadlock detected" errors
   - Implement exponential backoff for retries
*/
