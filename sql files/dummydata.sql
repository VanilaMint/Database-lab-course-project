BEGIN;

-- =======================================================
-- 1. DISABLE TRIGGERS & CLEANUP
-- =======================================================

ALTER TABLE reviews DISABLE TRIGGER ALL;

ALTER TABLE reports DISABLE TRIGGER ALL;


-- =======================================================
-- 2. SEED DATA 
-- =======================================================
INSERT INTO notification_types (name) VALUES 
('Order update'), ('Promotion alert'), ('System message')
ON CONFLICT (name) DO NOTHING;

INSERT INTO report_categories (name) VALUES 
('Spam'), ('Inappropriate Content'), ('Fraud'), ('Other')
ON CONFLICT (name) DO NOTHING;

INSERT INTO product_categories (name) VALUES 
('Electronics'), ('Clothing'), ('Home & Garden'), ('Beauty')
ON CONFLICT (name) DO NOTHING;

-- =======================================================
-- 3. USERS (Generate IDs 1 to 1000)
-- =======================================================
INSERT INTO users (user_name, password, personal_phone, email, privilege, account_status, registration_date)
SELECT 
    'user_' || i, 
    'hashed_pass_123', 
    '09' || lpad(i::text, 8, '0'), 
    'user_' || i || '@example.com', 
    CASE WHEN i <= 5 THEN 'Admin' ELSE 'Customer' END,
    'Active',
    NOW() - (random() * (INTERVAL '365 days'))
FROM generate_series(1, 1000) AS i
ON CONFLICT DO NOTHING;

-- =======================================================
-- 4. STORES (Generate IDs 1 to 50)
-- =======================================================
INSERT INTO stores (user_id, store_name, pickup_address, pickup_address_ward, pickup_address_city, postal_code, description)
SELECT 
    -- Link to random users between 6 and 1000
    (floor(random() * (1000-6+1) + 6)::int), 
    'Store_' || i || '_' || md5(random()::text), 
    i || ' Market Street', 
    'Ward ' || (floor(random() * 10 + 1)::int), 
    CASE WHEN random() > 0.5 THEN 'Hanoi' ELSE 'Ho Chi Minh City' END, 
    '10000',
    'Description for store ' || i
FROM generate_series(1, 50) AS i;

-- =======================================================
-- 5. PRODUCTS (500 rows)
-- =======================================================
INSERT INTO products (store_id, product_name, product_category_id, status, description)
SELECT 
    (floor(random() * 50 + 1)::int), -- Random Store ID 1-50
    'Product ' || i, 
    (floor(random() * 4 + 1)::int),
    'active',
    'Great product description #' || i
FROM generate_series(1, 500) AS i;

-- =======================================================
-- 6. VARIANTS (1,000 rows)
-- =======================================================
INSERT INTO product_variants (product_id, variant_name, price, stock)
SELECT 
    (floor(random() * 500 + 1)::int), -- Random Product ID 1-500
    CASE WHEN random() > 0.5 THEN 'Standard' ELSE 'Premium' END,
    (random() * 100 + 5)::numeric(10,2),
    floor(random() * 100)::int
FROM generate_series(1, 1000) AS i;

-- =======================================================
-- 7. ORDERS (2,000 rows)
-- =======================================================
INSERT INTO orders (user_id, store_id, shipping_address, shipping_ward, shipping_city, payment_method, order_status, create_date)
SELECT 
    (floor(random() * 1000 + 1)::int), -- Random User ID
    (floor(random() * 50 + 1)::int),   -- Random Store ID
    '123 Buyer Lane', 
    'Ward 5', 
    'Da Nang', 
    CASE WHEN random() > 0.5 THEN 'Cash' ELSE 'Online transaction' END,
    CASE (floor(random() * 5)::int)
        WHEN 0 THEN 'Approved by vendor'
        WHEN 1 THEN 'Approved by vendor' 
        WHEN 2 THEN 'Complaint resolved'
        WHEN 3 THEN 'Complaint filed'
        ELSE 'Unresolved'
    END,
    NOW() - (random() * (INTERVAL '90 days'))
FROM generate_series(1, 2000) AS i;

-- =======================================================
-- 8. ORDER ITEMS (Guaranteed coverage)
-- =======================================================
INSERT INTO order_items (order_id, variant_id, item_quantity, price_at_purchase)
SELECT 
    o.order_id,
    -- Random Variant ID (Assuming IDs are roughly 1-1000)
    (floor(random() * 1000 + 1)::int),
    floor(random() * 10 + 1)::int, -- Qty 1-10
    (random() * 190 + 10)::numeric(10,2)
FROM orders o
CROSS JOIN generate_series(1, floor(random() * 3 + 1)::int) AS x -- 1-3 items per order
ON CONFLICT (order_id, variant_id) DO NOTHING;

-- =======================================================
-- 9. SHIPPING STATUSES
-- =======================================================
INSERT INTO shipping_statuses (order_id, status, update_time)
SELECT 
    order_id, 
    CASE 
        WHEN order_status = 'Unresolved' THEN 'Not shipped'
        WHEN order_status = 'Complaint filed' THEN 'shipped'
        WHEN random() < 0.2 THEN 'Not shipped' 
        WHEN random() < 0.6 THEN 'shipped' 
        ELSE 'received' 
    END, 
    create_date + (INTERVAL '1 day')
FROM orders
ON CONFLICT DO NOTHING;

-- =======================================================
-- 10. REVIEWS (Fixed Volume & Variety)
-- =======================================================
INSERT INTO reviews (user_id, product_id, rating, comment, create_date)
SELECT 
    o.user_id,
    p.product_id,
    floor(random() * 5 + 1)::int,
    'Review for ' || p.product_name || ': ' || (ARRAY['Great!','Good value','Okay','Bad quality'])[floor(random()*4+1)],
    o.create_date + (INTERVAL '5 days')
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN product_variants pv ON oi.variant_id = pv.variant_id
JOIN products p ON pv.product_id = p.product_id
WHERE o.order_status IN ('Approved by vendor', 'Complaint resolved', 'received')
ORDER BY random() 
LIMIT 3000;

-- =======================================================
-- 11. COMPLAINTS 
-- =======================================================
INSERT INTO complaints (user_id, order_id, comment, create_date)
SELECT 
    user_id,
    order_id,
    'Item arrived damaged or late.',
    create_date + (INTERVAL '3 days')
FROM orders
WHERE order_status IN ('Complaint filed', 'Complaint resolved');

-- =======================================================
-- 12. REPORTS 
-- =======================================================
INSERT INTO reports (report_category_id, user_id, store_id, comment, resolved_status)
SELECT 
    (floor(random() * 4 + 1)::int),    -- Random Category 1-4
    (floor(random() * 1000 + 1)::int), -- Random User 1-1000
    (floor(random() * 50 + 1)::int),   -- Random Store 1-50
    'Automated report comment.',
    'Unresolved'
FROM generate_series(1, 50) AS i;

-- =======================================================
-- 13. NOTIFICATIONS 
-- =======================================================
INSERT INTO notifications (sender_id, receiver_id, notification_type_id, content)
SELECT 
    (floor(random() * 1000 + 1)::int), -- Random Sender
    (floor(random() * 1000 + 1)::int), -- Random Receiver
    (floor(random() * 3 + 1)::int),    -- Random Type 1-3
    'System generated notification #' || i
FROM generate_series(1, 100) AS i;

-- =======================================================
-- 14. PROMOTIONS (New & Fixed for Variety)
-- =======================================================

-- A. Create 50 Promotions
INSERT INTO promotions (discount_type, start_period, end_period)
SELECT 
    CASE WHEN random() > 0.5 THEN 'Fixed Price' ELSE 'Percentage Discount' END,
    NOW() - (random() * interval '30 days'), -- Start date in last 30 days
    NOW() + (random() * interval '30 days')  -- End date in future 30 days
FROM generate_series(1, 50);

-- B. Link Promotions to Products (Randomly)
-- Guarantees 1 to 5 products per promotion
INSERT INTO promotion_products (promotion_id, product_id)
SELECT 
    p.promotion_id,
    (floor(random() * 500 + 1)::int) -- Random Product ID 1-500
FROM promotions p
CROSS JOIN generate_series(1, floor(random() * 250 + 1)::int) -- 1-5 items per promo
ON CONFLICT DO NOTHING;

-- C. Add Details for "Fixed Price" Promotions
INSERT INTO fixed_price_promotions (promotion_id, price)
SELECT 
    promotion_id,
    (random() * 50 + 5)::numeric(10,2) -- Random fixed price $5 - $55
FROM promotions
WHERE discount_type = 'Fixed Price';

-- D. Add Details for "Percentage Discount" Promotions
INSERT INTO percent_discount_promotions (promotion_id, discount_percent)
SELECT 
    promotion_id,
    (floor(random() * 50 + 5)::numeric(5,2)) -- Random % 5% - 55%
FROM promotions
WHERE discount_type = 'Percentage Discount';

-- =======================================================
-- 15. RE-ENABLE TRIGGERS
-- =======================================================
ALTER TABLE orders ENABLE TRIGGER ALL;
ALTER TABLE order_items ENABLE TRIGGER ALL;
ALTER TABLE reviews ENABLE TRIGGER ALL;
ALTER TABLE shipping_statuses ENABLE TRIGGER ALL;
ALTER TABLE reports ENABLE TRIGGER ALL;
ALTER TABLE complaints ENABLE TRIGGER ALL;
ALTER TABLE replies ENABLE TRIGGER ALL;
ALTER TABLE notifications ENABLE TRIGGER ALL;
ALTER TABLE promotions ENABLE TRIGGER ALL;
ALTER TABLE promotion_products ENABLE TRIGGER ALL;

COMMIT;


------------------------------------------------------------------------
--BATCH 1
--------------------------------------------------------------------------


-- =======================================================
-- 2. USERS
-- We insert users, letting the database assign the ID.
-- =======================================================

INSERT INTO users (user_name, password, last_name, first_name, personal_phone, email, privilege, account_status) 
VALUES 
('admin_user', 'pass123', 'Admin', 'Super', '0901111111', 'admin@market.com', 'Admin', 'Active'),
('store_owner_bob', 'pass456', 'Builder', 'Bob', '0902222222', 'bob@store.com', 'Customer', 'Active'),
('buyer_alice', 'pass789', 'Wonderland', 'Alice', '0903333333', 'alice@gmail.com', 'Customer', 'Active')
ON CONFLICT (user_name) DO NOTHING; 
-- Note: schema forces unique user_name, so this prevents errors if run twice.

-- =======================================================
-- 3. STORES
-- We verify the user_id dynamically using the user_name
-- =======================================================

