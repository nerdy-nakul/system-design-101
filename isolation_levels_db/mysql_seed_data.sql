-- Sample Seed Data for MySQL Instagram Database
-- Run this after creating the schema with mysql_schema.sql

USE instagram_db;

-- Insert sample users
INSERT INTO users (username, email, password_hash, phone_number, is_verified, is_active) VALUES
('john_doe', 'john@example.com', '$2b$10$abcdefghijklmnopqrstuvwxyz123456', '+1234567890', TRUE, TRUE),
('jane_smith', 'jane@example.com', '$2b$10$abcdefghijklmnopqrstuvwxyz123456', '+1234567891', TRUE, TRUE),
('mike_wilson', 'mike@example.com', '$2b$10$abcdefghijklmnopqrstuvwxyz123456', '+1234567892', TRUE, TRUE),
('sarah_jones', 'sarah@example.com', '$2b$10$abcdefghijklmnopqrstuvwxyz123456', '+1234567893', TRUE, TRUE),
('alex_brown', 'alex@example.com', '$2b$10$abcdefghijklmnopqrstuvwxyz123456', '+1234567894', FALSE, TRUE);

-- Insert user profiles
INSERT INTO user_profile (user_id, full_name, bio, profile_picture_url, website, gender, date_of_birth, is_private, is_business_account, category) VALUES
(1, 'John Doe', 'Photography enthusiast 📷 | Travel lover ✈️', 'https://example.com/profiles/john.jpg', 'https://johndoe.com', 'male', '1995-06-15', FALSE, FALSE, NULL),
(2, 'Jane Smith', 'Fashion blogger 👗 | Style icon', 'https://example.com/profiles/jane.jpg', 'https://janesmith.com', 'female', '1998-03-22', FALSE, TRUE, 'Fashion'),
(3, 'Mike Wilson', 'Fitness coach 💪 | Healthy lifestyle', 'https://example.com/profiles/mike.jpg', 'https://mikewilson.com', 'male', '1992-11-08', FALSE, TRUE, 'Health & Fitness'),
(4, 'Sarah Jones', 'Food blogger 🍕 | Recipe creator', 'https://example.com/profiles/sarah.jpg', NULL, 'female', '1996-08-30', TRUE, FALSE, NULL),
(5, 'Alex Brown', 'Tech enthusiast | Gamer 🎮', 'https://example.com/profiles/alex.jpg', NULL, 'other', '2000-01-12', FALSE, FALSE, NULL);

-- Insert posts
INSERT INTO post (user_id, caption, location, likes_count, comments_count, shares_count) VALUES
(1, 'Beautiful sunset at the beach 🌅 #sunset #beach #photography', 'Malibu Beach, CA', 245, 18, 5),
(1, 'Morning coffee vibes ☕️ #coffee #morning', 'Home', 132, 8, 2),
(2, 'New outfit for the weekend! 👗✨ #fashion #ootd #style', 'New York, NY', 567, 42, 15),
(3, 'Leg day complete! 💪 #fitness #workout #gym', 'Gold\'s Gym', 198, 12, 3),
(4, 'Homemade pizza recipe 🍕 Link in bio! #food #pizza #cooking', 'My Kitchen', 421, 35, 22);

-- Insert photos for posts
INSERT INTO photos (post_id, user_id, photo_url, thumbnail_url, width, height, filter_used, order_index) VALUES
(1, 1, 'https://example.com/photos/sunset1.jpg', 'https://example.com/photos/sunset1_thumb.jpg', 1080, 1350, 'Valencia', 0),
(2, 1, 'https://example.com/photos/coffee1.jpg', 'https://example.com/photos/coffee1_thumb.jpg', 1080, 1080, 'Clarendon', 0),
(3, 2, 'https://example.com/photos/outfit1.jpg', 'https://example.com/photos/outfit1_thumb.jpg', 1080, 1350, 'Lark', 0),
(3, 2, 'https://example.com/photos/outfit2.jpg', 'https://example.com/photos/outfit2_thumb.jpg', 1080, 1350, 'Lark', 1),
(4, 3, 'https://example.com/photos/gym1.jpg', 'https://example.com/photos/gym1_thumb.jpg', 1080, 1080, 'Normal', 0),
(5, 4, 'https://example.com/photos/pizza1.jpg', 'https://example.com/photos/pizza1_thumb.jpg', 1080, 1350, 'Gingham', 0);

-- Insert videos
INSERT INTO video (user_id, video_url, thumbnail_url, duration, width, height, quality) VALUES
(2, 'https://example.com/videos/fashion_haul.mp4', 'https://example.com/videos/fashion_haul_thumb.jpg', 45, 1080, 1920, 'HD'),
(3, 'https://example.com/videos/workout_routine.mp4', 'https://example.com/videos/workout_routine_thumb.jpg', 120, 1080, 1920, 'HD'),
(4, 'https://example.com/videos/cooking_tutorial.mp4', 'https://example.com/videos/cooking_tutorial_thumb.jpg', 180, 1080, 1920, 'HD');

-- Insert reels
INSERT INTO reels (user_id, video_id, caption, audio_name, is_original_audio, views_count, likes_count, comments_count, shares_count) VALUES
(2, 1, 'Fashion haul try-on 👗 #fashion #haul', 'Trending Sound 2024', FALSE, 15420, 892, 67, 45),
(3, 2, '5-minute abs workout 💪 #fitness #abs', 'Workout Motivation', FALSE, 28750, 1543, 124, 89),
(4, 3, 'Easy pizza recipe in 10 minutes! 🍕 #cooking #recipe', 'Cooking Vibes', TRUE, 42100, 2341, 198, 156);

