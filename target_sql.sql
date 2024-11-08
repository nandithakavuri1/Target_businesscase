select count(*) from `target.customers`;
select count(*) from `target.geolocation`;

--1.1Data type of all columns in the “customers” table.
SELECT 
  column_name,
  data_type
FROM 
  `amazing-height-433215-c4.target.INFORMATION_SCHEMA.COLUMNS`
WHERE 
  table_name = 'customers';


--1.2 Get the time range between which the orders were placed.
select min(order_purchase_timestamp) as first_order_timestamp, max(order_purchase_timestamp) as last_order_timestamp
from `target.orders`;

--1.3 Count the Cities & States of customers who ordered during the given period.

with cte as (select min(order_purchase_timestamp) as min_time, max(order_purchase_timestamp) as max_time
from `target.orders`) 
select count(distinct b.customer_city) as cities, count(distinct b.customer_state) as state
from `target.orders` a 
join `target.customers` b 
on a.customer_id = b.customer_id 
join cte c 
on a.order_purchase_timestamp between min_time and max_time;

--2.1 Is there a growing trend in the no. of orders placed over the past years?
select extract(year from a.order_purchase_timestamp) as year, count(a.order_id) as total_orders
from `target.orders` a 
group by 1
order by 1;

--2.2 Can we see some kind of monthly seasonality in terms of the no. of orders being placed?
select  extract(year from a.order_purchase_timestamp) as year, 
        extract(month from a.order_purchase_timestamp) as month, 
        count(a.order_id) as total_orders
from    `target.orders` a 
group by 1,2
order by 1,2;

--2.3 During what time of the day, do the Brazilian customers mostly place their orders? (Dawn, Morning, Afternoon or Night)
/* 0-6 hrs : Dawn
7-12 hrs : Mornings
13-18 hrs : Afternoon
19-23 hrs : Night */

select  case when extract(hour from a.order_purchase_timestamp) between 0 and 6 then 'Dawn'
            when extract(hour from a.order_purchase_timestamp) between 7 and 12 then 'Mornings'  
            when extract(hour from a.order_purchase_timestamp) between 13 and 18 then 'Afternoon'
            when extract(hour from a.order_purchase_timestamp) between 19 and 23 then 'Night' end as time_of_day   
,       count(order_id) as total_orders
from `target.orders` a 
join `target.customers` b 
on a.customer_id = b.customer_id
group by 1
order by 2;

--3. Evolution of E-commerce orders in the Brazil region:
--3.1 Get the month on month no. of orders placed in each state.

select    b.customer_state,
          extract(year from a.order_purchase_timestamp) as year, 
          extract(month from a.order_purchase_timestamp) as month,
          count(order_id) as total_orders 
from      `target.orders` a 
join      `target.customers` b 
on        a.customer_id = b.customer_id
group by 1,2,3
order by 1,2,3;



--3.2 How are the customers distributed across all the states?
select    customer_state, count(customer_id) as total_customers
from      `target.customers`
group by  1
order by  2;

--4. Impact on Economy: Analyze the money movement by e-commerce by looking at order prices, freight and others.
--4.1 Get the % increase in the cost of orders from year 2017 to 2018 (include months between Jan to Aug only).
--You can use the "payment_value" column in the payments table to get the cost of orders.

with cte as (
select extract(year from a.order_purchase_timestamp) as year, 
       extract(month from a.order_purchase_timestamp) as month,
        round(sum(b.payment_value)) as prev_cost
from `target.orders` a 
join `target.payments` b 
on a.order_id = b.order_id 
where extract(year from a.order_purchase_timestamp) = 2017
and extract(month from a.order_purchase_timestamp) between 1 and 8
group by 1,2),
cte2 as (
select extract(year from a.order_purchase_timestamp) as year, 
       extract(month from a.order_purchase_timestamp) as month,
       round(sum(b.payment_value)) as current_cost
from `target.orders` a 
join `target.payments` b 
on a.order_id = b.order_id 
where extract(year from a.order_purchase_timestamp) = 2018
and extract(month from a.order_purchase_timestamp) between 1 and 8
group by 1,2)
select cte.year,cte.month,prev_cost,
       cte2.year,cte2.month,current_cost,
       round((cte2.current_cost - cte.prev_cost)*100/cte.prev_cost) as percentage_increase
from cte 
join cte2
on cte.year<cte2.year and cte.month = cte2.month
order by 1,2,4,5;
--3669022
--8694734

--4.2 Calculate the Total & Average value of order price for each state.
select b.customer_state as state ,round(sum(payment_value)) as total_cost, round(avg(payment_value)) as avg_cost
from `target.orders` a 
join `target.customers` b 
on a.customer_id = b.customer_id
join `target.payments` c 
on a.order_id = c.order_id
group by 1
order by 2,3 desc;

