
Create Database Zomato_db

use Zomato_db 

-- EDA 
select * from customers ;
select * from restaurants ;
select * from orders ;
select * from deliveries ; 
select * from riders ;

--- Handling Null Values  

select * from customers
where customer_id is null
or name is null
or email is null
or phone is null
or location is null
or total_orders is null
or average_rating is null


select * from restaurants 
where name is null
or cuisine_type is null
or owner_name is null 
or average_delivery_time is null
or rating is null
or total_orders is null 


select * from orders
where order_date is null
or status is null
or total_amount is null
or payment_mode is null


select * from deliveries 
where delivery_status is null
or	delivery_fee is null
or	delivery_time is null
or	distance is null
or	vehicle_type is null 


select * from riders
where name is null
or contact_number is null
or vehicle_type is null
or total_deliveries is null 
or average_rating is null 
or location is null


-- ----------------------
-- Analysis & Report 
-- ----------------------


--** Q.1 Top 10 customers by total spending 
select Top 10 
        c.customer_id,c.name ,
        sum(o.total_amount) as Total_Amount_spend 
from  customers as c 
    inner join orders as o
on c.customer_id = o.customer_id
    where o.status = 'Delivered'
group by c.customer_id,c.name
     order by Total_Amount_spend desc ; 


--** Q.2 Monthly revenue trend 
-- Calculate revenue month-wise and identify growth trends.
with monthly_revenue as (
    select FORMAT(order_date,'yyyy-MM') as Year_Month,
            SUM(total_amount) as Revenue  
from orders
group by FORMAT(order_date,'yyyy-MM')
)

Select Year_Month,Revenue,
    LEAD(revenue) over (order by Year_Month) as Next_Month_Revenue,
    LEAD(revenue) over (order by Year_Month) - Revenue as Growth,
    ROUND (( LEAD(revenue) over (order by Year_Month) - Revenue)*100/revenue,2) as Growth_rate
from monthly_revenue ;

--** Q.3 Delivery person performance ranking 
-- Rank delivery persons based on:
-- total deliveries
-- average delivery time
-- successful deliveries 

SELECT 
    r.delivery_person_id,r.name,
    COUNT(d.delivery_id) AS total_deliveries,
    AVG(d.delivery_time) AS avg_delivery_time,
    SUM(
        CASE 
            WHEN d.delivery_status = 'Delivered' THEN 1
            ELSE 0
        END
    ) AS successful_deliveries,

    RANK() OVER (ORDER BY COUNT(d.delivery_id) DESC,AVG(d.delivery_time) ASC)  
          AS delivery_rank

FROM deliveries d
    INNER JOIN riders r
ON d.delivery_person_id = r.delivery_person_id
    GROUP BY r.delivery_person_id,
             r.name;

-- ## Chasmum Gole and Naksh Khurana rank 1st and 2nd for the highest successful delivery rates. Delivery times are also reasonably efficient.


--** Q.4 Customers with no orders
-- Find registered customers who never placed any order.
select 
       c.customer_id,
       c.name,
       o.order_id,
       o.order_date 
from 
    customers as c 
    left join 
    orders as o
on c.customer_id = o.customer_id 
where o.order_id is null ;


--** Q.5 Identify peak ordering hours
-- Find the hours during which most orders are placed.
select format(order_date,'hh tt') as order_time,
       count(order_id) as Total_order 
from orders
    group by format(order_date,'hh tt')
order by count(order_id) desc ;

-- ## Order volume rises during the evening and peaks late at night, with 12 AM recording the highest number of orders. 

--** Q.6. Running total of daily sales
with Daily_sales as (
select cast(order_date as date) as Orders_Dates,
       sum(total_amount) as Daily_Sales
from orders
group by cast(order_date as date)
)

select 
    Orders_Dates,
    Daily_sales,
    sum(Daily_sales) over (order by orders_Dates asc) as Running_Total_Daily_Sales
from Daily_sales;
 

--** Q.7. Top customers in each city
WITH customer_spending AS (
    SELECT TRIM(value) AS city,
        c.customer_id,
        c.name,
        SUM(o.total_amount) AS total_spent
    FROM customers c
        CROSS APPLY (
    SELECT value, ordinal
    FROM STRING_SPLIT(c.location, ',', 1)) s
    JOIN orders o
        ON c.customer_id = o.customer_id
    WHERE s.ordinal = 3
        GROUP BY 
        TRIM(value),c.customer_id,c.name),

ranked_customers AS (
SELECT *,RANK() OVER (PARTITION BY city ORDER BY total_spent DESC) AS rnk
FROM customer_spending)

