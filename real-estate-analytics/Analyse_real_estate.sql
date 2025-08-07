--Задача 1. Время активности объявлений

--Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Добавляю поле с категорией региона: Санкт-Петербург и ЛО 
add_region_category as (
    select *, 
    	case 
	    	when city_id='6X8I' then 'Санкт-Петербург' 
	    	else 'Лен область' 
	    end as region_cat
    from real_estate.flats
    WHERE id IN (SELECT * FROM filtered_id)
    ),
 -- Добавляю категории по дням активности объявления
add_days_exp_category as (
    select *, 
    		a.last_price/add.total_area as price_qm, 
    		case 
    			when a.days_exposition<=30 then 'Меньше месяца'
    			when a.days_exposition between 31 and 90 then '1-3 месяца'
    			when a.days_exposition between 91 and 180 then '3-6 месяцев'
    			when a.days_exposition between 181 and 365 then '6-12 месяцев'
    			else 'Больше года' 
    		end as category_days_exp
    from add_region_category as add 
    left join real_estate.advertisement as a using(id)
    where a.days_exposition is not null and add.type_id='F8EM'
)
--Сводная таблица с регионами, категориям дат и разными параметрами
select region_cat, 
		category_days_exp, 
		count (id) as count_adv, 
		round(count (id)*1.0/(select count (id) from add_days_exp_category),2) as percent_adv,
		round(avg(price_qm)::numeric,2) as avg_price_qm, 
		round(avg (total_area)::numeric,2) as avg_tot_area,
		round(avg (ceiling_height)::numeric,2) as avg_ceil_height,
		percentile_disc (0.5) within group (order by rooms) as med_rooms,
		percentile_disc (0.5) within group (order by balcony) as med_balcony,
		percentile_disc (0.5) within group (order by floor) as med_floor,
		percentile_disc (0.5) within group (order by floors_total) as med_floors_tot,
		round(count (id) filter (where is_apartment=1)*1.0/count(id),3) as percent_apart
from add_days_exp_category
group by region_cat, category_days_exp
order by region_cat desc, category_days_exp

-- Дополнительные запросы к задаче 1. Смотрю статистику по квартирам в Санкт-Петербурге, которые быстро продались
--(Привожу в пример только один запрос из четырех, так как они одинаковые, меняются только условия в секции where)
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
add_region_category as (
    select *, 
    	case 
	    	when city_id='6X8I' then 'Санкт-Петербург' 
	    	else 'Лен область' 
	    end as region_cat
    from real_estate.flats
    WHERE id IN (SELECT * FROM filtered_id)
    ),
add_days_exp_category as (
    select *, 
    		a.last_price/add.total_area as price_qm, 
    		case 
    			when a.days_exposition<=30 then 'Меньше месяца'
    			when a.days_exposition between 31 and 90 then '1-3 месяца'
    			when a.days_exposition between 91 and 180 then '3-6 месяцев'
    			when a.days_exposition between 181 and 365 then '6-12 месяцев'
    			else 'Больше года' 
    		end as category_days_exp
    from add_region_category as add 
    left join real_estate.advertisement as a using(id)
    where a.days_exposition is not null and add.type_id='F8EM'
)
--Смотрю статистику по разным параметрам в разрезе количества комнат
select  rooms,
		count (id) as count_adv,
		round(avg(days_exposition)::numeric,0) as avg_days_exp,
		round(avg(price_qm)::numeric,0) as avg_price_qm, 
		round(avg (total_area)::numeric,2) as avg_tot_area,
		round(avg (ceiling_height)::numeric,2) as avg_ceil_height,
		percentile_disc (0.5) within group (order by balcony) as med_balcony,
		percentile_disc (0.5) within group (order by floor) as med_floor,
		percentile_disc (0.5) within group (order by floors_total) as med_floors_tot
from add_days_exp_category
where region_cat='Санкт-Петербург' and category_days_exp='Меньше месяца'
group by rooms
order by count_adv desc

--!!!Исправленный запрос
--Задача 2 (запрос для 1 и 2 вопроса). Сезонность объявлений. 
--Смотрю количество объявлений по месяцам, ранжирую
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
month_first_exposition as (
 	select 
 		to_char (first_day_exposition::date, 'month') as month_adv, 
 		count (id) first_date_adv
 	from real_estate.advertisement 
 	left join real_estate.flats as f using (id)
 	where id IN (SELECT * FROM filtered_id) and f.type_id='F8EM' and extract ('year' from first_day_exposition) between 2015 and 2018
 	group by month_adv),
month_last_exposition as (
 	select 
 		to_char (first_day_exposition::date + days_exposition::int, 'month') as month_adv,
 		count (id) last_date_adv
 	from real_estate.advertisement 
 	left join real_estate.flats as f using (id)
 	where id IN (SELECT * FROM filtered_id) and f.type_id='F8EM' and extract ('year' from first_day_exposition) between 2015 and 2018
 	group by month_adv)
select *, 
		dense_rank () over (order by first_date_adv desc) as rank_first, 
		dense_rank () over (order by last_date_adv desc) as rank_last
 from month_first_exposition
 full join month_last_exposition using (month_adv)
 order by rank_first
 
--!!!Исправленный 
--Задача 2(запрос для 3 вопроса).
--Смотрю статистику по ср цене кв м и ср площади в разрезе месяцев
 WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
 month_first_exposition as (
 	select 
 		extract ('month' from a.first_day_exposition) as month_adv, 
 		count (a.id) first_date_adv, 
 		round(avg (a.last_price/f.total_area)::numeric,2) as avg_price_qm, 
 		round(avg (f.total_area)::numeric,2) as avg_tot_area
 	from real_estate.advertisement as a  
 	left join real_estate.flats as f using (id)
 	where a.id IN (SELECT * FROM filtered_id) and f.type_id='F8EM' and extract ('year' from a.first_day_exposition) between 2015 and 2018
 	group by month_adv),