--4.3 Calculate the Total & Average value of order freight for each state.
select b.customer_state, round(sum(c.freight_value)) as total_freight, round(avg(c.freight_value)) as avg_freight
from `target.orders` a 
join `target.customers` b 
on a.customer_id = b.customer_id
join `target.order_items` c 
on a.order_id = c.order_id
group by 1
order by 2,3 desc;

--5. Analysis based on sales, freight and delivery time.
--5.1 Find the no. of days taken to deliver each order from the order’s purchase date as delivery time.
/* Also, calculate the difference (in days) between the estimated & actual delivery date of an order.
   Do this in a single query.

You can calculate the delivery time and the difference between the estimated & actual delivery date using the given formula:
time_to_deliver = order_delivered_customer_date - order_purchase_timestamp
diff_estimated_delivery = order_delivered_customer_date - order_estimated_delivery_date */ 

select  distinct order_id,date_diff(order_delivered_customer_date,order_purchase_timestamp,day) as time_to_deliver,
        date_diff(order_delivered_customer_date, order_estimated_delivery_date,day) as diff_estimated_delivery
from    `target.orders` 
where   order_delivered_customer_date is not null;





--5.2 Find out the top 5 states with the highest & lowest average freight value.
create view target.top_5_freight as (select b.customer_state, avg(c.freight_value) as avg_freight_value,
                    row_number() over(order by avg(c.freight_value) desc) as rnk1, 
                    row_number() over(order by avg(c.freight_value) asc) as rnk2
from `target.orders` a 
join `target.customers` b 
on a.customer_id = b.customer_id
join `target.order_items` c 
on a.order_id = c.order_id
group by 1)

--Top 5 with highest freight value
select customer_state, round(avg_freight_value) as avg_freight_value
from `target.top_5_freight`
where rnk1 <= 5
order by 2 desc;

--Last 5 states with lowest freight value 
select customer_state, round(avg_freight_value) as avg_freight_value
from `target.top_5_freight`
where rnk2 <= 5
order by 2 ;

select * from `target.top_5_freight` ;

--5.3 Find out the top 5 states with the highest & lowest average delivery time.
--Highest average
with cte as (select    b.customer_state, 
                       date_diff(order_delivered_customer_date,order_purchase_timestamp,day) as delivery_time
              from      `target.orders` a 
              join      `target.customers` b 
              on        a.customer_id = b.customer_id),
cte2 as (select customer_state, round(avg(delivery_time),2) as avg_delivery_time,
                row_number() over(order by avg(cte.delivery_time) desc) as rnk2
          from cte 
          group by 1)
select customer_state,avg_delivery_time 
from cte2
where rnk2<=5
order by 2;

--Lowest average
with cte as (select    b.customer_state, 
                       date_diff(order_delivered_customer_date,order_purchase_timestamp,day) as delivery_time
              from      `target.orders` a 
              join      `target.customers` b 
              on        a.customer_id = b.customer_id),
cte2 as (select customer_state, round(avg(delivery_time),2) as avg_delivery_time,
                row_number() over(order by avg(cte.delivery_time)) as rnk1
          from cte 
          group by 1)
select customer_state,avg_delivery_time 
from cte2
where rnk1<=5
order by 2;




--5.4 Find out the top 5 states where the order delivery is really fast as compared to the estimated date of delivery.
/*You can use the difference between the averages of actual & estimated delivery date to figure out how fast the delivery was for each state.*/ 

with cte as (select    b.customer_state, 
                       date_diff(order_delivered_customer_date,order_estimated_delivery_date,day) as delivery_time
              from      `target.orders` a 
              join      `target.customers` b 
              on        a.customer_id = b.customer_id
              where     a.order_delivered_customer_date is not null),
cte2 as (select customer_state, round(avg(delivery_time),2) as avg_delivery_time,
                row_number() over(order by avg(cte.delivery_time)) as rnk1
          from cte 
          group by 1)
select customer_state,avg_delivery_time 
from cte2
where rnk1<=5
order by 2;

--6. Analysis based on the payments:
--6.1 Find the month on month no. of orders placed using different payment types.
select    extract(year from order_purchase_timestamp) as year_purchased,
          extract(month from order_purchase_timestamp) as month_purchased,
          b.payment_type, 
          count(a.order_id) as total_orders
from `target.orders` a 
join `target.payments` b  
on b.order_id = a.order_id 
group by 1,2,3
order by 1,2 asc, 4 desc;

--6.2 Find the no. of orders placed on the basis of the payment installments that have been paid.
--We want you to count the no. of orders placed based on the no. of payment installments where at least one installment has been successfully paid.

select payment_installments,count(order_id) as total_orders 
from `target.payments` 
where payment_sequential >=1
group by 1;

Structure of code and approach to solve the problem are good. Output screenshots and insights are not given from 4.3 question.



