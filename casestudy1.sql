USE EightWeekSQLChallenge
GO

-- First, adapting the provided schema creation script to MS SQL Server

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'dannys_diner')
	EXECUTE sp_executesql @SQLString='CREATE SCHEMA dannys_diner;'
GO

-- SET search_path = dannys_diner; I could set the default schema of my user to this, but I don't want to for this one case study

DROP TABLE IF EXISTS dannys_diner.sales;
CREATE TABLE dannys_diner.sales (
  "customer_id" VARCHAR(1),
  "order_date" DATE,
  "product_id" INTEGER
);

INSERT INTO dannys_diner.sales
(
    customer_id,
    order_date,
    product_id
)
VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');
 
DROP TABLE IF EXISTS dannys_diner.menu;
CREATE TABLE dannys_diner.menu (
  product_id INTEGER,
  product_name VARCHAR(5),
  price INTEGER
);

INSERT INTO dannys_diner.menu
(
    product_id,
    product_name,
    price
)
VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');
  
DROP TABLE IF EXISTS dannys_diner.members;
CREATE TABLE dannys_diner.members (
  "customer_id" VARCHAR(1),
  "join_date" DATE
);

INSERT INTO dannys_diner.members
(
    customer_id,
    join_date
)
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');


/* --------------------
   Case Study Questions
   --------------------*/

-- 1. What is the total amount each customer spent at the restaurant?
-- 2. How many days has each customer visited the restaurant?
-- 3. What was the first item from the menu purchased by each customer?
-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
-- 5. Which item was the most popular for each customer?
-- 6. Which item was purchased first by the customer after they became a member?
-- 7. Which item was purchased just before the customer became a member?
-- 8. What is the total items and amount spent for each member before they became a member?
-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?


-- 1. What is the total amount each customer spent at the restaurant?

SELECT
	s.customer_id, 
	SUM(m.price) AS TotalSales
FROM dbo.sales s
INNER JOIN dbo.menu m ON m.product_id = s.product_id
GROUP BY s.customer_id;
GO

-- 2. How many days has each customer visited the restaurant?

SELECT 
    customer_id, 
    COUNT(DISTINCT order_date) AS visits 
FROM dannys_diner.sales
GROUP BY customer_id;
GO

-- 3. What was the first item from the menu purchased by each customer?

-- I don't know if we care about order date ties. I'm assuming not; if we do, can use RANK or DENSE_RANK
WITH item_cte AS
(
    SELECT 
    customer_id,
    order_date,
    product_id,
    ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date ASC) AS rn
    FROM dannys_diner.sales
)
SELECT item_cte.customer_id,
       item_cte.order_date,
       --item_cte.product_id,
       m.product_name
FROM item_cte
INNER JOIN dannys_diner.menu m ON m.product_id = item_cte.product_id
WHERE item_cte.rn=1;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT TOP (1) m.product_name, COUNT(*) AS order_count FROM dannys_diner.sales s
INNER JOIN dannys_diner.menu m ON m.product_id = s.product_id
GROUP BY m.product_name
ORDER BY order_count DESC;


-- 5. Which item was the most popular for each customer?

-- Here, I'll assume we want to see ties

WITH rank_cte AS
(
    SELECT 
        m.product_name, 
        s.customer_id, 
        COUNT(*) AS order_count,
        DENSE_RANK() OVER (PARTITION BY s.customer_id ORDER BY COUNT(*) DESC) AS ranking
    FROM dannys_diner.sales s
    INNER JOIN dannys_diner.menu m ON m.product_id = s.product_id
    GROUP BY m.product_name, s.customer_id
)
SELECT product_name, rank_cte.customer_id, rank_cte.order_count
FROM rank_cte
WHERE rank_cte.ranking=1;


-- 6. Which item was purchased first by the customer after they became a member?
WITH mem_cte AS 
(
SELECT mem.customer_id,
       mem.join_date,
       s.order_date,
       m.product_name,
       ROW_NUMBER() OVER (PARTITION BY mem.customer_id ORDER BY s.order_date ASC) AS rn
FROM dannys_diner.members mem
INNER JOIN dannys_diner.sales s ON s.customer_id = mem.customer_id
INNER JOIN dannys_diner.menu m ON m.product_id = s.product_id
WHERE s.order_date >= mem.join_date
)
SELECT mem_cte.customer_id,
       mem_cte.join_date,
       mem_cte.order_date,
       mem_cte.product_name
FROM mem_cte WHERE rn=1;
GO

-- 7. Which item was purchased just before the customer became a member?
WITH mem_cte AS 
(
SELECT mem.customer_id,
       mem.join_date,
       s.order_date,
       m.product_name,
       ROW_NUMBER() OVER (PARTITION BY mem.customer_id ORDER BY s.order_date DESC) AS rn
FROM dannys_diner.members mem
INNER JOIN dannys_diner.sales s ON s.customer_id = mem.customer_id
INNER JOIN dannys_diner.menu m ON m.product_id = s.product_id
WHERE s.order_date < mem.join_date
)
SELECT mem_cte.customer_id,
       mem_cte.join_date,
       mem_cte.order_date,
       mem_cte.product_name
FROM mem_cte WHERE rn=1;
GO

-- 8. What is the total items and amount spent for each member before they became a member?

SELECT mem.customer_id,
       --mem.join_date,
       --s.order_date,
       --s.product_id,
       --m.price,
       COUNT(*) AS order_count,
       SUM(m.price) AS total_spent
FROM dannys_diner.members mem
INNER JOIN dannys_diner.sales s ON s.customer_id = mem.customer_id
INNER JOIN dannys_diner.menu m ON m.product_id = s.product_id
WHERE s.order_date < mem.join_date
GROUP BY mem.customer_id;
GO

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

-- for a long term implementation, I would add a column to the menu table with the points multiplier, or maybe a separate mult lookup table. I'll just do a CASE here

SELECT 
    s.customer_id,
    SUM(CASE
        WHEN m.product_id = 1 THEN 2
        ELSE 1
    END * m.price) AS points 
FROM dannys_diner.sales s
INNER JOIN dannys_diner.menu m ON m.product_id = s.product_id
GROUP BY s.customer_id

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

SELECT 
    s.customer_id,
    SUM(CASE
        WHEN m.product_id = 1 THEN 2
        WHEN DATEDIFF(DAY, mem.join_date, s.order_date) BETWEEN 0 AND 7 THEN 2
        ELSE 1
    END * m.price) AS points
FROM dannys_diner.sales s
INNER JOIN dannys_diner.menu m ON m.product_id = s.product_id
INNER JOIN dannys_diner.members mem ON mem.customer_id = s.customer_id
WHERE s.order_date < '2021-02-01'
GROUP BY s.customer_id