DROP TABLE IF EXISTS replies CASCADE;
DROP TABLE IF EXISTS reviews CASCADE;
DROP TABLE IF EXISTS complaints CASCADE;
DROP TABLE IF EXISTS shipping_statuses CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS promotion_products CASCADE;
DROP TABLE IF EXISTS fixed_price_promotions CASCADE;
DROP TABLE IF EXISTS percent_discount_promotions CASCADE;
DROP TABLE IF EXISTS promotions CASCADE;
DROP TABLE IF EXISTS product_variants CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS product_categories CASCADE;
DROP TABLE IF EXISTS stores CASCADE;
DROP TABLE IF EXISTS reports CASCADE;
DROP TABLE IF EXISTS report_categories CASCADE;
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS notification_types CASCADE;
DROP TABLE IF EXISTS users CASCADE;

CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    user_name VARCHAR(30) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    last_name VARCHAR(100),
    first_name VARCHAR(100),
    personal_phone VARCHAR(20) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    home_address VARCHAR(255),
    home_address_ward VARCHAR(100),
    home_address_city VARCHAR(100),
    home_postal_code VARCHAR(20),
    privilege VARCHAR(20) NOT NULL DEFAULT 'Customer' CHECK (privilege IN ('Customer', 'Admin')),
    account_status VARCHAR(20) NOT NULL DEFAULT 'NotVerified' CHECK (account_status IN ('Active', 'Suspended', 'Banned', 'NotVerified')),
    registration_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE notification_types (
    notification_type_id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL
);

CREATE TABLE notifications (
    notification_id SERIAL PRIMARY KEY,

    sender_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    receiver_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    time_sent TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    notification_type_id INT NOT NULL REFERENCES notification_types(notification_type_id) ON DELETE RESTRICT,
    content VARCHAR(500) NOT NULL,
    read_status VARCHAR(10) NOT NULL DEFAULT 'Unread' CHECK (read_status IN ('Read', 'Unread'))
);

CREATE TABLE report_categories (
    report_category_id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL
);

CREATE TABLE stores (
    store_id SERIAL PRIMARY KEY,

    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
    store_name VARCHAR(200) UNIQUE NOT NULL,
    logo VARCHAR(255),
    business_phone VARCHAR(20),
    business_email VARCHAR(255),
    pickup_address VARCHAR(255) NOT NULL,
    pickup_address_ward VARCHAR(100) NOT NULL,
    pickup_address_city VARCHAR(100) NOT NULL,
    postal_code VARCHAR(20) NOT NULL,
    tax_code VARCHAR(50),
    description VARCHAR(2000),
    create_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE reports (
    report_id SERIAL PRIMARY KEY,
    report_category_id INT NOT NULL REFERENCES report_categories(report_category_id) ON DELETE RESTRICT,
    create_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_status VARCHAR(20) NOT NULL DEFAULT 'Unresolved' CHECK (resolved_status IN ('Unresolved', 'Pending Review', 'Resolved', 'Closed')),
    comment VARCHAR(1000) NOT NULL,
    admin_note VARCHAR(1000),
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT, 

    admin_id INT REFERENCES users(user_id) ON DELETE SET NULL,      
    store_id INT NOT NULL REFERENCES stores(store_id) ON DELETE RESTRICT
);

CREATE TABLE product_categories (
    product_category_id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL
);

CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,

    store_id INT NOT NULL REFERENCES stores(store_id) ON DELETE CASCADE,
    product_name VARCHAR(200) NOT NULL,

    product_category_id INT NOT NULL REFERENCES product_categories(product_category_id) ON DELETE RESTRICT,
    description VARCHAR(2000),
    status VARCHAR(20) NOT NULL DEFAULT 'pending approval' CHECK (status IN ('active', 'pending approval', 'removed')),
    create_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE product_variants (
    variant_id SERIAL PRIMARY KEY,

    product_id INT NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    variant_name VARCHAR(100) NOT NULL,
    price DECIMAL(10, 2) NOT NULL CHECK (price > 0),
    stock INT NOT NULL CHECK (stock >= 0),
    variant_image VARCHAR(255)
);

CREATE TABLE promotions (
    promotion_id SERIAL PRIMARY KEY,
    discount_type VARCHAR(30) NOT NULL CHECK (discount_type IN ('Fixed Price', 'Percentage Discount')),
    start_period TIMESTAMP NOT NULL,
    end_period TIMESTAMP NOT NULL,
    CONSTRAINT check_promotion_dates CHECK (end_period >= start_period)
);

CREATE TABLE fixed_price_promotions (

    promotion_id INT PRIMARY KEY REFERENCES promotions(promotion_id) ON DELETE CASCADE,
    price DECIMAL(10, 2) NOT NULL CHECK (price > 0)
);

CREATE TABLE percent_discount_promotions (

    promotion_id INT PRIMARY KEY REFERENCES promotions(promotion_id) ON DELETE CASCADE,
    discount_percent DECIMAL(5, 2) NOT NULL CHECK (discount_percent > 0 AND discount_percent <= 100)
);

CREATE TABLE promotion_products (

    promotion_id INT NOT NULL REFERENCES promotions(promotion_id) ON DELETE CASCADE,
    product_id INT NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    PRIMARY KEY (promotion_id, product_id)
);

CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,

    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
    store_id INT NOT NULL REFERENCES stores(store_id) ON DELETE RESTRICT,
    shipping_address VARCHAR(255) NOT NULL,
    shipping_ward VARCHAR(100) NOT NULL,
    shipping_city VARCHAR(100) NOT NULL,
    shipping_postal_code VARCHAR(20),
    payment_method VARCHAR(30) NOT NULL CHECK (payment_method IN ('Cash', 'Online transaction')),
    order_status VARCHAR(30) DEFAULT 'Unresolved' NOT NULL CHECK(order_status IN ('Rejected by vendor' ,'Approved by vendor', 'Unresolved', 'Complaint filed' , 'Complaint resolved')),
    create_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE order_items (

    order_id INT NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,

    variant_id INT NOT NULL REFERENCES product_variants(variant_id) ON DELETE RESTRICT,
    item_quantity INT NOT NULL CHECK (item_quantity >= 1),
    price_at_purchase DECIMAL(10, 2) CHECK (price_at_purchase > 0),
    PRIMARY KEY (order_id, variant_id)
);

CREATE TABLE shipping_statuses (
    shipping_status_id SERIAL PRIMARY KEY,

    order_id INT NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    update_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(50) NOT NULL DEFAULT 'Not shipped' CHECK (status IN ('Not shipped', 'shipped', 'received'))
);

CREATE TABLE complaints (
    complaint_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
    order_id INT NOT NULL REFERENCES orders(order_id) ON DELETE RESTRICT,
    comment VARCHAR(1000) NOT NULL,
    create_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE reviews (
    review_id SERIAL PRIMARY KEY,

    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,

    product_id INT NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    comment VARCHAR(1000),
    rating INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    create_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE replies (
    reply_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,

    review_id INT NOT NULL REFERENCES reviews(review_id) ON DELETE CASCADE,
    comment VARCHAR(1000) NOT NULL,
    create_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);


