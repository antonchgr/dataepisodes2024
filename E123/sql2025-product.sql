USE HellasGateV2
GO


with a as
(
select h.empid, year(h.orderdate) as fcyear, sum(i.qty*i.unitprice) as orderamt
from sales.OrdersHeader as h
join sales.OrderItems as i on i.orderid = h.orderid
group by h.empid, year(h.orderdate)
)
, b as 
(
select *,
cast ((a.orderamt / (lag(a.orderamt) 
 over (partition by a.empid order by a.fcyear)) 
 * 100.00) as decimal(5,2)) as pct_prev_year
from a
)
select * ,
product(pct_prev_year/100) over (partition by empid order by fcyear) as product_pct_prev_year
from b;