SELECT *
FROM ranked_customers
WHERE rnk = 1;

--** Q.8. Percentage contribution of each customer to total revenue 
with customer_revenue as (
       select c.customer_id,c.name,
       sum(o.total_amount) as Customer_total
       from customers c 
         join orders o 
            on c.customer_id = o.customer_id
               where o.status = 'Delivered'
       group by c.customer_id,c.name )

select customer_id,name, Customer_total,
        ROUND(Customer_total*100.0/sum(Customer_total) over (),2) as revenue_percentage
from customer_revenue 
    order by  revenue_percentage desc ;

-- ## Dhriti Bhatnagar, Wishi Sani, and Hardik Bansal have a high contribution to total revenue, 
-- ## each accounting for more than 1% of overall revenue.


--** Q.9. Average delivery delay analysis
-- Compare expected delivery time vs actual delivery time.

select r.delivery_person_id ,r.name,
    AVG(
      cast(d.delivery_time as int) - cast(d.estimated_time as int)) as Avg_delay_by_Riders 

from deliveries d 
    inner join riders r
                on d.delivery_person_id = r.delivery_person_id
                    group by r.delivery_person_id ,r.name ;

-- ## Most order Delivered  Earlier as expected 


--** Q.10. Detect inactive delivery partners
-- Find riders who have not completed deliveries in the last 30 days.
select r.delivery_person_id ,r.name ,
       max(d.delivery_time)  AS last_delivery_date 
from deliveries d right join riders r
    on d.delivery_person_id = r.delivery_person_id
group by r.delivery_person_id,r.name
        having MAX(d.delivery_time) < DATEADD(day,-30,GETDATE())
               or MAX(d.delivery_time) is null

--** Q.11.Most Frequently Ordered Restaurants
select r.restaurant_id, 
       r.name,
       count(o.order_id) as Total_Orders  
from restaurants r
    inner join orders o 
        on r.restaurant_id = o.restaurant_id
           group by r.restaurant_id ,
                    r.name
                order by total_orders desc

-- ## Most Frequently ordered Restaurants is Grand Bistro (BBQ)

--** Q.12. Repeat customer analysis 
-- Find customers who ordered more than once in a week/month.
select c.name ,
        FORMAT(o.order_date,'yy-MMM') as Order_Month,
        count(o.order_id) as Total_orders 
from customers c
    inner join orders o
        on c.customer_id = o.customer_id 
            group by  c.name,
                      FORMAT(o.order_date,'yy-MMM') 
            having count(o.order_id) >1
order by Total_orders desc 

--** Q.13. Order cancellation analysis
-- Analyze:
--- cancellation percentage
--- most cancelled areas
--- cancellation by time

--- cancellation percentage
Select count(status) as Total_orders,
        sum(case 
                when status = 'Cancelled' then 1
                else 0
            end
                ) as Total_Orders_cancel,

ROUND( (      sum(case 
                when status = 'Cancelled' then 1
                else 0
            end
        )*100.0/count(status)),2) as Cancelled_pct
from orders;

--- most cancelled areas
select trim(value) as Area, 
       sum(case when o.status = 'Cancelled' then 1 else 0 end) Total_Cancel
from customers c
    cross apply(select value,ordinal 
    from string_split(c.location,',',1)) s
inner join 
orders o
    on c.customer_id = o.customer_id
    where ordinal = 1
    group by TRIM(value)
    order by Total_Cancel desc;

---- cancellation by time:
select FORMAT(order_date,'hh tt') as Cancel_time,
       count(case when status = 'Cancelled' then 1 end) as Total_Cancel 
from orders
    group by FORMAT(order_date,'hh tt')
            order by Total_Cancel desc;

-- ## Cancellation rates peaked between 12 AM and 4 AM, 
--   while afternoon hours experienced the fewest cancellations.

--** Q.14. Revenue generated per delivery partner
-- Find which delivery persons handled the highest revenue orders. 

select top  5 r.delivery_person_id ,
            r.name,
            count(o.order_id) as Total_orders,
            sum(o.total_amount) as Total_Revenue,
            avg(o.total_amount) as Avg_revenue,
rank() over (order by sum(o.total_amount) desc) as rank_over_Total_rev
from orders o 
            inner join
 deliveries d
        on o.order_id = d.order_id
inner join riders r
        on d.delivery_person_id = r.delivery_person_id
    where o.status = 'Delivered'
group by r.delivery_person_id ,
         r.name
order by Total_Revenue desc;

