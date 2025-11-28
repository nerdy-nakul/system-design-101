-- ============================================
-- SESSION 1 - Interactive Isolation Level Demo
-- ============================================
-- Run this in your FIRST terminal window
-- Follow the steps in order, waiting for Session 2 when indicated
-- Database: instagram_db

-- ============================================
-- SETUP: Verify you're in the right database
-- ============================================
SELECT DATABASE();  -- Should show 'instagram_db'
SELECT @@transaction_isolation;  -- Check current isolation level

-- ============================================
-- SCENARIO 1: DIRTY READ (READ UNCOMMITTED)
-- ============================================
-- This demonstrates how READ UNCOMMITTED can see uncommitted changes

-- Step 1.1: Set isolation level to READ UNCOMMITTED
SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

-- Step 1.2: Start a transaction
START TRANSACTION;

-- Step 1.3: Read user data (before Session 2 makes changes)
SELECT user_id, username, email FROM users WHERE user_id = 1;
SELECT user_id, full_name, bio FROM user_profile WHERE user_id = 1;

-- ⏸️  WAIT: Let Session 2 run Steps 1.1-1.3 (update but NOT commit)

-- Step 1.4: Read again - you'll see UNCOMMITTED changes from Session 2!
SELECT user_id, username, email FROM users WHERE user_id = 1;
SELECT user_id, full_name, bio FROM user_profile WHERE user_id = 1;
-- 🔍 Notice: You can see Session 2's uncommitted changes (DIRTY READ)

-- Step 1.5: Commit your transaction
COMMIT;

-- ⏸️  WAIT: Let Session 2 rollback (Step 1.4)

-- Step 1.6: Read again - the dirty data is gone!
SELECT user_id, username, email FROM users WHERE user_id = 1;
SELECT user_id, full_name, bio FROM user_profile WHERE user_id = 1;
-- 🔍 Notice: Data reverted because Session 2 rolled back

-- ============================================
-- SCENARIO 2: NON-REPEATABLE READ (READ COMMITTED)
-- ============================================
-- This demonstrates how READ COMMITTED allows data to change mid-transaction

-- Step 2.1: Set isolation level to READ COMMITTED
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- Step 2.2: Start a transaction
START TRANSACTION;

-- Step 2.3: First read
SELECT user_id, username, email FROM users WHERE user_id = 2;
SELECT user_id, full_name, bio FROM user_profile WHERE user_id = 2;
-- 📝 Note the values

-- ⏸️  WAIT: Let Session 2 run Steps 2.1-2.3 (update and COMMIT)

-- Step 2.4: Read the same data again
SELECT user_id, username, email FROM users WHERE user_id = 2;
SELECT user_id, full_name, bio FROM user_profile WHERE user_id = 2;
-- 🔍 Notice: Different values! (NON-REPEATABLE READ)

-- Step 2.5: Commit
COMMIT;

-- ============================================
-- SCENARIO 3: PHANTOM READ (REPEATABLE READ)
-- ============================================
-- This demonstrates phantom reads with new rows appearing

-- Step 3.1: Set isolation level to REPEATABLE READ
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;

-- Step 3.2: Start a transaction
START TRANSACTION;

-- Step 3.3: Count verified users
SELECT COUNT(*) as verified_count FROM users WHERE is_verified = TRUE;
-- 📝 Note the count

-- Step 3.4: List verified users
SELECT user_id, username, is_verified FROM users WHERE is_verified = TRUE ORDER BY user_id;

-- ⏸️  WAIT: Let Session 2 run Steps 3.1-3.3 (insert new verified user and COMMIT)

-- Step 3.5: Count again
SELECT COUNT(*) as verified_count FROM users WHERE is_verified = TRUE;
-- 🔍 MySQL InnoDB: Same count (no phantom read due to gap locks)
-- 🔍 PostgreSQL: Same count (snapshot isolation)

-- Step 3.6: List again
SELECT user_id, username, is_verified FROM users WHERE is_verified = TRUE ORDER BY user_id;
-- 🔍 Notice: In MySQL REPEATABLE READ, you won't see the new row

-- Step 3.7: Commit
COMMIT;

-- Step 3.8: Now read outside transaction
SELECT COUNT(*) as verified_count FROM users WHERE is_verified = TRUE;
SELECT user_id, username, is_verified FROM users WHERE is_verified = TRUE ORDER BY user_id;
-- 🔍 Notice: Now you see the new user!

-- ============================================
-- SCENARIO 4: SERIALIZABLE - Lock Conflicts
-- ============================================
-- This demonstrates how SERIALIZABLE prevents concurrent modifications

-- Step 4.1: Set isolation level to SERIALIZABLE
SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE;

