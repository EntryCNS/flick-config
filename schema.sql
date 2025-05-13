DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS payment_requests CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS booths CASCADE;
DROP TABLE IF EXISTS user_roles CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS transactions CASCADE;
DROP TABLE IF EXISTS notices CASCADE;
DROP TABLE IF EXISTS inquiries CASCADE;

CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    dauth_id VARCHAR(36) UNIQUE NOT NULL,
    name VARCHAR(50) NOT NULL,
    email VARCHAR(100),
    grade SMALLINT,
    room SMALLINT,
    number SMALLINT,
    balance BIGINT NOT NULL DEFAULT 0,
    push_token TEXT,
    profile_url TEXT,
    last_login_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    CONSTRAINT valid_student_info CHECK (
        (grade IS NOT NULL AND room IS NOT NULL AND number IS NOT NULL) OR
        (grade IS NULL AND room IS NULL AND number IS NULL)
    )
);

CREATE TABLE user_roles (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(10) NOT NULL CHECK (role IN ('STUDENT', 'TEACHER', 'ADMIN')),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, role)
);

CREATE TABLE booths (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(30) NOT NULL UNIQUE,
    password_hash VARCHAR(100) NOT NULL,
    name VARCHAR(50) NOT NULL,
    description TEXT,
    status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'INACTIVE')),
    total_sales BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE TABLE products (
    id BIGSERIAL PRIMARY KEY,
    booth_id BIGINT NOT NULL REFERENCES booths(id) ON DELETE CASCADE,
    name VARCHAR(50) NOT NULL,
    price BIGINT NOT NULL CHECK (price >= 0),
    description TEXT,
    image_url TEXT,
    stock INTEGER NOT NULL DEFAULT 0,
    status VARCHAR(10) NOT NULL DEFAULT 'AVAILABLE' CHECK (status IN ('AVAILABLE', 'SOLD_OUT', 'HIDDEN')),
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE TABLE orders (
    id BIGSERIAL PRIMARY KEY,
    booth_id BIGINT NOT NULL REFERENCES booths(id),
    user_id BIGINT REFERENCES users(id),
    booth_order_number INTEGER NOT NULL,
    total_amount BIGINT NOT NULL CHECK (total_amount > 0),
    status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PAID', 'COMPLETED', 'CANCELED', 'EXPIRED')),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW() + INTERVAL '15 minutes',
    paid_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE TABLE order_items (
    id BIGSERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL REFERENCES products(id),
    product_name VARCHAR(50) NOT NULL,
    price BIGINT NOT NULL CHECK (price >= 0),
    quantity SMALLINT NOT NULL CHECK (quantity > 0),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE TABLE payment_requests (
    id BIGSERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    token VARCHAR(32) NOT NULL UNIQUE,
    method VARCHAR(10) NOT NULL CHECK (method IN ('QR_CODE', 'STUDENT_ID')),
    status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'COMPLETED', 'FAILED', 'EXPIRED')),
    user_id BIGINT REFERENCES users(id),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW() + INTERVAL '10 minutes',
    completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE TABLE transactions (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id),
    type VARCHAR(10) NOT NULL CHECK (type IN ('CHARGE', 'PAYMENT')),
    amount BIGINT NOT NULL CHECK (amount > 0),
    balance_after BIGINT NOT NULL CHECK (balance_after >= 0),
    order_id BIGINT REFERENCES orders(id),
    admin_id BIGINT REFERENCES users(id),
    memo TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE TABLE payments (
    id BIGSERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES orders(id),
    request_id BIGINT NOT NULL REFERENCES payment_requests(id),
    user_id BIGINT NOT NULL REFERENCES users(id),
    amount BIGINT NOT NULL CHECK (amount > 0),
    transaction_id BIGINT REFERENCES transactions(id),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE TABLE notifications (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id),
    type VARCHAR(20) NOT NULL CHECK (type IN ('PAYMENT_REQUEST', 'ORDER_COMPLETED', 'POINT_CHARGED', 'NOTICE_CREATED')),
    title VARCHAR(100) NOT NULL,
    body TEXT NOT NULL,
    data TEXT,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE TABLE notices (
    id BIGSERIAL PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    content TEXT NOT NULL,
    is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    author_id BIGINT REFERENCES users(id) ON DELETE SET NULL
);


CREATE TABLE inquiries (
    id BIGSERIAL PRIMARY KEY,
    category VARCHAR(20) NOT NULL CHECK (category IN ('PAYMENT', 'ACCOUNT', 'BOOTH', 'TECHNICAL', 'OTHER')), 
    title VARCHAR(100) NOT NULL,
    content TEXT NOT NULL,
    user_id BIGINT NOT NULL REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_dauth_id ON users(dauth_id);
CREATE INDEX idx_users_grade_room_number ON users(grade, room, number) WHERE grade IS NOT NULL;

CREATE INDEX idx_user_roles_user_id ON user_roles(user_id);
CREATE INDEX idx_user_roles_role ON user_roles(role);

CREATE INDEX idx_booths_status ON booths(status);
CREATE INDEX idx_booths_username ON booths(username);

CREATE INDEX idx_products_booth_id ON products(booth_id);
CREATE INDEX idx_products_booth_status ON products(booth_id, status);
CREATE INDEX idx_products_sort_order ON products(booth_id, sort_order);

CREATE INDEX idx_orders_booth_id ON orders(booth_id);
CREATE INDEX idx_orders_booth_number ON orders(booth_id, booth_order_number);
CREATE INDEX idx_orders_user_id ON orders(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_expires_pending ON orders(expires_at) WHERE status = 'PENDING';

CREATE INDEX idx_order_items_order_id ON order_items(order_id);

CREATE INDEX idx_payment_requests_order_id ON payment_requests(order_id);
CREATE INDEX idx_payment_requests_code ON payment_requests(token);
CREATE INDEX idx_payment_requests_user_id ON payment_requests(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_payment_requests_pending ON payment_requests(status, expires_at) WHERE status = 'PENDING';

CREATE INDEX idx_transactions_user_id ON transactions(user_id);
CREATE INDEX idx_transactions_type ON transactions(user_id, type);
CREATE INDEX idx_transactions_order_id ON transactions(order_id) WHERE order_id IS NOT NULL;

CREATE INDEX idx_payments_order_id ON payments(order_id);
CREATE INDEX idx_payments_user_id ON payments(user_id);

CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_unread ON notifications(user_id) WHERE is_read = FALSE;

CREATE INDEX idx_notices_is_pinned ON notices(is_pinned);
CREATE INDEX idx_notices_created_at ON notices(created_at);
CREATE INDEX idx_notices_author_id ON notices(author_id) WHERE author_id IS NOT NULL;

CREATE INDEX idx_inquiries_user_id ON inquiries(user_id);
CREATE INDEX idx_inquiries_category ON inquiries(category);
CREATE INDEX idx_inquiries_created_at ON inquiries(created_at);

CREATE OR REPLACE FUNCTION generate_booth_order_number()
RETURNS TRIGGER AS $$
DECLARE
    max_number INTEGER;
BEGIN
    SELECT COALESCE(MAX(booth_order_number), 0) INTO max_number 
    FROM orders 
    WHERE booth_id = NEW.booth_id;
    
    NEW.booth_order_number := max_number + 1;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_generate_booth_order_number
BEFORE INSERT ON orders
FOR EACH ROW
EXECUTE FUNCTION generate_booth_order_number();

CREATE OR REPLACE FUNCTION process_order_payment()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'PAID' AND OLD.status = 'PENDING' THEN
        UPDATE products p
        SET 
            stock = p.stock - oi.quantity,
            status = CASE WHEN p.stock - oi.quantity <= 0 THEN 'SOLD_OUT' ELSE p.status END,
            updated_at = NOW()
        FROM order_items oi
        WHERE oi.order_id = NEW.id AND oi.product_id = p.id;
        
        UPDATE booths
        SET 
            total_sales = total_sales + NEW.total_amount,
            updated_at = NOW()
        WHERE id = NEW.booth_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_process_order_payment
AFTER UPDATE ON orders
FOR EACH ROW
WHEN (NEW.status = 'PAID' AND OLD.status = 'PENDING')
EXECUTE FUNCTION process_order_payment();

CREATE OR REPLACE FUNCTION expire_pending_requests()
RETURNS INTEGER AS $$
DECLARE
    expired_count INTEGER;
BEGIN
    UPDATE payment_requests
    SET 
        status = 'EXPIRED',
        updated_at = NOW()
    WHERE 
        status = 'PENDING' AND
        expires_at <= NOW();
    
    GET DIAGNOSTICS expired_count = ROW_COUNT;
    
    UPDATE orders
    SET 
        status = 'EXPIRED',
        updated_at = NOW()
    WHERE 
        status = 'PENDING' AND
        expires_at <= NOW();
        
    RETURN expired_count;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION has_role(user_id BIGINT, check_role VARCHAR)
RETURNS BOOLEAN AS $$
DECLARE
    result BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM user_roles
        WHERE user_id = has_role.user_id AND role = check_role
    ) INTO result;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;