--- ## Chasmum Gole generated the highest revenue from successful deliveries, 
-- ## while Fiyaz Nayar recorded the highest average revenue per order among the top-performing riders. 


--** Q.15. Average order value (AOV) 
-- Calculate average order value overall and customer-wise.
-- Q.15 Average Order Value (AOV)
SELECT 
       c.customer_id,
       c.name,
       COUNT(o.order_id) AS Total_Orders,
       ROUND(SUM(o.total_amount),2) AS Total_Spending,
       ROUND(AVG(o.total_amount),2) AS AOV
FROM customers c
LEFT JOIN orders o
ON c.customer_id = o.customer_id
WHERE o.order_id IS NOT NULL
GROUP BY c.customer_id, c.name 
ORDER BY AOV DESC; 

-- ## The analysis revealed that revenue is heavily concentrated among repeat high-value customers, 
--##  while a large percentage of users are one-time purchasers. 
-- ## This suggests that improving customer retention could significantly increase long-term revenue.”


--** Q.16. Consecutive order streak analysis
-- Use window functions to identify customers ordering on consecutive days.
WITH customer_orders AS (
    SELECT DISTINCT
        customer_id,
        CAST(order_date AS DATE) AS order_day
    FROM orders),
previous_orders AS (
    SELECT 
        customer_id,
        order_day,
        LAG(order_day) OVER (
            PARTITION BY customer_id 
            ORDER BY order_day
        ) AS previous_day
    FROM customer_orders
)
SELECT customer_id,order_day,previous_day,
    DATEDIFF(
        DAY,
        previous_day,
        order_day

    ) AS day_gap
FROM previous_orders;

-- ## 1.A small group of repeat customers contributes a significant portion of total revenue, 
-- ## 2.Several customers placed only one order but had very high spending, 
-- ##   indicating strong potential for re-engagement and personalized marketing campaigns.

---** Q.17. Customer retention rate 
-- Measure how many customers returned after first purchase.
select customer_id,count(order_id) as Total_orders
from orders
group by customer_id
having count(order_id) >2;

---** Q.18. Fastest and slowest delivery zones
-- Compare average delivery times by area/city/zone.
with Order_delivery_time as (
select
      trim(value) as Area,
      cast(d.delivery_time as int) as Delivery_minute 
from customers c
cross apply string_split(c.location,',',1) s
 inner join orders o
 on c.customer_id = o.customer_id
 inner join deliveries d
 on o.order_id = d.order_id
 where s.ordinal = 1
 )

 select Area,ROUND(AVG(Delivery_minute),2)
  as  avg_delivery_time
 from Order_delivery_time
 group by Area 
 order by avg_delivery_time desc ;

 -- ## 1. Subramaniam Ganj recorded the slowest average delivery time at 60 minutes, 
--##  indicating possible operational inefficiencies or traffic-related delays in that zone.
--## 2. Areas like Gopal, Boase Zila, and Venkataraman Ganj had the fastest deliveries (15–16 minutes), 
------suggesting better delivery efficiency and optimized rider allocation.

---** Q.19. Revenue lost due to cancellations
-- Estimate monetary loss from cancelled orders. 
select sum (case when status = 'Cancelled' 
                 then (total_amount) end) 
as Total_lost_Revenue
from orders ;

-- ## The business lost approximately ₹1.24 million in potential revenue due to cancelled orders, 
--    highlighting a major impact on overall profitability.

---**Q.20. Top Revenue-Generating Restaurants 
-- Find the top 10 restaurants generating the highest revenue from completed orders.
select top 10 re.restaurant_id ,re.name ,
       sum(o.total_amount) as Total_revenue
from restaurants re left join orders o 
    on re.restaurant_id = o.restaurant_id
where o.status = 'Delivered'
group by re.restaurant_id ,re.name
order by Total_revenue desc;

--# South Indian and Chinese restaurants dominate the top revenue-generating list, 
--  indicating strong customer preference and high sales performance for these cuisines.

---**Q.21. Most Popular Cuisine Type
-- Identify which cuisine type receives the highest number of orders.
select cuisine_type ,
       COUNT(order_id) as Total_orders
from restaurants re inner join orders o
    on re.restaurant_id = o.restaurant_id
group by cuisine_type
order by total_orders desc;

-- ## Continental cuisine was the most ordered category, 
--    while South Indian and Chinese cuisines also showed consistently high customer demand

---** Q.22. Restaurant Rating vs Sales Analysis
-- Analyze whether highly rated restaurants actually generate more revenue.
select re.restaurant_id ,re.name ,
       Round(AVG(re.rating),1) as Avg_rating ,
       Round(AVG(o.total_amount),2) as Avg_Revenue