month_last_exposition as (
 	select 
 		extract ('month'from a.first_day_exposition + a.days_exposition::int) as month_adv, 
 		count (a.id) last_date_adv, 
 		round(avg (a.last_price/f.total_area)::numeric,2) as avg_price_qm, 
 		round(avg (f.total_area)::numeric,2) as avg_tot_area
 	from real_estate.advertisement as a
 	left join real_estate.flats as f using (id) 
 	where a.id IN (SELECT * FROM filtered_id) and f.type_id='F8EM' and extract ('year' from a.first_day_exposition) between 2015 and 2018
 	group by month_adv)
select *
from month_first_exposition
full join month_last_exposition using (month_adv)
order by month_adv
 
--Задача 3 (1 вопрос). Анализ рынка недвижимости Ленобласти
-- Смотрю кол-во объявлений по населенным пунктам Ленобласти
 WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    )
select 
 	c.city,
 	count (a.id) as count_adv
from real_estate.advertisement as a 
left join real_estate.flats as f using (id)
left join real_estate.city as c using (city_id)
where a.id IN (SELECT * FROM filtered_id) and c.city<>'Санкт-Петербург'
group by c.city
order by count_adv desc

--Задача 3 (2 вопрос). Анализ рынка недвижимости Ленобласти
--Смотрю долю снятых объявлений от общего кол-ва объявлений по населенным пунктам Ленобласти
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    )
 select 
 	c.city,
 	count (a.id) as count_adv, 
 	round((count (a.id) filter (where a.days_exposition is not null)*1.0/count (a.id))::numeric,2) as perc_closed_adv
from real_estate.advertisement as a 
left join real_estate.flats as f using (id)
left join real_estate.city as c using (city_id)
where a.id IN (SELECT * FROM filtered_id) and c.city<>'Санкт-Петербург'
group by c.city
order by perc_closed_adv desc, count_adv desc

--Задача 3 (2 вопрос, доп. запрос). Анализ рынка недвижимости Ленобласти
--Смотрю долю снятых объявлений от общего кол-ва объявлений только по населенным пунктам, где кол-во объявлений выше среднего

WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
city_lenobl as 
    (select 
    	c.city,
    	count (a.id) as count_adv, 
    	count (a.id) filter (where a.days_exposition is not null) as count_closed_adv
    from real_estate.advertisement as a 
    left join real_estate.flats as f using (id)
    left join real_estate.city as c using (city_id)
    where a.id IN (SELECT * FROM filtered_id) and c.city<>'Санкт-Петербург'
    group by c.city
    order by count_adv desc)
select  *, 
		round(count_closed_adv*1.0/count_adv,2) as perc_closed_adv
from city_lenobl
where count_adv > (select avg(count_adv) from city_lenobl)
group by city, count_adv, count_closed_adv
order by perc_closed_adv desc, count_adv desc

--Задача 3 (3 вопрос). Анализ рынка недвижимости Ленобласти
-- Смотрю ср цену за кв м и среднюю площадь по населенным пунктам Ленобласти

WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    )
select 
	c.city,
	round(avg(a.last_price/f.total_area)::numeric,0) as price_qm, 
	round(avg (f.total_area)::numeric,2) as avg_tot_area
from real_estate.advertisement as a 
left join real_estate.flats as f using (id)
left join real_estate.city as c using (city_id)
where a.id IN (SELECT * FROM filtered_id) and c.city<>'Санкт-Петербург'
group by c.city 
order by price_qm desc, avg_tot_area desc

--Задача 3 (3 вопрос, доп. запрос). Анализ рынка недвижимости Ленобласти
-- Смотрю ср цену за кв м и среднюю площадь по ТИПАМ населенных пунктов Ленобласти
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    )
select 
  	t.type,
  	round(avg(a.last_price/f.total_area)::numeric,0) as price_qm, 
  	round(avg (f.total_area)::numeric,2) as avg_tot_area
from real_estate.advertisement as a 
left join real_estate.flats as f using (id)
left join real_estate.city as c using (city_id)
left join real_estate.type as t using (type_id)
where a.id IN (SELECT * FROM filtered_id) and c.city<>'Санкт-Петербург'
group by t.type
order by price_qm desc, avg_tot_area desc

--Задача 3 (4 вопрос). Анализ рынка недвижимости Ленобласти
--Смотрю статистику по самым быстрым и долгим продажам по населенным пунктам Ленобласти
    WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    )
select 
	c.city, 
	round(avg (a.days_exposition)::numeric,0) as avg_days_exp
from real_estate.advertisement as a 
left join real_estate.flats as f using (id)
left join real_estate.city as c using (city_id)
where a.id IN (SELECT * FROM filtered_id) and c.city<>'Санкт-Петербург' and a.days_exposition is not null
group by c.city
order by avg_days_exp 

--Задача 3 (4 вопрос, доп. запрос). Анализ рынка недвижимости Ленобласти
--Смотрю статистику по самым быстрым и долгим продажам по ТИПАМ населенных пунктов Ленобласти

    WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    )
select 
	t.type, 
	round(avg (a.days_exposition)::numeric,0) as avg_days_exp
from real_estate.advertisement as a 
left join real_estate.flats as f using (id)
left join real_estate.city as c using (city_id)
left join real_estate.type as t using (type_id)
where a.id IN (SELECT * FROM filtered_id) and c.city<>'Санкт-Петербург' and a.days_exposition is not null
group by t.type
order by avg_days_exp 