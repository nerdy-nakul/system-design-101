-- ============================================
-- MySQL Isolation Level Test Suite
-- ============================================
-- Complete test scenarios for all isolation levels
-- Database: instagram_db
-- Run these tests in TWO separate MySQL sessions

-- ============================================
-- TEST 1: READ UNCOMMITTED - Dirty Read
-- ============================================
-- Demonstrates reading uncommitted data

-- SESSION 1:
SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
START TRANSACTION;
SELECT user_id, username FROM users WHERE user_id = 1;
-- WAIT for Session 2 to update
-- Then read again:
SELECT user_id, username FROM users WHERE user_id = 1;  -- Will see uncommitted change
COMMIT;

-- SESSION 2:
SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
START TRANSACTION;
UPDATE users SET username = 'uncommitted_change' WHERE user_id = 1;
-- DON'T COMMIT YET - let Session 1 read
-- Then rollback:
ROLLBACK;

-- EXPECTED RESULT:
-- Session 1 sees 'uncommitted_change' even though it was never committed (DIRTY READ)

-- ============================================
-- TEST 2: READ COMMITTED - Non-Repeatable Read
-- ============================================
-- Demonstrates same query returning different results

-- SESSION 1:
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
START TRANSACTION;
SELECT user_id, username, email FROM users WHERE user_id = 2;
-- Note the values
-- WAIT for Session 2 to update and commit
-- Then read again:
SELECT user_id, username, email FROM users WHERE user_id = 2;  -- Different values!
COMMIT;

-- SESSION 2:
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
START TRANSACTION;
UPDATE users SET username = 'changed_user', email = 'changed@example.com' WHERE user_id = 2;
COMMIT;  -- Commit immediately

-- EXPECTED RESULT:
-- Session 1's second SELECT returns different values (NON-REPEATABLE READ)

-- ============================================
-- TEST 3: REPEATABLE READ - Consistent Reads
-- ============================================
-- Demonstrates consistent reads within a transaction

-- SESSION 1:
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
START TRANSACTION;
SELECT user_id, username FROM users WHERE user_id = 3;
-- WAIT for Session 2 to update and commit
-- Then read again:
SELECT user_id, username FROM users WHERE user_id = 3;  -- Same values!
COMMIT;
-- Read after commit:
SELECT user_id, username FROM users WHERE user_id = 3;  -- Now sees new values

-- SESSION 2:
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
START TRANSACTION;
UPDATE users SET username = 'updated_in_session2' WHERE user_id = 3;
COMMIT;

-- EXPECTED RESULT:
-- Session 1's second SELECT (before commit) returns same values
-- After commit, Session 1 sees the new values

-- ============================================
-- TEST 4: REPEATABLE READ - Phantom Read Prevention
-- ============================================
-- MySQL InnoDB prevents phantom reads with gap locks

-- SESSION 1:
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
START TRANSACTION;
SELECT COUNT(*) FROM users WHERE is_verified = TRUE;
SELECT user_id, username FROM users WHERE is_verified = TRUE;
-- WAIT for Session 2 to insert and commit
-- Then count again:
SELECT COUNT(*) FROM users WHERE is_verified = TRUE;  -- Same count!
SELECT user_id, username FROM users WHERE is_verified = TRUE;  -- Same rows!
COMMIT;
-- After commit:
SELECT COUNT(*) FROM users WHERE is_verified = TRUE;  -- Now sees new row

-- SESSION 2:
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
START TRANSACTION;
INSERT INTO users (username, email, password_hash, is_verified) 
VALUES ('new_verified_user', 'newuser@example.com', '$2b$10$test', TRUE);
COMMIT;

-- EXPECTED RESULT:
-- Session 1 doesn't see the new row until after commit (NO PHANTOM READ in MySQL)

-- ============================================
-- TEST 5: SERIALIZABLE - Lock Conflicts
-- ============================================
-- Demonstrates blocking behavior

-- SESSION 1:
SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE;
START TRANSACTION;
SELECT * FROM users WHERE user_id = 4;  -- Acquires shared lock
-- WAIT - Session 2 will block on UPDATE
SELECT SLEEP(5);  -- Wait 5 seconds
COMMIT;  -- Release locks

-- SESSION 2:
SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE;
START TRANSACTION;
UPDATE users SET username = 'blocked_update' WHERE user_id = 4;  -- BLOCKS!
-- Will wait for Session 1 to commit
COMMIT;

-- EXPECTED RESULT:
-- Session 2's UPDATE blocks until Session 1 commits

-- ============================================
-- TEST 6: SERIALIZABLE - Write Skew Prevention
-- ============================================
-- Demonstrates how SERIALIZABLE prevents write skew