from restaurants re inner join orders o
    on re.restaurant_id = o.restaurant_id
group by re.restaurant_id ,re.name
order by Avg_Revenue desc ;

-- ## Tandoori Hut (Italian) with a high rating of 4.5 generated the highest average revenue (3690.73), 
-- while Madras Cafe (Mexican) with a lower rating of 3.3 still achieved very strong revenue (3582.35), 
-- showing that high sales are not always dependent on ratings alone.
-- Higher-rated restaurants do not always generate higher revenue 

---** Q.23. Restaurants With Highest Cancellation Rate
-- Find restaurants with the most cancelled orders.
select re.restaurant_id ,re.name ,
       count(o.order_id) as Total_orders,
       count(case when o.status = 'Cancelled' then 1 end) as Total_cancel_order,
       ROUND(
             (count(case 
                        when o.status = 'Cancelled' 
                            then 1 end) *100.0/count(o.order_id)),2) as Cancel_rate
             
from restaurants re inner join orders o
    on re.restaurant_id = o.restaurant_id
group by re.restaurant_id ,re.name
order by Total_cancel_order desc ;

-- ## Restaurants such as Spicy Kitchen (French) and Chennai Corner (Mediterranean) recorded extremely 
--    high cancellation rates of 80% and 100%, indicating possible operational, delivery,
--    or customer satisfaction issues affecting order completion.

---** Q.24. Peak Hour Performance by Restaurant 
-- Determine during which hour each restaurant receives the maximum number of orders. 
WITH restaurant_order AS (
    SELECT
        re.restaurant_id,
        re.name AS restaurant_name,
        FORMAT(o.order_date,'hh tt') AS order_hour,
        COUNT(o.order_id) AS total_orders
    FROM restaurants re
    JOIN orders o
        ON re.restaurant_id = o.restaurant_id
    GROUP BY
        re.restaurant_id,
        re.name,
        FORMAT(o.order_date,'hh tt')
),

peak_hour AS (
    SELECT *,
           ROW_NUMBER() OVER(
               PARTITION BY restaurant_id
               ORDER BY total_orders DESC
           ) AS rn
    FROM restaurant_order
)

SELECT
    restaurant_id,
    restaurant_name,
    order_hour AS peak_hour,
    total_orders
FROM peak_hour
WHERE rn = 1
ORDER BY total_orders DESC;

--## Peak ordering hours vary by restaurant and cuisine, with most restaurants 
--   receiving their highest order volume during lunch, evening, or late-night hours.

---** Q.25. Create a complete business KPI dashboard query 
------------
-- Total Orders
-- Total Revenue
-- Average Delivery Time
-- Active Customers
-- Cancellation Rate
-- Top Delivery Partner

-- Q.25 Complete Business KPI Dashboard Query

WITH top_delivery_partner AS (
    SELECT TOP 1 r.delivery_person_id, r.name,
        SUM(o.total_amount) AS total_revenue
    FROM riders r
    JOIN deliveries d
        ON r.delivery_person_id = d.delivery_person_id
    JOIN orders o
        ON d.order_id = o.order_id
    WHERE o.status = 'Delivered'
    GROUP BY r.delivery_person_id,r.name
    ORDER BY total_revenue DESC )

SELECT 
    -- Total Orders
     COUNT(o.order_id) AS total_orders,

    -- Total Revenue
    SUM(
        CASE 
            WHEN o.status = 'Delivered'
            THEN o.total_amount
            ELSE 0
        END
    ) AS total_revenue,

    -- Average Delivery Time
    ROUND( AVG( CAST(d.delivery_time AS FLOAT)),2) AS avg_delivery_time,

    -- Active Customers
    COUNT( DISTINCT o.customer_id) AS active_customers,

    -- Cancellation Rate
    ROUND(
        SUM(
            CASE 
                WHEN o.status = 'Cancelled'
                THEN 1
                ELSE 0
            END 

        ) * 100.0 / COUNT(o.order_id), 2) AS cancellation_rate,

    --- Top Delivery Partner   
      ( SELECT name FROM top_delivery_partner ) AS top_delivery_partner,

    ( SELECT total_revenue FROM top_delivery_partner )  AS partner_revenue 

FROM orders o 
inner JOIN deliveries d  
    ON o.order_id = d.order_id; 
-- ## The business generated over 1.22M revenue from 1,500 orders, with an average delivery time of 
--    37.48 minutes, a 33.93% cancellation rate, and Chasmum Gole emerging as the top delivery partner by revenue 
--    contribution.