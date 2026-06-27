-- ************************************** calendar_date
drop table if exists dw.calendar_date cascade;
CREATE TABLE dw.calendar_date
(
 calendar_dt date NOT NULL,
 dt_year          integer NOT NULL,
 dt_quarter      integer NOT NULL,
 dt_month         integer NOT NULL,
 dt_week          integer NOT NULL,
 dt_week_day      integer NOT NULL,
 dt_day           integer NOT NULL,
 CONSTRAINT PK_3 PRIMARY KEY ( calendar_dt )
);

insert into dw.calendar_date 
(
select distinct 
	  order_date as calendar_dt
	, extract(year from order_date) as dt_year
	, extract(quarter from order_date) as dt_quarter
	, extract(month from order_date) as dt_month
	, extract(week from order_date) as dt_week
	, extract(dow from order_date) as dt_week_day
	, extract(day from order_date) as dt_day
from public.orders

union 

select distinct 
	  ship_date as calendar_dt
	, extract(year from ship_date) as dt_year
	, extract(quarter from ship_date) as dt_quarter
	, extract(month from ship_date) as dt_month
	, extract(week from ship_date) as dt_week
	, extract(dow from ship_date) as dt_week_day
	, extract(day from ship_date) as dt_day
from public.orders
);



-- ************************************** customer_segment
DROP TABLE IF EXISTS dw.customer_segment cascade;
CREATE table dw.customer_segment
(
 segment_id   integer NOT NULL,
 segment_name varchar(11) NOT NULL,
 CONSTRAINT PK_9_1 PRIMARY KEY ( segment_id )
);


insert into dw.customer_segment
select row_number() over (order by segment_name) as segment_id
	, segment_name 
from (select distinct segment as segment_name from public.orders) t
;



-- ************************************** customer
drop table if exists dw.customer cascade;
CREATE TABLE dw.customer
(
 customer_id   varchar(8) NOT NULL,
 customer_name varchar NOT NULL,
 segment_id    integer NOT NULL,
 CONSTRAINT PK_4 PRIMARY KEY ( customer_id ),
 CONSTRAINT FK_7_1 FOREIGN KEY ( segment_id ) REFERENCES dw.customer_segment ( segment_id )
);

insert into dw.customer
select distinct 
	  o.customer_id
	, o.customer_name 
	, cs.segment_id
from public.orders o 
	inner join dw.customer_segment cs
		on cs.segment_name = o.segment
;


-- ************************************** shipping_address
drop table if exists dw.shipping_address cascade;
CREATE TABLE dw.shipping_address
(
 shipping_address_id integer NOT NULL,
 country             varchar(13) NOT NULL,
 region              varchar(7) NOT NULL,
 state               varchar(20) NOT NULL,
 city                varchar(17) NOT null, 
 postal_code         int4 NULL,
 CONSTRAINT PK_9 PRIMARY KEY ( shipping_address_id )
);

insert into dw.shipping_address
(
  with pre as (
       select distinct 
       		  country
       		, region
       		, state
       		, city
       		, postal_code
        from public.orders
  )
select row_number() over (order by country, region, state, city, postal_code) as shipping_address_id
	, country
    , region
    , state
    , city
    , postal_code
from pre
)
;



-- ************************************** "order"
drop table if exists dw."order" cascade;
CREATE TABLE dw."order"
(
 order_id            varchar(14) NOT NULL,
 order_dt          date NOT NULL,
 ship_dt           date NOT NULL,
 ship_mode           varchar(14) NOT NULL,
 customer_id         varchar(8) NOT NULL,
 shipping_address_id integer NOT NULL,
 returned_flg        smallint NOT NULL,
 CONSTRAINT PK_6 PRIMARY KEY ( order_id ),
 CONSTRAINT FK_2 FOREIGN KEY ( order_dt ) REFERENCES dw.calendar_date ( calendar_dt ),
 CONSTRAINT FK_3 FOREIGN KEY ( ship_dt ) REFERENCES dw.calendar_date ( calendar_dt ),
 CONSTRAINT FK_4 FOREIGN KEY ( customer_id ) REFERENCES dw.customer ( customer_id ),
 CONSTRAINT FK_8 FOREIGN KEY ( shipping_address_id ) REFERENCES dw.shipping_address ( shipping_address_id )
);

insert into dw."order"
(
  with returned as (
       select distinct r.order_id 
        from public."returns" r 
        where r.returned = 'Yes'
  )

select distinct 
	  o.order_id
	, o.order_date as order_dt
	, o.ship_date as ship_dt
	, o.ship_mode 
	, o.customer_id 
	, sa.shipping_address_id
	, case 	
		when r.order_id is not null then 1
		else 0
	end as returned_flg
from public.orders o
	inner join dw.shipping_address sa 
		on sa.city = o.city 
			and sa.country = o.country 
			and sa.region = o.region
			and sa.state = o.state 
			and coalesce(sa.postal_code, 0) = coalesce(o.postal_code, 0)
	left join returned r
		on o.order_id = r.order_id
);



-- ************************************** product
drop table if exists dw.product cascade;
CREATE TABLE dw.product
(
 product_id   varchar(15) NOT NULL,
 product_name varchar(127) NOT NULL,
 category     varchar(15) NOT NULL,
 subcategory  varchar(11) NOT NULL,
 valid_dt     date        not null,
 CONSTRAINT PK_7 PRIMARY KEY ( product_id ),
 CONSTRAINT FK_9 FOREIGN KEY ( valid_dt ) REFERENCES dw.calendar_date ( calendar_dt )
);

insert into dw.product 
(
select distinct on (product_id)
	  o.product_id 
	, o.product_name 
	, o.category 
	, o.subcategory 
	, o.order_date as valid_dt
from public.orders o 
order by product_id
	   , order_date
	   , ship_date
)
;



-- ************************************** order_x_product
drop table if exists dw.order_x_product cascade;
CREATE TABLE dw.order_x_product
(
 product_id varchar(15) NOT NULL,
 order_id   varchar(14) NOT NULL,
 sales numeric(9, 4) NOT NULL,
 quantity int4 NOT NULL,
 discount numeric(4, 2) NOT NULL,
 profit numeric(21, 16) NOT NULL,
 CONSTRAINT PK_8 PRIMARY KEY ( product_id, order_id ),
 CONSTRAINT FK_6 FOREIGN KEY ( order_id ) REFERENCES dw."order" ( order_id ),
 CONSTRAINT FK_7 FOREIGN KEY ( product_id ) REFERENCES dw.product ( product_id )
);

insert into dw.order_x_product 
select distinct on (product_id, order_id)
	  o.product_id 
	, o.order_id 
	, o.sales 
	, o.quantity
	, o.discount 
	, o.profit 
from public.orders o 
order by o.product_id
	   , o.order_id
	   , o.row_id desc
;