INSERT INTO stores (user_id, store_name, pickup_address, pickup_address_ward, pickup_address_city, postal_code, description)
VALUES (
    (SELECT user_id FROM users WHERE user_name = 'store_owner_bob'), 
    'Bob''s Gadgets', 
    '123 Tech Street', 
    'Ward 1', 
    'Ho Chi Minh City', 
    '70000', 
    'The best electronics in town.'
) ON CONFLICT (store_name) DO NOTHING;

-- =======================================================
-- 4. PRODUCTS & VARIANTS
-- We look up store_id and category_id dynamically
-- =======================================================

-- Product 1: Smartphone
WITH inserted_product AS (
    INSERT INTO products (store_id, product_name, product_category_id, description, status)
    VALUES (
        (SELECT store_id FROM stores WHERE store_name = 'Bob''s Gadgets' LIMIT 1),
        'Super Smartphone X',
        (SELECT product_category_id FROM product_categories WHERE name = 'Electronics'),
        'The latest model with AI features.',
        'active'
    )
    RETURNING product_id
)
INSERT INTO product_variants (product_id, variant_name, price, stock)
SELECT product_id, '128GB - Black', 999.00, 50 FROM inserted_product
UNION ALL
SELECT product_id, '256GB - Silver', 1099.00, 20 FROM inserted_product;

-- Product 2: T-Shirt
WITH inserted_product AS (
    INSERT INTO products (store_id, product_name, product_category_id, description, status)
    VALUES (
        (SELECT store_id FROM stores WHERE store_name = 'Bob''s Gadgets' LIMIT 1),
        'Cotton T-Shirt',
        (SELECT product_category_id FROM product_categories WHERE name = 'Clothing'),
        '100% organic cotton.',
        'active'
    )
    RETURNING product_id
)
INSERT INTO product_variants (product_id, variant_name, price, stock)
SELECT product_id, 'Large - White', 15.00, 100 FROM inserted_product;

-- =======================================================
-- 5. PROMOTIONS
-- We use CTEs to capture the generated ID immediately to link the subtype table
-- =======================================================

-- Promotion A: 10% Off
WITH new_promo AS (
    INSERT INTO promotions (discount_type, start_period, end_period) 
    VALUES ('Percentage Discount', NOW() - INTERVAL '1 day', NOW() + INTERVAL '7 days')
    RETURNING promotion_id
),
insert_type AS (
    INSERT INTO percent_discount_promotions (promotion_id, discount_percent)
    SELECT promotion_id, 10.00 FROM new_promo
)
INSERT INTO promotion_products (promotion_id, product_id)
SELECT 
    (SELECT promotion_id FROM new_promo), 
    (SELECT product_id FROM products WHERE product_name = 'Super Smartphone X' LIMIT 1);


-- Promotion B: Fixed Price
WITH new_promo AS (
    INSERT INTO promotions (discount_type, start_period, end_period) 
    VALUES ('Fixed Price', NOW() - INTERVAL '1 day', NOW() + INTERVAL '7 days')
    RETURNING promotion_id
),
insert_type AS (
    INSERT INTO fixed_price_promotions (promotion_id, price)
    SELECT promotion_id, 10.00 FROM new_promo
)
INSERT INTO promotion_products (promotion_id, product_id)
SELECT 
    (SELECT promotion_id FROM new_promo), 
    (SELECT product_id FROM products WHERE product_name = 'Cotton T-Shirt' LIMIT 1);

-- =======================================================
-- 6. ORDERS & ORDER ITEMS
-- Complex insertion: Order -> Get ID -> Insert Items -> Insert Shipping
-- =======================================================

WITH new_order AS (
    INSERT INTO orders (user_id, store_id, shipping_address, shipping_ward, shipping_city, payment_method, order_status)
    VALUES (
        (SELECT user_id FROM users WHERE user_name = 'buyer_alice'),
        (SELECT store_id FROM stores WHERE store_name = 'Bob''s Gadgets' LIMIT 1),
        '456 User Lane', 'Ward 5', 'Hanoi', 'Cash', 'Approved by vendor'
    )
    RETURNING order_id
),
order_items_insert AS (
    INSERT INTO order_items (order_id, variant_id, item_quantity)
    SELECT 
        (SELECT order_id FROM new_order),
        (SELECT variant_id FROM product_variants WHERE variant_name = '128GB - Black' LIMIT 1),
        1
)
INSERT INTO shipping_statuses (order_id, status)
SELECT order_id, 'shipped' FROM new_order;

-- =======================================================
-- 7. REVIEWS & REPLIES
-- Relies on the order existing (checked by trigger)
-- =======================================================

WITH new_review AS (
    INSERT INTO reviews (user_id, product_id, comment, rating)
    VALUES (
        (SELECT user_id FROM users WHERE user_name = 'buyer_alice'),
        (SELECT product_id FROM products WHERE product_name = 'Super Smartphone X' LIMIT 1),
        'Great phone, got it on discount!', 
        5
    )
    RETURNING review_id
)
INSERT INTO replies (user_id, review_id, comment)
SELECT 
    (SELECT user_id FROM users WHERE user_name = 'store_owner_bob'),
    review_id,
    'Thanks Alice! Glad you liked it.'
FROM new_review;

-- =======================================================
-- 8. COMPLAINTS & REPORTS
-- =======================================================

INSERT INTO reports (report_category_id, user_id, store_id, comment, resolved_status)
VALUES (
    (SELECT report_category_id FROM report_categories WHERE name = 'Inappropriate Content'),
    (SELECT user_id FROM users WHERE user_name = 'buyer_alice'),
    (SELECT store_id FROM stores WHERE store_name = 'Bob''s Gadgets' LIMIT 1),
    'The product description had a typo.', 
    'Pending Review'
);

-- We need to find Alice's recent order ID for the complaint
INSERT INTO complaints (user_id, order_id, comment)
VALUES (
    (SELECT user_id FROM users WHERE user_name = 'buyer_alice'),
    (SELECT order_id FROM orders WHERE user_id = (SELECT user_id FROM users WHERE user_name = 'buyer_alice') ORDER BY create_date DESC LIMIT 1),
    'Shipping took longer than expected.'
);


------------------------------------------------------------------------------
-- BATCH 2
----------------------------------------------------------------------------------
-- =======================================================
-- 1. NEW USERS (Customers & A New Store Owner)
-- =======================================================

INSERT INTO users (user_name, password, last_name, first_name, personal_phone, email, privilege, account_status) 
VALUES 
('store_owner_sara', 'pass_sara', 'Green', 'Sara', '0904444444', 'sara@garden.com', 'Customer', 'Active'),
('customer_dave', 'pass_dave', 'Davidson', 'Dave', '0905555555', 'dave@mail.com', 'Customer', 'Active'),
('customer_eve', 'pass_eve', 'Evening', 'Eve', '0906666666', 'eve@mail.com', 'Customer', 'Active')
ON CONFLICT (user_name) DO NOTHING;

-- =======================================================
-- 2. NEW STORE: "Sara's Garden"
-- =======================================================

INSERT INTO stores (user_id, store_name, pickup_address, pickup_address_ward, pickup_address_city, postal_code, description, create_date)
VALUES (
    (SELECT user_id FROM users WHERE user_name = 'store_owner_sara'), 
    'Sara''s Garden World', -- Unique Name
    '88 Blossom Blvd', 
    'Ward 3', 
    'Da Nang', 
    '55000', 
    'Everything you need for a beautiful garden.',
    NOW() - INTERVAL '6 months' -- Store created 6 months ago
);

-- =======================================================
-- 3. NEW PRODUCTS (For Sara and Bob)
-- =======================================================

