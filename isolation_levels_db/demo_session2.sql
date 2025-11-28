-- ============================================
-- SESSION 2 - Interactive Isolation Level Demo
-- ============================================
-- Run this in your SECOND terminal window
-- Follow the steps in order, coordinating with Session 1
-- Database: instagram_db

-- ============================================
-- SETUP: Verify you're in the right database
-- ============================================
SELECT DATABASE();  -- Should show 'instagram_db'
SELECT @@transaction_isolation;  -- Check current isolation level

-- ============================================
-- SCENARIO 1: DIRTY READ (READ UNCOMMITTED)
-- ============================================
-- You will make changes but NOT commit, so Session 1 can see dirty data

-- ⏸️  WAIT: Let Session 1 run Steps 1.1-1.3 first

-- Step 1.1: Set isolation level to READ UNCOMMITTED
SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

-- Step 1.2: Start a transaction
START TRANSACTION;

-- Step 1.3: Update user data (but DON'T commit yet)
UPDATE users SET username = 'dirty_read_test', email = 'dirty@example.com' WHERE user_id = 1;
UPDATE user_profile SET full_name = 'Dirty Read User', bio = 'This is uncommitted data!' WHERE user_id = 1;

-- ⏸️  SIGNAL: Tell Session 1 to run Step 1.4 (they will see your uncommitted changes)

-- Step 1.4: Rollback (simulate a failed transaction)
ROLLBACK;
-- 🔍 Notice: Your changes are undone, but Session 1 saw them (dirty read)

-- ⏸️  SIGNAL: Tell Session 1 to run Step 1.6

-- ============================================
-- SCENARIO 2: NON-REPEATABLE READ (READ COMMITTED)
-- ============================================
-- You will commit changes while Session 1 is in a transaction

-- ⏸️  WAIT: Let Session 1 run Steps 2.1-2.3 first

-- Step 2.1: Set isolation level to READ COMMITTED
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- Step 2.2: Start a transaction
START TRANSACTION;

-- Step 2.3: Update and COMMIT (while Session 1 is still in their transaction)
UPDATE users SET username = 'non_repeatable_test', email = 'nonrepeat@example.com' WHERE user_id = 2;
UPDATE user_profile SET full_name = 'Non-Repeatable User', bio = 'Data changed mid-transaction!' WHERE user_id = 2;
COMMIT;
-- 🔍 Notice: You committed, so Session 1 will see new data on their next read

-- ⏸️  SIGNAL: Tell Session 1 to run Step 2.4

-- ============================================
-- SCENARIO 3: PHANTOM READ (REPEATABLE READ)
-- ============================================
-- You will insert a new row while Session 1 is counting

-- ⏸️  WAIT: Let Session 1 run Steps 3.1-3.4 first

-- Step 3.1: Set isolation level to REPEATABLE READ
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;

-- Step 3.2: Start a transaction
START TRANSACTION;

-- Step 3.3: Insert a new verified user (while Session 1 is in their transaction)
INSERT INTO users (username, email, password_hash, is_verified) 
VALUES ('phantom_user', 'phantom@example.com', '$2b$10$phantom123456', TRUE);

-- Get the new user_id
SET @new_user_id = LAST_INSERT_ID();

-- Insert profile for the new user
INSERT INTO user_profile (user_id, full_name, bio) 
VALUES (@new_user_id, 'Phantom User', 'I am a phantom read!');

COMMIT;
-- 🔍 Notice: You added a new row, but Session 1 won't see it (in MySQL REPEATABLE READ)

-- ⏸️  SIGNAL: Tell Session 1 to run Steps 3.5-3.8

-- ============================================
-- SCENARIO 4: SERIALIZABLE - Lock Conflicts
-- ============================================
-- You will try to update data that Session 1 has locked

-- ⏸️  WAIT: Let Session 1 run Steps 4.1-4.3 first (they will lock the rows)

-- Step 4.1: Set isolation level to SERIALIZABLE
SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE;

-- Step 4.2: Start a transaction
START TRANSACTION;

-- Step 4.3: Try to update the same user (this will BLOCK!)
-- 🔍 Notice: This will wait for Session 1's lock to be released
UPDATE users SET username = 'session2_blocked' WHERE user_id = 3;
UPDATE user_profile SET full_name = 'Blocked Update' WHERE user_id = 3;
-- ⏸️  This will block until Session 1 commits!

-- ⏸️  WAIT: Session 1 will commit (Step 4.4), then your update will proceed

-- Step 4.4: Commit your changes
COMMIT;

-- Step 4.5: Verify the update went through
SELECT u.user_id, u.username, p.full_name 
FROM users u 
JOIN user_profile p ON u.user_id = p.user_id 
WHERE u.user_id = 3;

-- ============================================
-- SCENARIO 5: CONCURRENT UPDATES ON RELATED TABLES
-- ============================================
-- You will try to update the same user that Session 1 is updating

-- ⏸️  WAIT: Let Session 1 run Steps 5.1-5.4 first

-- Step 5.1: Set isolation level to REPEATABLE READ
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;

-- Step 5.2: Start a transaction
START TRANSACTION;

-- Step 5.3: Try to update the same user (this will BLOCK!)
-- 🔍 Notice: This will wait because Session 1 has locks on user_id = 4
UPDATE users SET username = 'session2_user' WHERE user_id = 4;
UPDATE user_profile SET full_name = 'Session 2 Updated', bio = 'Updated by Session 2' WHERE user_id = 4;
-- ⏸️  This will block until Session 1 commits!

-- ⏸️  WAIT: Session 1 will commit (Step 5.5), then your update will proceed

-- Step 5.4: Commit your changes
COMMIT;

-- Step 5.5: Check final state
SELECT u.user_id, u.username, p.full_name, p.bio 
FROM users u 
JOIN user_profile p ON u.user_id = p.user_id 
WHERE u.user_id = 4;
-- 🔍 Notice: Your changes overwrote Session 1's changes (last writer wins)

-- ============================================
-- SCENARIO 6: LOST UPDATE PREVENTION
-- ============================================
-- You will also increment likes, demonstrating proper locking

-- ⏸️  WAIT: Let Session 1 run Steps 6.1-6.3 first

-- Step 6.1: Set isolation level to REPEATABLE READ
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;

-- Step 6.2: Start a transaction
START TRANSACTION;

-- Step 6.3: Read current likes count
SELECT post_id, likes_count FROM post WHERE post_id = 1;
-- 📝 Note the likes_count (same as Session 1 saw)

-- ⏸️  WAIT: Let Session 1 acquire the lock with SELECT FOR UPDATE (Step 6.4)

-- Step 6.4: Try to lock and update (this will BLOCK!)
-- 🔍 Notice: This will wait because Session 1 has the lock
SELECT post_id, likes_count FROM post WHERE post_id = 1 FOR UPDATE;
-- ⏸️  This will block until Session 1 commits!

-- ⏸️  WAIT: Session 1 will commit (Step 6.7), then you can proceed

-- Step 6.5: Now update based on the CURRENT locked value
UPDATE post SET likes_count = likes_count + 1 WHERE post_id = 1;

-- Step 6.6: Verify
SELECT post_id, likes_count FROM post WHERE post_id = 1;

-- Step 6.7: Commit
COMMIT;

-- ⏸️  SIGNAL: Tell Session 1 to check final count (Step 6.8)

-- ============================================
-- CLEANUP & RESET
-- ============================================
-- Reset to default isolation level
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;

-- Verify no active transactions
SELECT @@transaction_isolation;

-- Clean up the phantom user we created
DELETE FROM user_profile WHERE full_name = 'Phantom User';
DELETE FROM users WHERE username = 'phantom_user';

-- Reset modified users back to original state
UPDATE users SET username = 'john_doe', email = 'john@example.com' WHERE user_id = 1;
UPDATE user_profile SET full_name = 'John Doe', bio = 'Photography enthusiast 📷 | Travel lover ✈️' WHERE user_id = 1;

UPDATE users SET username = 'jane_smith', email = 'jane@example.com' WHERE user_id = 2;
UPDATE user_profile SET full_name = 'Jane Smith', bio = 'Fashion blogger 👗 | Style icon' WHERE user_id = 2;

UPDATE users SET username = 'mike_wilson', email = 'mike@example.com' WHERE user_id = 3;
UPDATE user_profile SET full_name = 'Mike Wilson', bio = 'Fitness coach 💪 | Healthy lifestyle' WHERE user_id = 3;

UPDATE users SET username = 'sarah_jones', email = 'sarah@example.com' WHERE user_id = 4;
UPDATE user_profile SET full_name = 'Sarah Jones', bio = 'Food blogger 🍕 | Recipe creator' WHERE user_id = 4;

-- Verify cleanup
SELECT u.user_id, u.username, u.email, p.full_name, p.bio 
FROM users u 
JOIN user_profile p ON u.user_id = p.user_id 
WHERE u.user_id IN (1, 2, 3, 4)
ORDER BY u.user_id;

-- ============================================
-- 🎓 LEARNING SUMMARY
-- ============================================
/*
What you learned from Session 2's perspective:

1. DIRTY READ:
   - Your uncommitted changes were visible to Session 1
   - When you rolled back, Session 1 saw data that never existed
   - This is why READ UNCOMMITTED is dangerous

2. NON-REPEATABLE READ:
   - Your committed changes appeared in Session 1's ongoing transaction
   - Session 1 got different results from the same query
   - This is normal behavior for READ COMMITTED

3. PHANTOM READ:
   - You inserted a new row while Session 1 was counting
   - In MySQL REPEATABLE READ, Session 1 didn't see it (gap locks)
   - After Session 1 committed, they saw your new row

4. SERIALIZABLE BLOCKING:
   - Your update was blocked by Session 1's locks
   - You had to wait for Session 1 to commit
   - This prevents concurrent modifications

5. CONCURRENT UPDATES:
   - Both sessions tried to update the same user
   - Locks prevented simultaneous updates
   - Last writer wins (your changes overwrote Session 1's)

6. LOST UPDATE PREVENTION:
   - SELECT FOR UPDATE prevented lost updates
   - Both increments were preserved
   - Proper locking is essential for counters
*/

-- ============================================
-- 🧪 EXPERIMENT IDEAS
-- ============================================
/*
Try these on your own:

1. What happens if you update in a different order than Session 1?
   (Update user_profile first, then users)

2. Can you create a deadlock?
   (Session 1: lock A then B, Session 2: lock B then A)

3. What happens with DELETE instead of UPDATE?

4. Try updating different users in each session - do they block?

5. What happens if you use READ COMMITTED instead of REPEATABLE READ
   for the concurrent updates scenario?
*/
