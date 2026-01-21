-- 1st query: Query to search for a product from their name or description. 
--In this example i chose the keyword to be ‘LED light’
CREATE INDEX idx_products_full_text_search 
ON products 
USING GIN (to_tsvector('english', coalesce(product_name, '') || ' ' || coalesce(description, '')));

SELECT product_id
FROM products
WHERE to_tsvector('english', product_name || ' ' || description) 
      @@ plainto_tsquery('english', 'LED light');

-- 2nd query: Get the notifications list that belongs to a user to show them. Useful for application display.
--For this example i used user_id = 2
CREATE INDEX idx_notifications_receiver_time 
ON notifications (receiver_id, time_sent);

SELECT sender_id, time_sent, notification_type_id, content, read_status
FROM notifications
WHERE receiver_id = 2
ORDER BY time_sent
LIMIT 10

--3rd query: Get a list of customers that have a buying streak of 3 days in a row.
--Good for getting data on high quality customer
WITH unique_orders AS (
    SELECT DISTINCT user_id, create_date
    FROM orders
),
tmp AS (
SELECT user_id, create_date::date - ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY create_date)::int AS streak_start_id
FROM unique_orders
)
SELECT DISTINCT user_id
FROM tmp
GROUP BY user_id, streak_start_id
HAVING COUNT(user_id) >=3
--4th query: Quantity sold and revenue of each category of products
CREATE INDEX idx_shipping_received_orders 
ON shipping_statuses (order_id) 
WHERE status = 'received';

SELECT name, SUM(item_quantity), SUM(price_at_purchase)
FROM order_items
JOIN orders o USING(order_id)
JOIN product_variants USING(variant_id)
JOIN products USING (product_id)
JOIN product_categories USING(product_category_id)
WHERE EXISTS (
    SELECT 1 
    FROM shipping_statuses ss 
    WHERE ss.order_id = o.order_id 
    AND ss.status = 'received'
)
GROUP BY 1
--5th query: Query to get list of unapproved product. Useful for admin users whos job is to manually review these 
CREATE INDEX idx_products_pending_approval 
ON products (status) 
WHERE status = 'pending approval';

SELECT p.product_name, s.store_name, p.create_date
FROM products p
JOIN stores s ON p.store_id = s.store_id
WHERE p.status = 'pending approval'
ORDER BY p.create_date ASC;

--6th query: Customers who registered more than a year ago but never purchased anything
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_users_registration_date ON users(registration_date);

SELECT user_id FROM users u
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.user_id = u.user_id)
AND registration_date < NOW() - INTERVAL '1 year';
-- 7th query: Query to display the list of order with order_status = ‘Complain filed’. 
-- Useful for quick navigation for store owners
CREATE INDEX idx_orders_complaint_filed 
ON orders (order_status) 
WHERE order_status = 'Complain filed';

SELECT o.order_id, c.comment
FROM orders o
JOIN complaints c ON o.order_id = c.order_id
JOIN stores s ON o.store_id = s.store_id
WHERE o.order_status = 'Complaint filed' AND o.store_id = 2;

--8th query: Calculate the average time difference between an order being created and it getting shipped
CREATE INDEX idx_shipping_time
ON shipping_statuses (order_id, update_time);

SELECT AVG(ss.update_time - o.create_date)
FROM orders o
JOIN shipping_statuses ss ON o.order_id = ss.order_id
WHERE o.store_id = 2
  AND ss.status = 'shipped'; 
-- 9th query: Filter for review with low rating. 
-- Help stores handle situation where a product flops hard and damage control is needed
CREATE INDEX idx_reviews_negative_feedback 
ON reviews (create_date) 
WHERE rating <= 2;

SELECT * FROM reviews 
WHERE rating = 1 AND create_date > NOW() - INTERVAL '1 day';
-- 10th query: Trigger to check if field admin_id in reports table is someone with admin privilege
CREATE OR REPLACE FUNCTION check_report_admin_privilege()
RETURNS TRIGGER AS $$
BEGIN

    IF NEW.admin_id IS NOT NULL THEN

        IF NOT EXISTS (
            SELECT 1 
            FROM users 
            WHERE user_id = NEW.admin_id 
            AND privilege = 'Admin'
        ) THEN
            RAISE EXCEPTION 'Violation: The user assigned to Report #% (User ID %) does not have Admin privileges.', NEW.report_id, NEW.admin_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_report_admin ON reports;

CREATE TRIGGER trg_check_report_admin
BEFORE INSERT OR UPDATE OF admin_id
ON reports
FOR EACH ROW
EXECUTE FUNCTION check_report_admin_privilege();

