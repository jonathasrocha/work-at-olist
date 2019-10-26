create table if not exists 
public.d_date(
	date_sk BIGINT IDENTITY(0,1) PRIMARY KEY,
	field_date TIMESTAMP,
	year SMALLINT,
	month SMALLINT,
	day_of_year SMALLINT,
	day_of_mouth SMALLINT,
	day_of_week SMALLINT,
	week_of_year SMALLINT,
	day_of_week_desc VARCHAR(30),	
	day_of_week_desc_short VARCHAR(30),
	month_desc VARCHAR(30),
	month_desc_short VARCHAR(3),
	quarter VARCHAR(1),
	half VARCHAR(1),
	name_holiday VARCHAR(200),
	type_holiday VARCHAR(50)
);
create table if not exists
public.d_customers(
	customer_id VARCHAR(100) PRIMARY KEY,
	city VARCHAR(35),
	state VARCHAR(2),
	latitude DOUBLE PRECISION,
	longitude DOUBLE PRECISION,
	version BIGINT DEFAULT NULL,
	date_from TIMESTAMP DEFAULT NULL,
	date_until TIMESTAMP DEFAULT NULL
);

CREATE TABLE IF NOT EXISTS 
public.d_sellers(
	seller_id VARCHAR(100) PRIMARY KEY, 
	city VARCHAR(35),
	state VARCHAR(2),
	latitude DOUBLE PRECISION,
	longitude DOUBLE PRECISION,
	version BIGINT DEFAULT NULL,
	date_from TIMESTAMP DEFAULT NULL,
	date_until TIMESTAMP DEFAULT NULL
);
CREATE TABLE IF NOT EXISTS 
public.d_products(
	product_id VARCHAR(100) PRIMARY KEY, 
	category_name  VARCHAR(100),
	weight_g  DOUBLE PRECISION,
	length_cm DOUBLE PRECISION,
	height_cm DOUBLE PRECISION,
	width_cm DOUBLE PRECISION,
	version BIGINT DEFAULT NULL,
	date_from TIMESTAMP DEFAULT NULL,
	date_until TIMESTAMP DEFAULT NULL
);
CREATE TABLE IF NOT EXISTS 
public.f_sales(
	order_id VARCHAR(42) NOT NULL,
	product_sk VARCHAR(100) REFERENCES d_products(product_id),
	sellers_sk VARCHAR(100) REFERENCES d_sellers(seller_id),
	customer_sk VARCHAR(100) REFERENCES d_customers(customer_id),
	purchase_date_sk BIGINT REFERENCES d_date(date_sk),
	shipping_limit TIMESTAMP,
	status VARCHAR(50),
	freight_value DOUBLE PRECISION,
	price DOUBLE PRECISION,
	payment_type VARCHAR(50),
	payment_value DOUBLE PRECISION,
	payment_installments DOUBLE PRECISION	
)
compound sortkey(order_id, product_sk, sellers_sk);