-- Product A: Ceramic Pot (Sara's Store)
WITH inserted_product AS (
    INSERT INTO products (store_id, product_name, product_category_id, description, status, create_date)
    VALUES (
        (SELECT store_id FROM stores WHERE store_name = 'Sara''s Garden World'),
        'Handmade Ceramic Pot',
        (SELECT product_category_id FROM product_categories WHERE name = 'Home & Garden'),
        'Beautiful glazed pot for indoor plants.',
        'active',
        NOW() - INTERVAL '5 months'
    )
    RETURNING product_id
)
INSERT INTO product_variants (product_id, variant_name, price, stock)
SELECT product_id, 'Medium - Blue', 25.00, 30 FROM inserted_product;

-- Product B: Gaming Mouse (Bob's Store - Existing Store)
WITH inserted_product AS (
    INSERT INTO products (store_id, product_name, product_category_id, description, status, create_date)
    VALUES (
        (SELECT store_id FROM stores WHERE store_name = 'Bob''s Gadgets'),
        'Pro Gaming Mouse',
        (SELECT product_category_id FROM product_categories WHERE name = 'Electronics'),
        'High DPI mouse for professionals.',
        'active',
        NOW() - INTERVAL '4 months'
    )
    RETURNING product_id
)
INSERT INTO product_variants (product_id, variant_name, price, stock)
SELECT product_id, 'RGB - Wired', 45.00, 100 FROM inserted_product;

-- =======================================================
-- 4. HISTORICAL ORDER (3 Months Ago - Completed)
-- Customer: Dave, Store: Sara's Garden
-- =======================================================

WITH new_order AS (
    INSERT INTO orders (user_id, store_id, shipping_address, shipping_ward, shipping_city, payment_method, order_status, create_date)
    VALUES (
        (SELECT user_id FROM users WHERE user_name = 'customer_dave'),
        (SELECT store_id FROM stores WHERE store_name = 'Sara''s Garden World'),
        '777 Relax Road', 'Ward 10', 'Da Nang', 'Online transaction', 'Approved by vendor',
        NOW() - INTERVAL '3 months' -- Placed 3 months ago
    )
    RETURNING order_id
),
order_items_insert AS (
    INSERT INTO order_items (order_id, variant_id, item_quantity, price_at_purchase)
    SELECT 
        (SELECT order_id FROM new_order),
        (SELECT variant_id FROM product_variants WHERE variant_name = 'Medium - Blue' LIMIT 1),
        2,
        0 -- Trigger will calculate actual price
)
INSERT INTO shipping_statuses (order_id, status, update_time)
SELECT order_id, 'received', NOW() - INTERVAL '2 months' FROM new_order;


-- =======================================================
-- 5. RECENT ORDER (2 Days Ago - With Complaint)
-- Customer: Eve, Store: Bob's Gadgets
-- =======================================================

WITH new_order AS (
    INSERT INTO orders (user_id, store_id, shipping_address, shipping_ward, shipping_city, payment_method, order_status, create_date)
    VALUES (
        (SELECT user_id FROM users WHERE user_name = 'customer_eve'),
        (SELECT store_id FROM stores WHERE store_name = 'Bob''s Gadgets'),
        '101 Fast Lane', 'Ward 1', 'Ho Chi Minh City', 'Cash', 'Complaint filed',
        NOW() - INTERVAL '2 days' -- Placed 2 days ago
    )
    RETURNING order_id
),
order_items_insert AS (
    INSERT INTO order_items (order_id, variant_id, item_quantity, price_at_purchase)
    SELECT 
        (SELECT order_id FROM new_order),
        (SELECT variant_id FROM product_variants WHERE variant_name = 'RGB - Wired' LIMIT 1),
        1,
        0 -- Trigger will calculate actual price
)
INSERT INTO shipping_statuses (order_id, status, update_time)
SELECT order_id, 'shipped', NOW() - INTERVAL '1 day' FROM new_order;

-- =======================================================
-- 6. HISTORICAL REVIEWS & COMPLAINTS
-- =======================================================

-- Review for Dave's 3-month-old order (Ceramic Pot)
INSERT INTO reviews (user_id, product_id, comment, rating, create_date)
VALUES (
    (SELECT user_id FROM users WHERE user_name = 'customer_dave'),
    (SELECT product_id FROM products WHERE product_name = 'Handmade Ceramic Pot'),
    'Arrived intact and looks great in my living room.', 
    5,
    NOW() - INTERVAL '2 months - 5 days' -- Reviewed shortly after receiving
);

-- Complaint for Eve's recent order (Gaming Mouse)
-- We need to look up Eve's most recent order ID
INSERT INTO complaints (user_id, order_id, comment, create_date)
VALUES (
    (SELECT user_id FROM users WHERE user_name = 'customer_eve'),
    (SELECT order_id FROM orders WHERE user_id = (SELECT user_id FROM users WHERE user_name = 'customer_eve') ORDER BY create_date DESC LIMIT 1),
    'The mouse buttons feel sticky.',
    NOW() - INTERVAL '1 hour'
);

-- =======================================================
-- 7. NOTIFICATIONS (Simulating History)
-- =======================================================

INSERT INTO notifications (sender_id, receiver_id, notification_type_id, content, time_sent, read_status)
VALUES 
(
    (SELECT user_id FROM users WHERE user_name = 'store_owner_sara'),
    (SELECT user_id FROM users WHERE user_name = 'customer_dave'),
    (SELECT notification_type_id FROM notification_types WHERE name = 'Order update'),
    'Your order has been shipped!',
    NOW() - INTERVAL '2 months - 2 days',
    'Read'
);
-----------------------------------------------------------------------------
--BATCH 3
-----------------------------------------------------------------------------
-- =======================================================
-- 1. NEW USERS (High Volume Customers)
-- =======================================================
INSERT INTO users (user_name, password, last_name, first_name, personal_phone, email, privilege, account_status) 
VALUES 
('fashion_fanatic', 'pass_fashion', 'Styles', 'Harry', '0907777777', 'harry@fashion.com', 'Customer', 'Active'),
('tech_guru', 'pass_tech', 'Gates', 'Billie', '0908888888', 'billie@tech.com', 'Customer', 'Active')
ON CONFLICT (user_name) DO NOTHING;

-- =======================================================
-- 2. COMPLEX PRODUCT: "Designer Hoodie" (Many Variants)
-- Store: Sara's Garden World (Expanding into lifestyle)
-- =======================================================

WITH inserted_product AS (
    INSERT INTO products (store_id, product_name, product_category_id, description, status, create_date)
    VALUES (
        (SELECT store_id FROM stores WHERE store_name = 'Sara''s Garden World'),
        'Cozy Garden Hoodie',
        (SELECT product_category_id FROM product_categories WHERE name = 'Clothing'),
        'Premium cotton hoodie perfect for outdoor gardening.',
        'active',
        NOW() - INTERVAL '3 months'
    )
    RETURNING product_id
)
INSERT INTO product_variants (product_id, variant_name, price, stock)
SELECT product_id, 'Small - Earth Green', 45.00, 20 FROM inserted_product
UNION ALL
SELECT product_id, 'Medium - Earth Green', 45.00, 50 FROM inserted_product
UNION ALL
SELECT product_id, 'Large - Earth Green', 45.00, 30 FROM inserted_product
UNION ALL
SELECT product_id, 'Small - Clay Red', 48.00, 15 FROM inserted_product
UNION ALL
SELECT product_id, 'Medium - Clay Red', 48.00, 40 FROM inserted_product
UNION ALL
SELECT product_id, 'Large - Clay Red', 48.00, 25 FROM inserted_product;

-- =======================================================
-- 3. COMPLEX PRODUCT: "Modular Bookshelf" (Price Variants)
-- Store: Bob's Gadgets (Expanding into office furniture)
-- =======================================================

WITH inserted_product AS (
    INSERT INTO products (store_id, product_name, product_category_id, description, status, create_date)
    VALUES (
        (SELECT store_id FROM stores WHERE store_name = 'Bob''s Gadgets'),
        'Modular Office Shelf',
        (SELECT product_category_id FROM product_categories WHERE name = 'Home & Garden'),
        'Customizable shelving unit for modern offices.',
        'active',
        NOW() - INTERVAL '2 months'
    )
    RETURNING product_id
)
INSERT INTO product_variants (product_id, variant_name, price, stock)
SELECT product_id, '2-Tier Basic', 89.99, 10 FROM inserted_product
UNION ALL
SELECT product_id, '3-Tier Standard', 129.99, 15 FROM inserted_product
UNION ALL
SELECT product_id, '5-Tier Deluxe', 199.99, 5 FROM inserted_product
UNION ALL
SELECT product_id, 'Add-on: Glass Door', 45.00, 50 FROM inserted_product;

-- =======================================================
-- 4. PROMOTIONS (Specific Variant Targeting)
-- =======================================================

-- Promo: "Green Hoodie Sale" - 20% off
-- Note: Promotions are linked to Products, not Variants directly in your schema, 
-- so this discount applies to ALL variants of the hoodie.
WITH new_promo AS (
    INSERT INTO promotions (discount_type, start_period, end_period) 
    VALUES ('Percentage Discount', NOW() - INTERVAL '1 month', NOW() + INTERVAL '1 month')
    RETURNING promotion_id
),
insert_type AS (
    INSERT INTO percent_discount_promotions (promotion_id, discount_percent)
    SELECT promotion_id, 20.00 FROM new_promo
)
INSERT INTO promotion_products (promotion_id, product_id)
SELECT 
    (SELECT promotion_id FROM new_promo), 
    (SELECT product_id FROM products WHERE product_name = 'Cozy Garden Hoodie' LIMIT 1);


-- =======================================================
-- 5. COMPLEX ORDER (Multi-Variant, Multi-Quantity)
-- User: fashion_fanatic
-- Items: 1x Small Green Hoodie, 2x Medium Red Hoodie
-- =======================================================

WITH new_order AS (
    INSERT INTO orders (user_id, store_id, shipping_address, shipping_ward, shipping_city, payment_method, order_status, create_date)
    VALUES (
        (SELECT user_id FROM users WHERE user_name = 'fashion_fanatic'),
        (SELECT store_id FROM stores WHERE store_name = 'Sara''s Garden World'),
        '55 Runway Road', 'Ward 2', 'Ho Chi Minh City', 'Online transaction', 'Approved by vendor',
        NOW() - INTERVAL '3 weeks'
    )
    RETURNING order_id
)
INSERT INTO order_items (order_id, variant_id, item_quantity, price_at_purchase)
SELECT 
    (SELECT order_id FROM new_order),
    (SELECT variant_id FROM product_variants WHERE variant_name = 'Small - Earth Green' LIMIT 1),
    1,
    0 -- Trigger calculates: 45.00 - 20% = 36.00
UNION ALL
SELECT 
    (SELECT order_id FROM new_order),
    (SELECT variant_id FROM product_variants WHERE variant_name = 'Medium - Clay Red' LIMIT 1),
    2,
    0; -- Trigger calculates: 48.00 - 20% = 38.40 (Promo applies to product)

-- Add Shipping Status
INSERT INTO shipping_statuses (order_id, status, update_time)
VALUES (
    (SELECT order_id FROM orders WHERE user_id = (SELECT user_id FROM users WHERE user_name = 'fashion_fanatic') ORDER BY create_date DESC LIMIT 1),
    'shipped',
    NOW() - INTERVAL '2 weeks'
);


-- =======================================================
-- 6. COMPLEX ORDER (Expensive Items)
-- User: tech_guru
-- Items: 1x 5-Tier Deluxe Shelf, 2x Glass Doors
-- =======================================================

WITH new_order AS (
    INSERT INTO orders (user_id, store_id, shipping_address, shipping_ward, shipping_city, payment_method, order_status, create_date)
    VALUES (
        (SELECT user_id FROM users WHERE user_name = 'tech_guru'),
        (SELECT store_id FROM stores WHERE store_name = 'Bob''s Gadgets'),
        '99 Silicon Valley Dr', 'Ward 9', 'Da Nang', 'Cash', 'Unresolved', -- Order just placed/pending
        NOW() - INTERVAL '1 day'
    )
    RETURNING order_id
)
INSERT INTO order_items (order_id, variant_id, item_quantity, price_at_purchase)
SELECT 
    (SELECT order_id FROM new_order),
    (SELECT variant_id FROM product_variants WHERE variant_name = '5-Tier Deluxe' LIMIT 1),
    1,
    0 
UNION ALL
SELECT 
    (SELECT order_id FROM new_order),
    (SELECT variant_id FROM product_variants WHERE variant_name = 'Add-on: Glass Door' LIMIT 1),
    2,
    0;

-- =======================================================
-- 7. REVIEWS (Detailed Feedback on Variants)
-- =======================================================

INSERT INTO reviews (user_id, product_id, comment, rating, create_date)
VALUES (
    (SELECT user_id FROM users WHERE user_name = 'fashion_fanatic'),
    (SELECT product_id FROM products WHERE product_name = 'Cozy Garden Hoodie'),
    'The Earth Green color is fantastic, but the Clay Red is a bit brighter than expected. Very comfortable though.', 
    4,
    NOW() - INTERVAL '1 week'
);

-- Store Reply
INSERT INTO replies (user_id, review_id, comment)
VALUES (
    (SELECT user_id FROM users WHERE user_name = 'store_owner_sara'),
    (SELECT review_id FROM reviews WHERE comment LIKE '%Earth Green%' LIMIT 1),
    'Thanks for the detailed feedback Harry! We will update our photos to reflect the red color better.'
);
--------------------------------------------------------------------------
--BATCH 4
-----------------------------------------------------------------------------
-- =======================================================
-- BULK PRODUCTS: ELECTRONICS (Bob's Store)
-- =======================================================

-- 1. Mechanical Keyboard
WITH inserted_product AS (
    INSERT INTO products (store_id, product_name, product_category_id, description, status, create_date)
    VALUES (
        (SELECT store_id FROM stores WHERE store_name = 'Bob''s Gadgets'),
        'RGB Mechanical Keyboard',
        (SELECT product_category_id FROM product_categories WHERE name = 'Electronics'),
        'Clicky mechanical switches with customizable backlighting.',
        'active',
        NOW() - INTERVAL '3 months'
    ) RETURNING product_id
)
INSERT INTO product_variants (product_id, variant_name, price, stock)
SELECT product_id, 'Blue Switch - Black', 79.99, 50 FROM inserted_product
UNION ALL
SELECT product_id, 'Red Switch - Black', 79.99, 45 FROM inserted_product
UNION ALL
SELECT product_id, 'Brown Switch - White', 84.99, 30 FROM inserted_product;

-- 2. 4K Monitor
WITH inserted_product AS (
    INSERT INTO products (store_id, product_name, product_category_id, description, status, create_date)
    VALUES (
        (SELECT store_id FROM stores WHERE store_name = 'Bob''s Gadgets'),
        'UltraClear 4K Monitor',
        (SELECT product_category_id FROM product_categories WHERE name = 'Electronics'),
        '27-inch display perfect for creative work.',
        'active',
        NOW() - INTERVAL '2 months'
    ) RETURNING product_id
)
INSERT INTO product_variants (product_id, variant_name, price, stock)
SELECT product_id, 'Standard Stand', 299.00, 15 FROM inserted_product
UNION ALL
SELECT product_id, 'Ergo Arm Bundle', 349.00, 10 FROM inserted_product;

-- 3. Noise Cancelling Headphones
WITH inserted_product AS (
    INSERT INTO products (store_id, product_name, product_category_id, description, status, create_date)
    VALUES (
        (SELECT store_id FROM stores WHERE store_name = 'Bob''s Gadgets'),
        'Silence Pro Headphones',
        (SELECT product_category_id FROM product_categories WHERE name = 'Electronics'),
        'Best-in-class active noise cancellation.',
        'active',
        NOW() - INTERVAL '1 month'
    ) RETURNING product_id
)
INSERT INTO product_variants (product_id, variant_name, price, stock)
SELECT product_id, 'Matte Black', 199.99, 100 FROM inserted_product
UNION ALL
SELECT product_id, 'Midnight Blue', 199.99, 80 FROM inserted_product;


-- =======================================================
-- BULK PRODUCTS: GARDEN & HOME (Sara's Store)
-- =======================================================

-- 4. Organic Fertilizer
WITH inserted_product AS (
    INSERT INTO products (store_id, product_name, product_category_id, description, status, create_date)
    VALUES (
        (SELECT store_id FROM stores WHERE store_name = 'Sara''s Garden World'),
        'SuperGrow Organic Fertilizer',
        (SELECT product_category_id FROM product_categories WHERE name = 'Home & Garden'),
        'Safe for pets and boosts plant growth.',
        'active',
        NOW() - INTERVAL '4 months'
    ) RETURNING product_id
)
INSERT INTO product_variants (product_id, variant_name, price, stock)
SELECT product_id, '1kg Bag', 12.50, 200 FROM inserted_product
UNION ALL
SELECT product_id, '5kg Sack', 45.00, 50 FROM inserted_product;

-- 5. Solar Garden Lights
WITH inserted_product AS (
    INSERT INTO products (store_id, product_name, product_category_id, description, status, create_date)
    VALUES (
        (SELECT store_id FROM stores WHERE store_name = 'Sara''s Garden World'),
        'Solar Pathway Lights',
        (SELECT product_category_id FROM product_categories WHERE name = 'Home & Garden'),
        'Waterproof LED lights that charge during the day.',
        'active',
        NOW() - INTERVAL '2 months'
    ) RETURNING product_id
)
INSERT INTO product_variants (product_id, variant_name, price, stock)
SELECT product_id, 'Warm White (Pack of 4)', 25.00, 60 FROM inserted_product
UNION ALL
SELECT product_id, 'Cool White (Pack of 4)', 25.00, 60 FROM inserted_product
UNION ALL
SELECT product_id, 'Multicolor (Pack of 4)', 28.00, 40 FROM inserted_product;

-- 6. Gardening Gloves
WITH inserted_product AS (
    INSERT INTO products (store_id, product_name, product_category_id, description, status, create_date)
    VALUES (
        (SELECT store_id FROM stores WHERE store_name = 'Sara''s Garden World'),
        'ToughTouch Gloves',
        (SELECT product_category_id FROM product_categories WHERE name = 'Home & Garden'),
        'Thorn-proof gloves for heavy duty work.',
        'active',
        NOW() - INTERVAL '5 months'
    ) RETURNING product_id
)
INSERT INTO product_variants (product_id, variant_name, price, stock)
SELECT product_id, 'Small', 9.99, 30 FROM inserted_product
UNION ALL
SELECT product_id, 'Medium', 9.99, 50 FROM inserted_product
UNION ALL
SELECT product_id, 'Large', 9.99, 40 FROM inserted_product
UNION ALL
SELECT product_id, 'Extra Large', 11.99, 20 FROM inserted_product;


-- =======================================================
-- BULK ORDERS: MIXED HISTORIES AND STATUSES
-- =======================================================

-- Order 1: Tech Guru buying a Keyboard (2 months ago, Received)
WITH new_order AS (
    INSERT INTO orders (user_id, store_id, shipping_address, shipping_ward, shipping_city, payment_method, order_status, create_date)
    VALUES ((SELECT user_id FROM users WHERE user_name = 'tech_guru'), (SELECT store_id FROM stores WHERE store_name = 'Bob''s Gadgets'), '99 Silicon Valley Dr', 'Ward 9', 'Da Nang', 'Online transaction', 'Approved by vendor', NOW() - INTERVAL '60 days') RETURNING order_id
)
INSERT INTO order_items (order_id, variant_id, item_quantity, price_at_purchase)
SELECT (SELECT order_id FROM new_order), (SELECT variant_id FROM product_variants WHERE variant_name = 'Blue Switch - Black' LIMIT 1), 1, 0;
INSERT INTO shipping_statuses (order_id, status, update_time)
SELECT order_id, 'received', NOW() - INTERVAL '50 days' FROM orders WHERE user_id = (SELECT user_id FROM users WHERE user_name = 'tech_guru') ORDER BY create_date DESC LIMIT 1;


-- Order 2: Tech Guru buying a Monitor (1 month ago, Received)
WITH new_order AS (
    INSERT INTO orders (user_id, store_id, shipping_address, shipping_ward, shipping_city, payment_method, order_status, create_date)
    VALUES ((SELECT user_id FROM users WHERE user_name = 'tech_guru'), (SELECT store_id FROM stores WHERE store_name = 'Bob''s Gadgets'), '99 Silicon Valley Dr', 'Ward 9', 'Da Nang', 'Online transaction', 'Approved by vendor', NOW() - INTERVAL '30 days') RETURNING order_id
)
INSERT INTO order_items (order_id, variant_id, item_quantity, price_at_purchase)
SELECT (SELECT order_id FROM new_order), (SELECT variant_id FROM product_variants WHERE variant_name = 'Ergo Arm Bundle' LIMIT 1), 1, 0;
INSERT INTO shipping_statuses (order_id, status, update_time)
SELECT order_id, 'received', NOW() - INTERVAL '25 days' FROM orders WHERE user_id = (SELECT user_id FROM users WHERE user_name = 'tech_guru') ORDER BY create_date DESC LIMIT 1;


-- Order 3: Fashion Fanatic buying Headphones (Yesterday, Shipped)
WITH new_order AS (
    INSERT INTO orders (user_id, store_id, shipping_address, shipping_ward, shipping_city, payment_method, order_status, create_date)
    VALUES ((SELECT user_id FROM users WHERE user_name = 'fashion_fanatic'), (SELECT store_id FROM stores WHERE store_name = 'Bob''s Gadgets'), '55 Runway Road', 'Ward 2', 'Ho Chi Minh City', 'Cash', 'Approved by vendor', NOW() - INTERVAL '1 day') RETURNING order_id
)
INSERT INTO order_items (order_id, variant_id, item_quantity, price_at_purchase)
SELECT (SELECT order_id FROM new_order), (SELECT variant_id FROM product_variants WHERE variant_name = 'Matte Black' LIMIT 1), 1, 0;
INSERT INTO shipping_statuses (order_id, status, update_time)
SELECT order_id, 'shipped', NOW() - INTERVAL '2 hours' FROM orders WHERE user_id = (SELECT user_id FROM users WHERE user_name = 'fashion_fanatic') ORDER BY create_date DESC LIMIT 1;


-- Order 4: Dave buying Fertilizer (3 months ago, Received)
WITH new_order AS (
    INSERT INTO orders (user_id, store_id, shipping_address, shipping_ward, shipping_city, payment_method, order_status, create_date)
    VALUES ((SELECT user_id FROM users WHERE user_name = 'customer_dave'), (SELECT store_id FROM stores WHERE store_name = 'Sara''s Garden World'), '777 Relax Road', 'Ward 10', 'Da Nang', 'Cash', 'Approved by vendor', NOW() - INTERVAL '90 days') RETURNING order_id
)
INSERT INTO order_items (order_id, variant_id, item_quantity, price_at_purchase)
SELECT (SELECT order_id FROM new_order), (SELECT variant_id FROM product_variants WHERE variant_name = '5kg Sack' LIMIT 1), 2, 0;
INSERT INTO shipping_statuses (order_id, status, update_time)
SELECT order_id, 'received', NOW() - INTERVAL '85 days' FROM orders WHERE user_id = (SELECT user_id FROM users WHERE user_name = 'customer_dave') ORDER BY create_date DESC LIMIT 1;


-- Order 5: Eve buying Lights (2 weeks ago, Received)
WITH new_order AS (
    INSERT INTO orders (user_id, store_id, shipping_address, shipping_ward, shipping_city, payment_method, order_status, create_date)
    VALUES ((SELECT user_id FROM users WHERE user_name = 'customer_eve'), (SELECT store_id FROM stores WHERE store_name = 'Sara''s Garden World'), '101 Fast Lane', 'Ward 1', 'Ho Chi Minh City', 'Online transaction', 'Approved by vendor', NOW() - INTERVAL '14 days') RETURNING order_id
)
INSERT INTO order_items (order_id, variant_id, item_quantity, price_at_purchase)
SELECT (SELECT order_id FROM new_order), (SELECT variant_id FROM product_variants WHERE variant_name = 'Warm White (Pack of 4)' LIMIT 1), 3, 0;
INSERT INTO shipping_statuses (order_id, status, update_time)
SELECT order_id, 'received', NOW() - INTERVAL '10 days' FROM orders WHERE user_id = (SELECT user_id FROM users WHERE user_name = 'customer_eve') ORDER BY create_date DESC LIMIT 1;


-- Order 6: Alice buying Gloves (Just now, Unresolved)
WITH new_order AS (
    INSERT INTO orders (user_id, store_id, shipping_address, shipping_ward, shipping_city, payment_method, order_status, create_date)
    VALUES ((SELECT user_id FROM users WHERE user_name = 'buyer_alice'), (SELECT store_id FROM stores WHERE store_name = 'Sara''s Garden World'), '456 User Lane', 'Ward 5', 'Hanoi', 'Cash', 'Unresolved', NOW()) RETURNING order_id
)
INSERT INTO order_items (order_id, variant_id, item_quantity, price_at_purchase)
SELECT (SELECT order_id FROM new_order), (SELECT variant_id FROM product_variants WHERE variant_name = 'Small' LIMIT 1), 1, 0;


-- Order 7: Alice buying Fertilizer + Gloves (Bulk, Unresolved)
WITH new_order AS (
    INSERT INTO orders (user_id, store_id, shipping_address, shipping_ward, shipping_city, payment_method, order_status, create_date)
    VALUES ((SELECT user_id FROM users WHERE user_name = 'buyer_alice'), (SELECT store_id FROM stores WHERE store_name = 'Sara''s Garden World'), '456 User Lane', 'Ward 5', 'Hanoi', 'Cash', 'Unresolved', NOW()) RETURNING order_id
)
INSERT INTO order_items (order_id, variant_id, item_quantity, price_at_purchase)
SELECT (SELECT order_id FROM new_order), (SELECT variant_id FROM product_variants WHERE variant_name = '1kg Bag' LIMIT 1), 5, 0
UNION ALL
SELECT (SELECT order_id FROM new_order), (SELECT variant_id FROM product_variants WHERE variant_name = 'Medium' LIMIT 1), 2, 0;


-- Order 8: Dave buying Headphones (Rejected by Vendor - Out of Stock simulation)
WITH new_order AS (
    INSERT INTO orders (user_id, store_id, shipping_address, shipping_ward, shipping_city, payment_method, order_status, create_date)
    VALUES ((SELECT user_id FROM users WHERE user_name = 'customer_dave'), (SELECT store_id FROM stores WHERE store_name = 'Bob''s Gadgets'), '777 Relax Road', 'Ward 10', 'Da Nang', 'Online transaction', 'Rejected by vendor', NOW() - INTERVAL '5 days') RETURNING order_id
)
INSERT INTO order_items (order_id, variant_id, item_quantity, price_at_purchase)
SELECT (SELECT order_id FROM new_order), (SELECT variant_id FROM product_variants WHERE variant_name = 'Midnight Blue' LIMIT 1), 1, 0;


-- Order 9: Eve buying Keyboard (Pending Approval)
WITH new_order AS (
    INSERT INTO orders (user_id, store_id, shipping_address, shipping_ward, shipping_city, payment_method, order_status, create_date)
    VALUES ((SELECT user_id FROM users WHERE user_name = 'customer_eve'), (SELECT store_id FROM stores WHERE store_name = 'Bob''s Gadgets'), '101 Fast Lane', 'Ward 1', 'Ho Chi Minh City', 'Online transaction', 'Unresolved', NOW() - INTERVAL '1 hour') RETURNING order_id
)
INSERT INTO order_items (order_id, variant_id, item_quantity, price_at_purchase)
SELECT (SELECT order_id FROM new_order), (SELECT variant_id FROM product_variants WHERE variant_name = 'Brown Switch - White' LIMIT 1), 1, 0;


-- Order 10: Tech Guru buying Solar Lights (Shipped)
WITH new_order AS (
    INSERT INTO orders (user_id, store_id, shipping_address, shipping_ward, shipping_city, payment_method, order_status, create_date)
    VALUES ((SELECT user_id FROM users WHERE user_name = 'tech_guru'), (SELECT store_id FROM stores WHERE store_name = 'Sara''s Garden World'), '99 Silicon Valley Dr', 'Ward 9', 'Da Nang', 'Online transaction', 'Approved by vendor', NOW() - INTERVAL '3 days') RETURNING order_id
)
INSERT INTO order_items (order_id, variant_id, item_quantity, price_at_purchase)
SELECT (SELECT order_id FROM new_order), (SELECT variant_id FROM product_variants WHERE variant_name = 'Multicolor (Pack of 4)' LIMIT 1), 2, 0;
INSERT INTO shipping_statuses (order_id, status, update_time)
SELECT order_id, 'shipped', NOW() - INTERVAL '1 day' FROM orders WHERE user_id = (SELECT user_id FROM users WHERE user_name = 'tech_guru') ORDER BY create_date DESC LIMIT 1;
-- =======================================================
-- BATCH 5: PURE ORDER VOLUME
-- =======================================================

-- 1. CROSS-STORE PURCHASE: Bob (Store Owner) buying from Sara
-- Bob needs plants for his shop. 10 Pots.
WITH new_order AS (
    INSERT INTO orders (user_id, store_id, shipping_address, shipping_ward, shipping_city, payment_method, order_status, create_date)
    VALUES ((SELECT user_id FROM users WHERE user_name = 'store_owner_bob'), (SELECT store_id FROM stores WHERE store_name = 'Sara''s Garden World'), '123 Tech Street', 'Ward 1', 'Ho Chi Minh City', 'Online transaction', 'Approved by vendor', NOW() - INTERVAL '5 months') RETURNING order_id
)
INSERT INTO order_items (order_id, variant_id, item_quantity, price_at_purchase)
SELECT (SELECT order_id FROM new_order), (SELECT variant_id FROM product_variants WHERE variant_name = 'Medium - Blue' LIMIT 1), 10, 0; 
-- Update Shipping
INSERT INTO shipping_statuses (order_id, status, update_time)
SELECT order_id, 'received', NOW() - INTERVAL '140 days' FROM orders WHERE user_id = (SELECT user_id FROM users WHERE user_name = 'store_owner_bob') ORDER BY create_date DESC LIMIT 1;


-- 2. BULK BUY: Alice buying 20 T-Shirts (Team Event)
WITH new_order AS (
    INSERT INTO orders (user_id, store_id, shipping_address, shipping_ward, shipping_city, payment_method, order_status, create_date)
    VALUES ((SELECT user_id FROM users WHERE user_name = 'buyer_alice'), (SELECT store_id FROM stores WHERE store_name = 'Bob''s Gadgets'), '456 User Lane', 'Ward 5', 'Hanoi', 'Cash', 'Approved by vendor', NOW() - INTERVAL '1 week') RETURNING order_id
)
INSERT INTO order_items (order_id, variant_id, item_quantity, price_at_purchase)
SELECT (SELECT order_id FROM new_order), (SELECT variant_id FROM product_variants WHERE variant_name = 'Large - White' LIMIT 1), 20, 0;
-- Update Shipping
INSERT INTO shipping_statuses (order_id, status, update_time)
SELECT order_id, 'shipped', NOW() - INTERVAL '6 days' FROM orders WHERE user_id = (SELECT user_id FROM users WHERE user_name = 'buyer_alice') ORDER BY create_date DESC LIMIT 1;


-- 3. REJECTED ORDER: Dave trying to buy too many Headphones (Stock issue simulation)
WITH new_order AS (
    INSERT INTO orders (user_id, store_id, shipping_address, shipping_ward, shipping_city, payment_method, order_status, create_date)
    VALUES ((SELECT user_id FROM users WHERE user_name = 'customer_dave'), (SELECT store_id FROM stores WHERE store_name = 'Bob''s Gadgets'), '777 Relax Road', 'Ward 10', 'Da Nang', 'Online transaction', 'Rejected by vendor', NOW() - INTERVAL '2 days') RETURNING order_id
)
INSERT INTO order_items (order_id, variant_id, item_quantity, price_at_purchase)
SELECT (SELECT order_id FROM new_order), (SELECT variant_id FROM product_variants WHERE variant_name = 'Matte Black' LIMIT 1), 50, 0;


-- 4. COMPLEX GARDEN SETUP: Eve buying Lights + Fertilizer + Gloves
WITH new_order AS (
    INSERT INTO orders (user_id, store_id, shipping_address, shipping_ward, shipping_city, payment_method, order_status, create_date)
    VALUES ((SELECT user_id FROM users WHERE user_name = 'customer_eve'), (SELECT store_id FROM stores WHERE store_name = 'Sara''s Garden World'), '101 Fast Lane', 'Ward 1', 'Ho Chi Minh City', 'Cash', 'Unresolved', NOW() - INTERVAL '3 hours') RETURNING order_id
)
INSERT INTO order_items (order_id, variant_id, item_quantity, price_at_purchase)
SELECT (SELECT order_id FROM new_order), (SELECT variant_id FROM product_variants WHERE variant_name = 'Cool White (Pack of 4)' LIMIT 1), 2, 0
UNION ALL
SELECT (SELECT order_id FROM new_order), (SELECT variant_id FROM product_variants WHERE variant_name = '5kg Sack' LIMIT 1), 1, 0
UNION ALL
SELECT (SELECT order_id FROM new_order), (SELECT variant_id FROM product_variants WHERE variant_name = 'Medium' LIMIT 1), 2, 0;


-- 5. OFFICE UPGRADE: Tech Guru buying 5 Monitors
WITH new_order AS (
    INSERT INTO orders (user_id, store_id, shipping_address, shipping_ward, shipping_city, payment_method, order_status, create_date)
    VALUES ((SELECT user_id FROM users WHERE user_name = 'tech_guru'), (SELECT store_id FROM stores WHERE store_name = 'Bob''s Gadgets'), '99 Silicon Valley Dr', 'Ward 9', 'Da Nang', 'Online transaction', 'Approved by vendor', NOW() - INTERVAL '10 days') RETURNING order_id
)
INSERT INTO order_items (order_id, variant_id, item_quantity, price_at_purchase)
SELECT (SELECT order_id FROM new_order), (SELECT variant_id FROM product_variants WHERE variant_name = 'Standard Stand' LIMIT 1), 5, 0;
-- Update Shipping
INSERT INTO shipping_statuses (order_id, status, update_time)
SELECT order_id, 'shipped', NOW() - INTERVAL '9 days' FROM orders WHERE user_id = (SELECT user_id FROM users WHERE user_name = 'tech_guru') ORDER BY create_date DESC LIMIT 1;


-- 6. FASHION HAUL: Harry buying Hoodies (Different colors)
WITH new_order AS (
    INSERT INTO orders (user_id, store_id, shipping_address, shipping_ward, shipping_city, payment_method, order_status, create_date)
    VALUES ((SELECT user_id FROM users WHERE user_name = 'fashion_fanatic'), (SELECT store_id FROM stores WHERE store_name = 'Sara''s Garden World'), '55 Runway Road', 'Ward 2', 'Ho Chi Minh City', 'Online transaction', 'Approved by vendor', NOW() - INTERVAL '20 days') RETURNING order_id
)
INSERT INTO order_items (order_id, variant_id, item_quantity, price_at_purchase)
SELECT (SELECT order_id FROM new_order), (SELECT variant_id FROM product_variants WHERE variant_name = 'Large - Earth Green' LIMIT 1), 1, 0
UNION ALL
SELECT (SELECT order_id FROM new_order), (SELECT variant_id FROM product_variants WHERE variant_name = 'Large - Clay Red' LIMIT 1), 1, 0;
-- Update Shipping
INSERT INTO shipping_statuses (order_id, status, update_time)
SELECT order_id, 'received', NOW() - INTERVAL '15 days' FROM orders WHERE user_id = (SELECT user_id FROM users WHERE user_name = 'fashion_fanatic') ORDER BY create_date DESC LIMIT 1;


-- 7. SMALL ACCESSORY: Alice buying a Mouse
WITH new_order AS (
    INSERT INTO orders (user_id, store_id, shipping_address, shipping_ward, shipping_city, payment_method, order_status, create_date)
    VALUES ((SELECT user_id FROM users WHERE user_name = 'buyer_alice'), (SELECT store_id FROM stores WHERE store_name = 'Bob''s Gadgets'), '456 User Lane', 'Ward 5', 'Hanoi', 'Cash', 'Unresolved', NOW()) RETURNING order_id
)
INSERT INTO order_items (order_id, variant_id, item_quantity, price_at_purchase)
SELECT (SELECT order_id FROM new_order), (SELECT variant_id FROM product_variants WHERE variant_name = 'RGB - Wired' LIMIT 1), 1, 0;


-- 8. COMPLAINT FILED: Harry received wrong shelf part
WITH new_order AS (
    INSERT INTO orders (user_id, store_id, shipping_address, shipping_ward, shipping_city, payment_method, order_status, create_date)
    VALUES ((SELECT user_id FROM users WHERE user_name = 'fashion_fanatic'), (SELECT store_id FROM stores WHERE store_name = 'Bob''s Gadgets'), '55 Runway Road', 'Ward 2', 'Ho Chi Minh City', 'Online transaction', 'Complaint filed', NOW() - INTERVAL '5 days') RETURNING order_id
)
INSERT INTO order_items (order_id, variant_id, item_quantity, price_at_purchase)
SELECT (SELECT order_id FROM new_order), (SELECT variant_id FROM product_variants WHERE variant_name = 'Add-on: Glass Door' LIMIT 1), 2, 0;
-- Update Shipping
INSERT INTO shipping_statuses (order_id, status, update_time)
SELECT order_id, 'received', NOW() - INTERVAL '1 day' FROM orders WHERE user_id = (SELECT user_id FROM users WHERE user_name = 'fashion_fanatic') ORDER BY create_date DESC LIMIT 1;


-- 9. HISTORICAL: Eve buying a Phone (Last Year)
WITH new_order AS (
    INSERT INTO orders (user_id, store_id, shipping_address, shipping_ward, shipping_city, payment_method, order_status, create_date)
    VALUES ((SELECT user_id FROM users WHERE user_name = 'customer_eve'), (SELECT store_id FROM stores WHERE store_name = 'Bob''s Gadgets'), '101 Fast Lane', 'Ward 1', 'Ho Chi Minh City', 'Cash', 'Approved by vendor', NOW() - INTERVAL '360 days') RETURNING order_id
)
INSERT INTO order_items (order_id, variant_id, item_quantity, price_at_purchase)
SELECT (SELECT order_id FROM new_order), (SELECT variant_id FROM product_variants WHERE variant_name = '256GB - Silver' LIMIT 1), 1, 0;
-- Update Shipping
INSERT INTO shipping_statuses (order_id, status, update_time)
SELECT order_id, 'received', NOW() - INTERVAL '355 days' FROM orders WHERE user_id = (SELECT user_id FROM users WHERE user_name = 'customer_eve') ORDER BY create_date DESC LIMIT 1;


-- 10. BULK FERTILIZER: Dave (Professional Landscaper scenario)
WITH new_order AS (
    INSERT INTO orders (user_id, store_id, shipping_address, shipping_ward, shipping_city, payment_method, order_status, create_date)
    VALUES ((SELECT user_id FROM users WHERE user_name = 'customer_dave'), (SELECT store_id FROM stores WHERE store_name = 'Sara''s Garden World'), '777 Relax Road', 'Ward 10', 'Da Nang', 'Cash', 'Approved by vendor', NOW() - INTERVAL '2 months') RETURNING order_id
)
INSERT INTO order_items (order_id, variant_id, item_quantity, price_at_purchase)
SELECT (SELECT order_id FROM new_order), (SELECT variant_id FROM product_variants WHERE variant_name = '5kg Sack' LIMIT 1), 15, 0;
INSERT INTO shipping_statuses (order_id, status, update_time)
SELECT order_id, 'received', NOW() - INTERVAL '55 days' FROM orders WHERE user_id = (SELECT user_id FROM users WHERE user_name = 'customer_dave') ORDER BY create_date DESC LIMIT 1;


-- 11. MIXED CART: Tech Guru buying Keyboard + Gloves (Odd combination)
WITH new_order AS (
    INSERT INTO orders (user_id, store_id, shipping_address, shipping_ward, shipping_city, payment_method, order_status, create_date)
    VALUES ((SELECT user_id FROM users WHERE user_name = 'tech_guru'), (SELECT store_id FROM stores WHERE store_name = 'Sara''s Garden World'), '99 Silicon Valley Dr', 'Ward 9', 'Da Nang', 'Online transaction', 'Approved by vendor', NOW() - INTERVAL '4 days') RETURNING order_id
)
INSERT INTO order_items (order_id, variant_id, item_quantity, price_at_purchase)
SELECT (SELECT order_id FROM new_order), (SELECT variant_id FROM product_variants WHERE variant_name = 'Extra Large' LIMIT 1), 2, 0
UNION ALL
SELECT (SELECT order_id FROM new_order), (SELECT variant_id FROM product_variants WHERE variant_name = 'Small - Earth Green' LIMIT 1), 1, 0; -- Buying a Hoodie from the Garden store
INSERT INTO shipping_statuses (order_id, status, update_time)
SELECT order_id, 'shipped', NOW() - INTERVAL '3 days' FROM orders WHERE user_id = (SELECT user_id FROM users WHERE user_name = 'tech_guru') ORDER BY create_date DESC LIMIT 1;


-- 12. PENDING ORDER: Alice buying Shelf
WITH new_order AS (
    INSERT INTO orders (user_id, store_id, shipping_address, shipping_ward, shipping_city, payment_method, order_status, create_date)
    VALUES ((SELECT user_id FROM users WHERE user_name = 'buyer_alice'), (SELECT store_id FROM stores WHERE store_name = 'Bob''s Gadgets'), '456 User Lane', 'Ward 5', 'Hanoi', 'Online transaction', 'Unresolved', NOW() - INTERVAL '30 minutes') RETURNING order_id
)
INSERT INTO order_items (order_id, variant_id, item_quantity, price_at_purchase)
SELECT (SELECT order_id FROM new_order), (SELECT variant_id FROM product_variants WHERE variant_name = '3-Tier Standard' LIMIT 1), 1, 0;


-- 13. BULK LIGHTS: Bob buying lights for his store decoration from Sara
WITH new_order AS (
    INSERT INTO orders (user_id, store_id, shipping_address, shipping_ward, shipping_city, payment_method, order_status, create_date)
    VALUES ((SELECT user_id FROM users WHERE user_name = 'store_owner_bob'), (SELECT store_id FROM stores WHERE store_name = 'Sara''s Garden World'), '123 Tech Street', 'Ward 1', 'Ho Chi Minh City', 'Cash', 'Approved by vendor', NOW() - INTERVAL '1 month') RETURNING order_id
)
INSERT INTO order_items (order_id, variant_id, item_quantity, price_at_purchase)
SELECT (SELECT order_id FROM new_order), (SELECT variant_id FROM product_variants WHERE variant_name = 'Warm White (Pack of 4)' LIMIT 1), 5, 0;
INSERT INTO shipping_statuses (order_id, status, update_time)
SELECT order_id, 'received', NOW() - INTERVAL '25 days' FROM orders WHERE user_id = (SELECT user_id FROM users WHERE user_name = 'store_owner_bob') ORDER BY create_date DESC LIMIT 1;


-- 14. SINGLE ITEM: Dave buying 1 T-Shirt
WITH new_order AS (
    INSERT INTO orders (user_id, store_id, shipping_address, shipping_ward, shipping_city, payment_method, order_status, create_date)
    VALUES ((SELECT user_id FROM users WHERE user_name = 'customer_dave'), (SELECT store_id FROM stores WHERE store_name = 'Bob''s Gadgets'), '777 Relax Road', 'Ward 10', 'Da Nang', 'Cash', 'Unresolved', NOW()) RETURNING order_id
)
INSERT INTO order_items (order_id, variant_id, item_quantity, price_at_purchase)
SELECT (SELECT order_id FROM new_order), (SELECT variant_id FROM product_variants WHERE variant_name = 'Large - White' LIMIT 1), 1, 0;
-- =======================================================
-- BATCH 6: BULK REVIEWS & REPLIES
-- =======================================================

-- 1. AUTO-GENERATE POSITIVE REVIEWS
-- Finds items bought by users that DO NOT have a review yet.
-- Assigns a random 4 or 5 star rating.
INSERT INTO reviews (user_id, product_id, rating, comment, create_date)
SELECT DISTINCT 
    o.user_id,
    pv.product_id,
    (FLOOR(RANDOM() * 2) + 4)::INT as rating, -- Generates 4 or 5
    CASE (FLOOR(RANDOM() * 4))::INT
        WHEN 0 THEN 'Absolutely love this product! Highly recommended.'
        WHEN 1 THEN 'Great quality for the price. Fast shipping too.'
        WHEN 2 THEN 'Exactly as described. Will buy again.'
        ELSE 'Five stars! Exceeded my expectations.'
    END as comment,
    o.create_date + INTERVAL '5 days' -- Review posted 5 days after order
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN product_variants pv ON oi.variant_id = pv.variant_id
WHERE o.order_status = 'Approved by vendor' -- Only review approved orders
  AND NOT EXISTS (
      SELECT 1 FROM reviews r 
      WHERE r.user_id = o.user_id AND r.product_id = pv.product_id
  )
LIMIT 15; -- Generate 15 positive reviews for available purchases


-- 2. AUTO-GENERATE CRITICAL REVIEWS
-- Focuses on items where the user might have been less satisfied
-- (Simulated by just picking different random rows)
INSERT INTO reviews (user_id, product_id, rating, comment, create_date)
SELECT DISTINCT 
    o.user_id,
    pv.product_id,
    (FLOOR(RANDOM() * 2) + 1)::INT as rating, -- Generates 1 or 2
    CASE (FLOOR(RANDOM() * 3))::INT
        WHEN 0 THEN 'Not what I expected. The color is off.'
        WHEN 1 THEN 'Shipping took way too long and item arrived dusty.'
        ELSE 'Quality is poor. I want a refund.'
    END as comment,
    o.create_date + INTERVAL '10 days'
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN product_variants pv ON oi.variant_id = pv.variant_id
WHERE o.order_status = 'Approved by vendor' 
  AND NOT EXISTS (
      SELECT 1 FROM reviews r 
      WHERE r.user_id = o.user_id AND r.product_id = pv.product_id
  )
LIMIT 5; -- Generate 5 critical reviews


-- 3. SPECIFIC REVIEW: Tech Guru reviewing the Keyboard
-- (Explicit insert for a specific scenario created in previous batch)
INSERT INTO reviews (user_id, product_id, rating, comment, create_date)
SELECT 
    (SELECT user_id FROM users WHERE user_name = 'tech_guru'),
    (SELECT product_id FROM products WHERE product_name = 'RGB Mechanical Keyboard'),
    5,
    'The tactile feedback on the Blue switches is incredibly satisfying. My coding speed has improved!',
    NOW() - INTERVAL '45 days'
WHERE EXISTS (
    SELECT 1 FROM orders o 
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN product_variants pv ON oi.variant_id = pv.variant_id
    JOIN products p ON pv.product_id = p.product_id
    WHERE o.user_id = (SELECT user_id FROM users WHERE user_name = 'tech_guru')
      AND p.product_name = 'RGB Mechanical Keyboard'
)
AND NOT EXISTS (
    SELECT 1 FROM reviews 
    WHERE user_id = (SELECT user_id FROM users WHERE user_name = 'tech_guru')
    AND product_id = (SELECT product_id FROM products WHERE product_name = 'RGB Mechanical Keyboard')
);


-- 4. BULK REPLIES FROM STORE OWNERS
-- Store owners reply to reviews on their own products.

-- A. Reply to Low Ratings (1 or 2 stars) with an apology
INSERT INTO replies (user_id, review_id, comment, create_date)
SELECT 
    s.user_id, -- The store owner
    r.review_id,
    'We are so sorry to hear this! Please contact us directly so we can make it right.',
    r.create_date + INTERVAL '1 day'
FROM reviews r
JOIN products p ON r.product_id = p.product_id
JOIN stores s ON p.store_id = s.store_id
WHERE r.rating <= 2
  AND NOT EXISTS (SELECT 1 FROM replies rep WHERE rep.review_id = r.review_id);

-- B. Reply to High Ratings (5 stars) with thanks
INSERT INTO replies (user_id, review_id, comment, create_date)
SELECT 
    s.user_id, -- The store owner
    r.review_id,
    'Thank you for your kind words! We hope to see you again soon.',
    r.create_date + INTERVAL '2 hours'
FROM reviews r
JOIN products p ON r.product_id = p.product_id
JOIN stores s ON p.store_id = s.store_id
WHERE r.rating = 5
  AND NOT EXISTS (SELECT 1 FROM replies rep WHERE rep.review_id = r.review_id)
LIMIT 10; -- Cap the automated 'thank you' notes

-- =======================================================
-- BATCH 7: NEGATIVE & CRITICAL REVIEWS
-- =======================================================

-- 1. TARGETED ANGER: Reviews for orders with complaints
-- If a user filed a complaint, they are very likely to leave a 1-star review.
INSERT INTO reviews (user_id, product_id, rating, comment, create_date)
SELECT DISTINCT 
    o.user_id,
    pv.product_id,
    1, -- Force 1 Star
    CASE (FLOOR(RANDOM() * 3))::INT
        WHEN 0 THEN 'Do not buy! The item arrived completely broken and the seller is refusing to refund.'
        WHEN 1 THEN 'Horrible experience. I filed a complaint weeks ago and still no resolution.'
        ELSE 'Scam alert. The product looks nothing like the pictures.'
    END,
    o.create_date + INTERVAL '10 days'
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN product_variants pv ON oi.variant_id = pv.variant_id
WHERE o.order_status IN ('Complaint filed', 'Complaint resolved') -- Target unhappy users
  AND o.order_status != 'Rejected by vendor' -- Trigger requirement
  AND NOT EXISTS (
      SELECT 1 FROM reviews r 
      WHERE r.user_id = o.user_id AND r.product_id = pv.product_id
  );


-- 2. GENERAL DISSATISFACTION: 2-Star Reviews (Random Orders)
-- People who received the item but hate it.
INSERT INTO reviews (user_id, product_id, rating, comment, create_date)
SELECT DISTINCT 
    o.user_id,
    pv.product_id,
    2, -- Force 2 Stars
    CASE (FLOOR(RANDOM() * 3))::INT
        WHEN 0 THEN 'Quality is very cheap plastic. Feels like it will break immediately.'
        WHEN 1 THEN 'Smaller than expected. Check the dimensions carefully before buying.'
        ELSE 'Shipping took forever. The product is okay but not worth the wait.'
    END,
    o.create_date + INTERVAL '7 days'
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN product_variants pv ON oi.variant_id = pv.variant_id
WHERE o.order_status NOT IN ('Rejected by vendor')
  AND NOT EXISTS (
      SELECT 1 FROM reviews r 
      WHERE r.user_id = o.user_id AND r.product_id = pv.product_id
  )
LIMIT 8; -- limit to 8 new bad reviews


-- 3. MEDIOCRE FEEDBACK: 3-Star Reviews
-- "It's okay, but..."
INSERT INTO reviews (user_id, product_id, rating, comment, create_date)
SELECT DISTINCT 
    o.user_id,
    pv.product_id,
    3, -- Force 3 Stars
    CASE (FLOOR(RANDOM() * 3))::INT
        WHEN 0 THEN 'It does the job, but I have seen better quality elsewhere.'
        WHEN 1 THEN 'Average product. Good for the price point I guess.'
        ELSE 'Mixed feelings. It works, but the packaging was damaged.'
    END,
    o.create_date + INTERVAL '14 days'
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN product_variants pv ON oi.variant_id = pv.variant_id
WHERE o.order_status NOT IN ('Rejected by vendor')
  AND NOT EXISTS (
      SELECT 1 FROM reviews r 
      WHERE r.user_id = o.user_id AND r.product_id = pv.product_id
  )
LIMIT 8;


-- 4. DAMAGE CONTROL: Store Owner Replies
-- Store owners replying SPECIFICALLY to these new 1-star reviews.
INSERT INTO replies (user_id, review_id, comment, create_date)
SELECT 
    s.user_id,
    r.review_id,
    CASE (FLOOR(RANDOM() * 2))::INT
        WHEN 0 THEN 'We sincerely apologize for this experience. Please check your DMs so we can process a refund immediately.'
        ELSE 'This is not the standard we strive for. Please contact support referencing your Order ID.'
    END,
    r.create_date + INTERVAL '1 day'
FROM reviews r
JOIN products p ON r.product_id = p.product_id
JOIN stores s ON p.store_id = s.store_id
WHERE r.rating = 1 -- Only replying to the worst reviews
  AND r.create_date > (NOW() - INTERVAL '1 day') -- Only reply to the ones we just inserted (approx)
  AND NOT EXISTS (SELECT 1 FROM replies rep WHERE rep.review_id = r.review_id);
  
-- =======================================================
-- BATCH 8: POSITIVE REVIEWS (4-5 STARS)
-- =======================================================

-- 1. ENTHUSIASTIC CUSTOMERS (5 Stars)
-- Selects users who bought items but haven't reviewed them yet.
INSERT INTO reviews (user_id, product_id, rating, comment, create_date)
SELECT DISTINCT 
    o.user_id,
    pv.product_id,
    5, -- Force 5 Stars
    CASE (FLOOR(RANDOM() * 5))::INT
        WHEN 0 THEN 'Absolutely perfect! The quality is unmatched.'
        WHEN 1 THEN 'Five stars! Arrived earlier than expected and works like a charm.'
        WHEN 2 THEN 'I am so happy with this purchase. Will definitely buy from this store again.'
        WHEN 3 THEN 'Best investment I have made this year. Highly recommended!'
        ELSE 'Simply amazing. Exceeded all my expectations.'
    END,
    o.create_date + INTERVAL '3 days' -- Quick review after purchase
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN product_variants pv ON oi.variant_id = pv.variant_id
WHERE o.order_status IN ('Approved by vendor', 'Complaint resolved') 
  AND o.order_status != 'Rejected by vendor'
  AND NOT EXISTS (
      SELECT 1 FROM reviews r 
      WHERE r.user_id = o.user_id AND r.product_id = pv.product_id
  )
LIMIT 12; -- Generate 12 new 5-star reviews


-- 2. SATISFIED CUSTOMERS (4 Stars)
-- Good products, minor nitpicks or just "Good"
INSERT INTO reviews (user_id, product_id, rating, comment, create_date)
SELECT DISTINCT 
    o.user_id,
    pv.product_id,
    4, -- Force 4 Stars
    CASE (FLOOR(RANDOM() * 3))::INT
        WHEN 0 THEN 'Great product, but the packaging could be better.'
        WHEN 1 THEN 'Solid performance for the price. I give it a 4/5.'
        ELSE 'Really good item. Matches the description well.'
    END,
    o.create_date + INTERVAL '7 days'
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN product_variants pv ON oi.variant_id = pv.variant_id
WHERE o.order_status IN ('Approved by vendor', 'Complaint resolved')
  AND o.order_status != 'Rejected by vendor'
  AND NOT EXISTS (
      SELECT 1 FROM reviews r 
      WHERE r.user_id = o.user_id AND r.product_id = pv.product_id
  )
LIMIT 8; -- Generate 8 new 4-star reviews


-- 3. STORE OWNER APPRECIATION (Replies)
-- Store owners replying to the reviews we just created (filtering by recent dates/high ratings)
INSERT INTO replies (user_id, review_id, comment, create_date)
SELECT 
    s.user_id, -- The Store Owner
    r.review_id,
    CASE (FLOOR(RANDOM() * 3))::INT
        WHEN 0 THEN 'Thank you for the wonderful feedback! We are glad you love it.'
        WHEN 1 THEN 'Thanks for supporting our small business!'
        ELSE 'We appreciate the high rating! Let us know if you need anything else.'
    END,
    r.create_date + INTERVAL '6 hours'
FROM reviews r
JOIN products p ON r.product_id = p.product_id
JOIN stores s ON p.store_id = s.store_id
WHERE r.rating >= 4 -- Only reply to positive reviews
  AND NOT EXISTS (SELECT 1 FROM replies rep WHERE rep.review_id = r.review_id)
LIMIT 10;
-- =======================================================
-- BATCH 9: VARIOUS SERIOUS REPORTS
-- Logic: Reports are for serious offenses/escalations, not just refunds.
-- =======================================================

-- 1. FRAUD (Escalation of a Refund)
-- Alice tried to get a refund via the Complaint system, but the store rejected it unreasonably.
-- She is now reporting the store for Fraud.
INSERT INTO reports (report_category_id, user_id, store_id, comment, admin_note, resolved_status, create_date, admin_id)
VALUES (
    (SELECT report_category_id FROM report_categories WHERE name = 'Fraud'),
    (SELECT user_id FROM users WHERE user_name = 'buyer_alice'),
    (SELECT store_id FROM stores WHERE store_name = 'Bob''s Gadgets'),
    'I filed a complaint about a fake product (Order #105), but the seller rejected it claiming "No Refunds" despite the policy. They are knowingly selling counterfeits.',
    'Verified product images. Seller clearly violated counterfeit policy. Refund forced and warning issued.',
    'Resolved',
    NOW() - INTERVAL '2 months',
    (SELECT user_id FROM users WHERE user_name = 'admin_user') -- Admin handled this
);


-- 2. HARASSMENT / INAPPROPRIATE CONTENT
-- Eve is reporting abusive behavior (Personal attack).
INSERT INTO reports (report_category_id, user_id, store_id, comment, admin_note, resolved_status, create_date, admin_id)
VALUES (
    (SELECT report_category_id FROM report_categories WHERE name = 'Inappropriate Content'),
    (SELECT user_id FROM users WHERE user_name = 'customer_eve'),
    (SELECT store_id FROM stores WHERE store_name = 'Bob''s Gadgets'),
    'After I left a 3-star review, the store owner sent me a message calling me "stupid" and "poor". This is harassment.',
    'Reviewing chat logs. User temporarily suspended pending investigation.',
    'Pending Review',
    NOW() - INTERVAL '2 days',
    (SELECT user_id FROM users WHERE user_name = 'admin_user')
);


-- 3. SPAM / PRIVACY VIOLATION
-- Dave reports Sara's Garden for taking communication off-platform (Serious offense).
INSERT INTO reports (report_category_id, user_id, store_id, comment, admin_note, resolved_status, create_date, admin_id)
VALUES (
    (SELECT report_category_id FROM report_categories WHERE name = 'Spam'),
    (SELECT user_id FROM users WHERE user_name = 'customer_dave'),
    (SELECT store_id FROM stores WHERE store_name = 'Sara''s Garden World'),
    'The seller took my phone number from the shipping label and is now texting my personal phone with advertisements for their new website.',
    'Confirmed. Seller warned about data privacy violation.',
    'Resolved',
    NOW() - INTERVAL '1 month',
    (SELECT user_id FROM users WHERE user_name = 'admin_user')
);


-- 4. FRAUD (Non-Delivery / Ghosting)
-- Tech Guru claims the store took money and disappeared (ignoring complaints).
INSERT INTO reports (report_category_id, user_id, store_id, comment, resolved_status, create_date, admin_id)
VALUES (
    (SELECT report_category_id FROM report_categories WHERE name = 'Fraud'),
    (SELECT user_id FROM users WHERE user_name = 'tech_guru'),
    (SELECT store_id FROM stores WHERE store_name = 'Sara''s Garden World'),
    'I filed a complaint 3 weeks ago about a missing item. The seller marked the complaint as "Resolved" without replying or refunding me.',
    'Unresolved',
    NOW() - INTERVAL '4 hours',
    NULL -- New report, no admin assigned yet
);


-- 5. OTHER (Policy Violation - Prohibited Items)
-- Harry reports a listing that violates site rules (not a refund issue, but a safety issue).
INSERT INTO reports (report_category_id, user_id, store_id, comment, admin_note, resolved_status, create_date, admin_id)
VALUES (
    (SELECT report_category_id FROM report_categories WHERE name = 'Other'),
    (SELECT user_id FROM users WHERE user_name = 'fashion_fanatic'),
    (SELECT store_id FROM stores WHERE store_name = 'Bob''s Gadgets'),
    'This store is listing "Laser Pointers" categorized as "Toys", but they are high-powered industrial lasers. This is dangerous and against safety guidelines.',
    'Listing removed.',
    'Closed',
    NOW() - INTERVAL '1 week',
    (SELECT user_id FROM users WHERE user_name = 'admin_user')
);


-- 6. INAPPROPRIATE CONTENT (Coercion)
-- Alice reports the seller for trying to manipulate reviews.
INSERT INTO reports (report_category_id, user_id, store_id, comment, resolved_status, create_date, admin_id)
VALUES (
    (SELECT report_category_id FROM report_categories WHERE name = 'Inappropriate Content'),
    (SELECT user_id FROM users WHERE user_name = 'buyer_alice'),
    (SELECT store_id FROM stores WHERE store_name = 'Bob''s Gadgets'),
    'Seller offered to pay me $20 via PayPal if I delete my negative review. I believe review manipulation is against the rules.',
    'Unresolved',
    NOW() - INTERVAL '30 minutes',
    NULL
);
-- =======================================================
-- BATCH 10: BULK COMPLAINTS (Refunds, Returns, Issues)
-- =======================================================

-- 1. SHIPPING DELAY (Active Complaint)
-- Alice complains that her order hasn't arrived.
WITH target_order AS (
    SELECT order_id, user_id 
    FROM orders 
    WHERE user_id = (SELECT user_id FROM users WHERE user_name = 'buyer_alice')
      AND order_status IN ('Approved by vendor', 'Unresolved') -- Valid states to complain from
    ORDER BY create_date DESC 
    LIMIT 1
),
insert_complaint AS (
    INSERT INTO complaints (user_id, order_id, comment, create_date)
    SELECT 
        user_id, 
        order_id, 
        'It has been 10 days since I placed the order and the status still says Unresolved. Please cancel and refund.',
        NOW()
    FROM target_order
)
-- Update the order status to reflect the active complaint
UPDATE orders 
SET order_status = 'Complaint filed' 
WHERE order_id = (SELECT order_id FROM target_order);


-- 2. DAMAGED ITEM (Active Complaint)
-- Dave received a broken garden pot.
WITH target_order AS (
    SELECT order_id, user_id 
    FROM orders 
    WHERE user_id = (SELECT user_id FROM users WHERE user_name = 'customer_dave')
      AND store_id = (SELECT store_id FROM stores WHERE store_name = 'Sara''s Garden World')
    ORDER BY create_date DESC 
    LIMIT 1
),
insert_complaint AS (
    INSERT INTO complaints (user_id, order_id, comment, create_date)
    SELECT 
        user_id, 
        order_id, 
        'The ceramic pot arrived shattered. The box was clearly crushed during shipping. I have attached photos.',
        NOW() - INTERVAL '2 hours'
    FROM target_order
)
UPDATE orders 
SET order_status = 'Complaint filed' 
WHERE order_id = (SELECT order_id FROM target_order);


-- 3. WRONG ITEM (Resolved Complaint)
-- Fashion Fanatic received the wrong color, but the issue is already resolved (Refunded/Exchanged).
WITH target_order AS (
    SELECT order_id, user_id 
    FROM orders 
    WHERE user_id = (SELECT user_id FROM users WHERE user_name = 'fashion_fanatic')
    ORDER BY create_date DESC 
    LIMIT 1
),
insert_complaint AS (
    INSERT INTO complaints (user_id, order_id, comment, create_date)
    SELECT 
        user_id, 
        order_id, 
        'I ordered the Earth Green hoodie but received Clay Red. I would like an exchange.',
        NOW() - INTERVAL '5 days'
    FROM target_order
)
UPDATE orders 
SET order_status = 'Complaint resolved' 
WHERE order_id = (SELECT order_id FROM target_order);


-- 4. MISSING PART (Active Complaint)
-- Tech Guru bought a shelf but it's missing screws.
WITH target_order AS (
    SELECT order_id, user_id 
    FROM orders 
    WHERE user_id = (SELECT user_id FROM users WHERE user_name = 'tech_guru')
      AND store_id = (SELECT store_id FROM stores WHERE store_name = 'Bob''s Gadgets')
    ORDER BY create_date DESC 
    LIMIT 1
),
insert_complaint AS (
    INSERT INTO complaints (user_id, order_id, comment, create_date)
    SELECT 
        user_id, 
        order_id, 
        'The package was sealed but the bag of screws for the shelf is missing. I cannot assemble it.',
        NOW() - INTERVAL '1 day'
    FROM target_order
)
UPDATE orders 
SET order_status = 'Complaint filed' 
WHERE order_id = (SELECT order_id FROM target_order);


-- 5. DEFECTIVE PRODUCT (Resolved)
-- Eve found a dead pixel on a monitor.
WITH target_order AS (
    SELECT order_id, user_id 
    FROM orders 
    WHERE user_id = (SELECT user_id FROM users WHERE user_name = 'customer_eve')
      AND store_id = (SELECT store_id FROM stores WHERE store_name = 'Bob''s Gadgets')
    ORDER BY create_date DESC 
    LIMIT 1
),
insert_complaint AS (
    INSERT INTO complaints (user_id, order_id, comment, create_date)
    SELECT 
        user_id, 
        order_id, 
        'Monitor has a cluster of dead pixels in the center. Requesting a replacement unit.',
        NOW() - INTERVAL '2 weeks'
    FROM target_order
)
UPDATE orders 
SET order_status = 'Complaint resolved' 
WHERE order_id = (SELECT order_id FROM target_order);


-- 6. EXPIRED/BAD QUALITY (Active Complaint)
-- Dave complains about the fertilizer.
WITH target_order AS (
    SELECT order_id, user_id 
    FROM orders 
    WHERE user_id = (SELECT user_id FROM users WHERE user_name = 'customer_dave')
      AND store_id = (SELECT store_id FROM stores WHERE store_name = 'Sara''s Garden World')
      AND order_status != 'Complaint filed' -- Look for a different order than the one used in item 2
    ORDER BY create_date ASC 
    LIMIT 1
),
insert_complaint AS (
    INSERT INTO complaints (user_id, order_id, comment, create_date)
    SELECT 
        user_id, 
        order_id, 
        'The fertilizer bag had a hole in it and moisture got in. It is unusable clumps.',
        NOW() - INTERVAL '3 days'
    FROM target_order
)
UPDATE orders 
SET order_status = 'Complaint filed' 
WHERE order_id = (SELECT order_id FROM target_order);


-- 7. AUTO-FILL ORPHANED COMPLAINTS
-- In previous batches, we inserted orders with status 'Complaint filed' but didn't make a complaint row.
-- This block finds those orders and generates a generic complaint so the DB is consistent.
INSERT INTO complaints (user_id, order_id, comment, create_date)
SELECT 
    o.user_id,
    o.order_id,
    'System generated complaint: User reported an issue with the order items.',
    o.create_date + INTERVAL '5 days'
FROM orders o
WHERE o.order_status IN ('Complaint filed', 'Complaint resolved')
  AND NOT EXISTS (
      SELECT 1 FROM complaints c WHERE c.order_id = o.order_id
  );