DROP DATABASE IF EXISTS instacart;
CREATE DATABASE instacart;
USE instacart;

CREATE TABLE departments (
    department_id INT PRIMARY KEY,
    department VARCHAR(50) NOT NULL
);

CREATE TABLE aisles (
    aisle_id INT PRIMARY KEY,
    aisle VARCHAR(50) NOT NULL
);

CREATE TABLE products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(200) NOT NULL,
    aisle_id INT NOT NULL,
    department_id INT NOT NULL,
    FOREIGN KEY (aisle_id) REFERENCES aisles (aisle_id),
    FOREIGN KEY (department_id) REFERENCES departments (department_id)
);

CREATE TABLE orders (
    order_id INT PRIMARY KEY,
    user_id INT NOT NULL,
    eval_set VARCHAR(5) NOT NULL,
    order_number SMALLINT NOT NULL,
    order_dow TINYINT NOT NULL,
    order_hour TINYINT NOT NULL,
    days_since_prior SMALLINT,
    INDEX idx_user (user_id, order_number)
);

CREATE TABLE order_products (
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    add_to_cart_order SMALLINT NOT NULL,
    reordered TINYINT NOT NULL,
    PRIMARY KEY (order_id, product_id)
);

LOAD DATA LOCAL INFILE 'data/departments.csv' INTO TABLE departments
FIELDS TERMINATED BY ',' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'data/aisles.csv' INTO TABLE aisles
FIELDS TERMINATED BY ',' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'data/products.csv' INTO TABLE products
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '' IGNORE 1 LINES
(product_id, @name, aisle_id, department_id)
SET product_name = REPLACE(@name, '\\"', '"');

LOAD DATA LOCAL INFILE 'data/orders.csv' INTO TABLE orders
FIELDS TERMINATED BY ',' IGNORE 1 LINES
(order_id, user_id, eval_set, order_number, order_dow, order_hour, @gap)
SET days_since_prior = CAST(NULLIF(@gap, '') AS DECIMAL(4, 1));

LOAD DATA LOCAL INFILE 'data/order_products__prior.csv' INTO TABLE order_products
FIELDS TERMINATED BY ',' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'data/order_products__train.csv' INTO TABLE order_products
FIELDS TERMINATED BY ',' IGNORE 1 LINES;

CREATE INDEX idx_product ON order_products (product_id);