-- Step 4.2: Start a transaction
START TRANSACTION;

-- Step 4.3: Read user data (this acquires locks)
SELECT user_id, username FROM users WHERE user_id = 3;
SELECT user_id, full_name FROM user_profile WHERE user_id = 3;

-- ⏸️  WAIT: Let Session 2 try to update (Step 4.1-4.3)
-- Session 2 will BLOCK waiting for your locks!

-- Step 4.4: Wait a few seconds, then commit
SELECT SLEEP(5);  -- Wait 5 seconds
COMMIT;
-- 🔍 Notice: Session 2's update will now proceed

-- ============================================
-- SCENARIO 5: CONCURRENT UPDATES ON RELATED TABLES
-- ============================================
-- This demonstrates updating users + user_profile together

-- Step 5.1: Set isolation level to REPEATABLE READ
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;

-- Step 5.2: Start a transaction
START TRANSACTION;

-- Step 5.3: Update user and profile together
UPDATE users SET username = 'session1_user' WHERE user_id = 4;
UPDATE user_profile SET full_name = 'Session 1 Updated', bio = 'Updated by Session 1' WHERE user_id = 4;

-- Step 5.4: Verify your changes (not committed yet)
SELECT u.user_id, u.username, p.full_name, p.bio 
FROM users u 
JOIN user_profile p ON u.user_id = p.user_id 
WHERE u.user_id = 4;

-- ⏸️  WAIT: Let Session 2 try to update the same user (Steps 5.1-5.3)
-- Session 2 will BLOCK waiting for your locks!

-- Step 5.5: Commit your changes
COMMIT;
-- 🔍 Notice: Session 2 can now proceed

-- Step 5.6: Check final state
SELECT u.user_id, u.username, p.full_name, p.bio 
FROM users u 
JOIN user_profile p ON u.user_id = p.user_id 
WHERE u.user_id = 4;

-- ============================================
-- SCENARIO 6: LOST UPDATE PREVENTION
-- ============================================
-- This demonstrates how to prevent lost updates

-- Step 6.1: Set isolation level to REPEATABLE READ
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;

-- Step 6.2: Start a transaction
START TRANSACTION;

-- Step 6.3: Read current likes count
SELECT post_id, likes_count FROM post WHERE post_id = 1;
-- 📝 Note the likes_count

-- ⏸️  WAIT: Let Session 2 also read the likes_count (Steps 6.1-6.3)

-- Step 6.4: Increment likes (using SELECT FOR UPDATE to lock the row)
SELECT post_id, likes_count FROM post WHERE post_id = 1 FOR UPDATE;

-- Step 6.5: Update based on locked value
UPDATE post SET likes_count = likes_count + 1 WHERE post_id = 1;

-- Step 6.6: Verify
SELECT post_id, likes_count FROM post WHERE post_id = 1;

-- Step 6.7: Commit
COMMIT;

-- ⏸️  WAIT: Let Session 2 complete its update

-- Step 6.8: Check final count
SELECT post_id, likes_count FROM post WHERE post_id = 1;
-- 🔍 Notice: Both increments are preserved (no lost update)

-- ============================================
-- CLEANUP & RESET
-- ============================================
-- Reset to default isolation level
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;

-- Verify no active transactions
SELECT @@transaction_isolation;

-- ============================================
-- 🎓 LEARNING SUMMARY
-- ============================================
/*
What you learned:

1. READ UNCOMMITTED:
   - Can see uncommitted changes (dirty reads)
   - Dangerous for business logic
   - Only use for approximate statistics

2. READ COMMITTED:
   - Only sees committed data
   - Same query can return different results (non-repeatable reads)
   - Good for most web applications

3. REPEATABLE READ:
   - Same query returns same results within transaction
   - MySQL InnoDB prevents phantom reads with gap locks
   - Good for reports and batch processing

4. SERIALIZABLE:
   - Strictest isolation
   - Prevents all concurrency issues
   - Can cause blocking and deadlocks
   - Use only for critical operations

5. Related Tables (users + user_profile):
   - Updates to related tables should be in same transaction
   - Foreign key constraints are enforced
   - Locks are acquired on both tables

6. Lost Update Prevention:
   - Use SELECT FOR UPDATE to lock rows
   - Prevents concurrent modifications
   - Essential for increment operations
*/

-- ============================================
-- 🧪 EXPERIMENT IDEAS
-- ============================================
/*
Try these on your own:

1. What happens if you update user_profile without updating users?
2. Can you create a deadlock by updating in different orders?
3. How does DELETE behave at different isolation levels?
4. What happens with INSERT and SERIALIZABLE?
5. Test with more than 2 concurrent sessions
*/