-- Insert stories (active for 24 hours)
INSERT INTO story (user_id, media_type, media_url, thumbnail_url, views_count, expires_at) VALUES
(1, 'photo', 'https://example.com/stories/john_story1.jpg', NULL, 89, DATE_ADD(NOW(), INTERVAL 24 HOUR)),
(2, 'video', 'https://example.com/stories/jane_story1.mp4', 'https://example.com/stories/jane_story1_thumb.jpg', 234, DATE_ADD(NOW(), INTERVAL 24 HOUR)),
(3, 'photo', 'https://example.com/stories/mike_story1.jpg', NULL, 156, DATE_ADD(NOW(), INTERVAL 24 HOUR)),
(4, 'photo', 'https://example.com/stories/sarah_story1.jpg', NULL, 67, DATE_ADD(NOW(), INTERVAL 24 HOUR));

-- Insert followers relationships
INSERT INTO followers (user_id, follower_user_id) VALUES
(1, 2), (1, 3), (1, 4), (1, 5),  -- Users 2,3,4,5 follow user 1
(2, 1), (2, 3), (2, 4),          -- Users 1,3,4 follow user 2
(3, 1), (3, 2), (3, 5),          -- Users 1,2,5 follow user 3
(4, 1), (4, 2), (4, 3),          -- Users 1,2,3 follow user 4
(5, 1), (5, 3);                  -- Users 1,3 follow user 5

-- Insert followings relationships
INSERT INTO followings (user_id, following_user_id) VALUES
(2, 1), (3, 1), (4, 1), (5, 1),  -- User 1 is followed by 2,3,4,5
(1, 2), (3, 2), (4, 2),          -- User 2 is followed by 1,3,4
(1, 3), (2, 3), (5, 3),          -- User 3 is followed by 1,2,5
(1, 4), (2, 4), (3, 4),          -- User 4 is followed by 1,2,3
(1, 5), (3, 5);                  -- User 5 is followed by 1,3

-- Insert mutual connections (users who follow each other)
INSERT INTO connections (user_id_1, user_id_2, status) VALUES
(1, 2, 'accepted'),  -- John and Jane are connected
(1, 3, 'accepted'),  -- John and Mike are connected
(1, 4, 'accepted'),  -- John and Sarah are connected
(2, 3, 'accepted'),  -- Jane and Mike are connected
(2, 4, 'accepted');  -- Jane and Sarah are connected

-- Insert comments
INSERT INTO comments (post_id, user_id, comment_text, likes_count) VALUES
(1, 2, 'Stunning photo! 😍', 12),
(1, 3, 'Love the colors!', 8),
(1, 4, 'Where is this? Beautiful!', 5),
(3, 1, 'Looking great! 👌', 15),
(3, 4, 'Love your style!', 9),
(5, 1, 'This looks delicious! 🤤', 18),
(5, 2, 'Need this recipe!', 11),
(5, 3, 'Making this tonight!', 7);

-- Insert nested comment (reply)
INSERT INTO comments (post_id, user_id, parent_comment_id, comment_text, likes_count) VALUES
(1, 1, 3, 'It\'s Malibu Beach! You should visit!', 3);

-- Insert likes on posts
INSERT INTO likes (user_id, post_id) VALUES
(2, 1), (3, 1), (4, 1), (5, 1),  -- Post 1 likes
(1, 3), (3, 3), (4, 3), (5, 3),  -- Post 3 likes
(1, 5), (2, 5), (3, 5), (5, 5);  -- Post 5 likes

-- Insert likes on reels
INSERT INTO likes (user_id, reel_id) VALUES
(1, 1), (3, 1), (4, 1),  -- Reel 1 likes
(1, 2), (2, 2), (4, 2),  -- Reel 2 likes
(1, 3), (2, 3), (3, 3);  -- Reel 3 likes

-- Insert hashtags
INSERT INTO hashtags (hashtag_name, usage_count) VALUES
('sunset', 1245),
('beach', 3421),
('photography', 8765),
('coffee', 2134),
('morning', 1876),
('fashion', 12543),
('ootd', 9876),
('style', 11234),
('fitness', 15678),
('workout', 13456),
('gym', 10987),
('food', 18765),
('pizza', 5432),
('cooking', 7654);

-- Insert post-hashtag relationships
INSERT INTO post_hashtags (post_id, hashtag_id) VALUES
(1, 1), (1, 2), (1, 3),  -- Post 1: sunset, beach, photography
(2, 4), (2, 5),          -- Post 2: coffee, morning
(3, 6), (3, 7), (3, 8),  -- Post 3: fashion, ootd, style
(4, 9), (4, 10), (4, 11), -- Post 4: fitness, workout, gym
(5, 12), (5, 13), (5, 14); -- Post 5: food, pizza, cooking

-- Display summary
SELECT 'Database seeded successfully!' as Status;
SELECT COUNT(*) as total_users FROM users;
SELECT COUNT(*) as total_posts FROM post;
SELECT COUNT(*) as total_reels FROM reels;
SELECT COUNT(*) as total_stories FROM story;
SELECT COUNT(*) as total_followers FROM followers;
SELECT COUNT(*) as total_connections FROM connections;