-- SESSION 1:
SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE;
START TRANSACTION;
SELECT COUNT(*) FROM users WHERE is_verified = TRUE;  -- Suppose count is 4
-- Business rule: must have at least 3 verified users
-- WAIT for Session 2 to also check
-- Try to unverify a user:
UPDATE users SET is_verified = FALSE WHERE user_id = 1;
COMMIT;

-- SESSION 2:
SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE;
START TRANSACTION;
SELECT COUNT(*) FROM users WHERE is_verified = TRUE;  -- Also sees 4
-- Business rule: must have at least 3 verified users
-- Try to unverify a different user:
UPDATE users SET is_verified = FALSE WHERE user_id = 2;  -- May fail or block
COMMIT;

-- EXPECTED RESULT:
-- One session may get a serialization error to prevent both updates

-- ============================================
-- TEST 7: Lost Update Prevention with SELECT FOR UPDATE
-- ============================================
-- Demonstrates proper way to prevent lost updates

-- SESSION 1:
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
START TRANSACTION;
SELECT likes_count FROM post WHERE post_id = 1 FOR UPDATE;  -- Lock the row
-- Increment:
UPDATE post SET likes_count = likes_count + 1 WHERE post_id = 1;
SELECT SLEEP(3);  -- Simulate processing
COMMIT;

-- SESSION 2:
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
START TRANSACTION;
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
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
START TRANSACTION;
UPDATE users SET username = 'session1_update' WHERE user_id = 5;
UPDATE user_profile SET full_name = 'Session 1 Name' WHERE user_id = 5;
SELECT SLEEP(3);
COMMIT;

-- SESSION 2:
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
START TRANSACTION;
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
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
START TRANSACTION;
UPDATE users SET username = 'lock_user1' WHERE user_id = 1;  -- Lock user 1
SELECT SLEEP(2);  -- Wait
UPDATE users SET username = 'lock_user2' WHERE user_id = 2;  -- Try to lock user 2
COMMIT;

-- SESSION 2:
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
START TRANSACTION;
UPDATE users SET username = 'lock_user2_s2' WHERE user_id = 2;  -- Lock user 2
SELECT SLEEP(2);  -- Wait
UPDATE users SET username = 'lock_user1_s2' WHERE user_id = 1;  -- Try to lock user 1 - DEADLOCK!
COMMIT;

-- EXPECTED RESULT:
-- MySQL detects deadlock and rolls back one transaction
-- Error: Deadlock found when trying to get lock; try restarting transaction

-- ============================================
-- TEST 10: Foreign Key Constraints with Transactions
-- ============================================
-- Demonstrates how foreign keys behave with isolation levels

-- SESSION 1:
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
START TRANSACTION;
DELETE FROM user_profile WHERE user_id = 5;  -- Delete profile first
SELECT SLEEP(3);
DELETE FROM users WHERE user_id = 5;  -- Then delete user
COMMIT;

-- SESSION 2:
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
START TRANSACTION;
SELECT * FROM user_profile WHERE user_id = 5;  -- May or may not see it
SELECT * FROM users WHERE user_id = 5;
COMMIT;

-- EXPECTED RESULT:
-- Session 2 sees consistent state (both exist or both don't)
-- Foreign key constraints are maintained

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

-- Reset isolation level
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;

-- ============================================
-- VERIFICATION QUERIES
-- ============================================
-- Check current state

SELECT @@transaction_isolation AS current_isolation_level;
SELECT @@autocommit AS autocommit_status;

SELECT u.user_id, u.username, u.email, u.is_verified, p.full_name 
FROM users u 
JOIN user_profile p ON u.user_id = p.user_id 
ORDER BY u.user_id;

-- ============================================
-- 🎓 KEY LEARNINGS
-- ============================================
/*
1. READ UNCOMMITTED:
   - Allows dirty reads
   - Fastest but least safe
   - Use only for approximate statistics

2. READ COMMITTED:
   - Default in PostgreSQL
   - Prevents dirty reads
   - Allows non-repeatable reads
   - Good for most applications

3. REPEATABLE READ:
   - Default in MySQL
   - Prevents dirty and non-repeatable reads
   - MySQL InnoDB also prevents phantom reads (gap locks)
   - Good for reports and batch processing

4. SERIALIZABLE:
   - Strictest isolation
   - Prevents all anomalies
   - Can cause blocking and deadlocks
   - Use for critical operations only

5. Best Practices:
   - Use SELECT FOR UPDATE for counters
   - Keep transactions short
   - Handle deadlocks with retry logic
   - Update related tables in same transaction
   - Choose appropriate isolation level for each operation
*/
