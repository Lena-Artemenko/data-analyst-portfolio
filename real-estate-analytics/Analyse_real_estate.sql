--1. Время активности объявлений
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
add_region_category AS (
    SELECT *, 
    	CASE 
	    	WHEN city_id='6X8I' THEN 'Санкт-Петербург' 
	    	ELSE 'Лен область' 
	    END AS region_cat
    FROM real_estate.flats
    WHERE id IN (SELECT * FROM filtered_id)
    ),
 -- Добавляю категории по дням активности объявления
add_days_exp_category AS (
    SELECT *, 
    		a.lASt_price/add.total_area AS price_qm, 
    		CASE 
    			WHEN a.days_exposition<=30 THEN 'Меньше месяца'
    			WHEN a.days_exposition BETWEEN 31 AND 90 THEN '1-3 месяца'
    			WHEN a.days_exposition BETWEEN 91 AND 180 THEN '3-6 месяцев'
    			WHEN a.days_exposition BETWEEN 181 AND 365 THEN '6-12 месяцев'
    			ELSE 'Больше года' 
    		END AS category_days_exp
    FROM add_region_category AS add 
    LEFT JOIN real_estate.advertisement AS a USING(id)
    WHERE a.days_exposition IS NOT NULL AND add.type_id='F8EM'
)
--Сводная таблица с регионами, категориям дат и разными параметрами
SELECT region_cat, 
		category_days_exp, 
		COUNT (id) AS COUNT_adv, 
		round(COUNT (id)*1.0/(SELECT COUNT (id) FROM add_days_exp_category),2) AS percent_adv,
		round(avg(price_qm)::numeric,2) AS avg_price_qm, 
		round(avg (total_area)::numeric,2) AS avg_tot_area,
		round(avg (ceiling_height)::numeric,2) AS avg_ceil_height,
		percentile_disc (0.5) within GROUP (ORDER BY rooms) AS med_rooms,
		percentile_disc (0.5) within GROUP (ORDER BY balcony) AS med_balcony,
		percentile_disc (0.5) within GROUP (ORDER BY floor) AS med_floor,
		percentile_disc (0.5) within GROUP (ORDER BY floors_total) AS med_floors_tot,
		round(COUNT (id) filter (WHERE is_apartment=1)*1.0/COUNT(id),3) AS percent_apart
FROM add_days_exp_category
GROUP BY region_cat, category_days_exp
ORDER BY region_cat DESC, category_days_exp

--Смотрю статистику по квартирам в Санкт-Петербурге, которые быстро продались
--(Привожу в пример только один запрос из четырех, так как они одинаковые, меняются только условия в секции WHERE)
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
add_region_category AS (
    SELECT *, 
    	CASE 
	    	WHEN city_id='6X8I' THEN 'Санкт-Петербург' 
	    	ELSE 'Лен область' 
	    END AS region_cat
    FROM real_estate.flats
    WHERE id IN (SELECT * FROM filtered_id)
    ),
add_days_exp_category AS (
    SELECT *, 
    		a.lASt_price/add.total_area AS price_qm, 
    		CASE 
    			WHEN a.days_exposition<=30 THEN 'Меньше месяца'
    			WHEN a.days_exposition BETWEEN 31 AND 90 THEN '1-3 месяца'
    			WHEN a.days_exposition BETWEEN 91 AND 180 THEN '3-6 месяцев'
    			WHEN a.days_exposition BETWEEN 181 AND 365 THEN '6-12 месяцев'
    			ELSE 'Больше года' 
    		END AS category_days_exp
    FROM add_region_category AS add 
    LEFT JOIN real_estate.advertisement AS a USING(id)
    WHERE a.days_exposition IS NOT NULL AND add.type_id='F8EM'
)
--Смотрю статистику по разным параметрам в разрезе количества комнат
SELECT  rooms,
		COUNT (id) AS COUNT_adv,
		round(avg(days_exposition)::numeric,0) AS avg_days_exp,
		round(avg(price_qm)::numeric,0) AS avg_price_qm, 
		round(avg (total_area)::numeric,2) AS avg_tot_area,
		round(avg (ceiling_height)::numeric,2) AS avg_ceil_height,
		percentile_disc (0.5) within group (ORDER BY balcony) AS med_balcony,
		percentile_disc (0.5) within group (ORDER BY floor) AS med_floor,
		percentile_disc (0.5) within group (ORDER BY floors_total) AS med_floors_tot
FROM add_days_exp_category
WHERE region_cat='Санкт-Петербург' AND category_days_exp='Меньше месяца'
GROUP BY rooms
ORDER BY COUNT_adv DESC

--Сезонность объявлений. 
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
month_first_exposition AS (
 	SELECT 
 		to_char (first_day_exposition::date, 'month') AS month_adv, 
 		COUNT (id) first_date_adv
 	FROM real_estate.advertisement 
 	LEFT JOIN real_estate.flats AS f USING (id)
 	WHERE id IN (SELECT * FROM filtered_id) AND f.type_id='F8EM' AND extract ('year' FROM first_day_exposition) BETWEEN 2015 AND 2018
 	GROUP BY month_adv),
month_lASt_exposition AS (
 	SELECT 
 		to_char (first_day_exposition::date + days_exposition::int, 'month') AS month_adv,
 		COUNT (id) lASt_date_adv
 	FROM real_estate.advertisement 
 	LEFT JOIN real_estate.flats AS f USING (id)
 	WHERE id IN (SELECT * FROM filtered_id) AND f.type_id='F8EM' AND extract ('year' FROM first_day_exposition) BETWEEN 2015 AND 2018
 	GROUP BY month_adv)
SELECT *, 
		dense_rank () over (ORDER BY first_date_adv DESC) AS rank_first, 
		dense_rank () over (ORDER BY lASt_date_adv DESC) AS rank_lASt
 FROM month_first_exposition
 FULL JOIN month_lASt_exposition USING (month_adv)
 ORDER BY rank_first
 

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
 month_first_exposition AS (
 	SELECT 
 		extract ('month' FROM a.first_day_exposition) AS month_adv, 
 		COUNT (a.id) first_date_adv, 
 		round(avg (a.lASt_price/f.total_area)::numeric,2) AS avg_price_qm, 
 		round(avg (f.total_area)::numeric,2) AS avg_tot_area
 	FROM real_estate.advertisement AS a  
 	LEFT JOIN real_estate.flats AS f USING (id)
 	WHERE a.id IN (SELECT * FROM filtered_id) AND f.type_id='F8EM' AND extract ('year' FROM a.first_day_exposition) BETWEEN 2015 AND 2018
 	GROUP BY month_adv),
month_lASt_exposition AS (
 	SELECT 
 		extract ('month'FROM a.first_day_exposition + a.days_exposition::int) AS month_adv, 
 		COUNT (a.id) lASt_date_adv, 
 		round(avg (a.lASt_price/f.total_area)::numeric,2) AS avg_price_qm, 
 		round(avg (f.total_area)::numeric,2) AS avg_tot_area
 	FROM real_estate.advertisement AS a
 	LEFT JOIN real_estate.flats AS f USING (id) 
 	WHERE a.id IN (SELECT * FROM filtered_id) AND f.type_id='F8EM' AND extract ('year' FROM a.first_day_exposition) BETWEEN 2015 AND 2018
 	GROUP BY month_adv)
SELECT *
FROM month_first_exposition
FULL JOIN month_lASt_exposition USING (month_adv)
ORDER BY month_adv
 
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
SELECT 
 	c.city,
 	COUNT (a.id) AS COUNT_adv
FROM real_estate.advertisement AS a 
LEFT JOIN real_estate.flats AS f USING (id)
LEFT JOIN real_estate.city AS c USING (city_id)
WHERE a.id IN (SELECT * FROM filtered_id) AND c.city<>'Санкт-Петербург'
GROUP BY c.city
ORDER BY COUNT_adv DESC

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
 SELECT 
 	c.city,
 	COUNT (a.id) AS COUNT_adv, 
 	round((COUNT (a.id) filter (WHERE a.days_exposition IS NOT NULL)*1.0/COUNT (a.id))::numeric,2) AS perc_closed_adv
FROM real_estate.advertisement AS a 
LEFT JOIN real_estate.flats AS f USING (id)
LEFT JOIN real_estate.city AS c USING (city_id)
WHERE a.id IN (SELECT * FROM filtered_id) AND c.city<>'Санкт-Петербург'
GROUP BY c.city
ORDER BY perc_closed_adv DESC, COUNT_adv DESC

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
city_lenobl AS 
    (SELECT 
    	c.city,
    	COUNT (a.id) AS COUNT_adv, 
    	COUNT (a.id) filter (WHERE a.days_exposition IS NOT NULL) AS COUNT_closed_adv
    FROM real_estate.advertisement AS a 
    LEFT JOIN real_estate.flats AS f USING (id)
    LEFT JOIN real_estate.city AS c USING (city_id)
    WHERE a.id IN (SELECT * FROM filtered_id) AND c.city<>'Санкт-Петербург'
    GROUP BY c.city
    ORDER BY COUNT_adv DESC)
SELECT  *, 
		round(COUNT_closed_adv*1.0/COUNT_adv,2) AS perc_closed_adv
FROM city_lenobl
WHERE COUNT_adv > (SELECT avg(COUNT_adv) FROM city_lenobl)
GROUP BY city, COUNT_adv, COUNT_closed_adv
ORDER BY perc_closed_adv DESC, COUNT_adv DESC

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
SELECT 
	c.city,
	round(avg(a.lASt_price/f.total_area)::numeric,0) AS price_qm, 
	round(avg (f.total_area)::numeric,2) AS avg_tot_area
FROM real_estate.advertisement AS a 
LEFT JOIN real_estate.flats AS f USING (id)
LEFT JOIN real_estate.city AS c USING (city_id)
WHERE a.id IN (SELECT * FROM filtered_id) AND c.city<>'Санкт-Петербург'
GROUP BY c.city 
ORDER BY price_qm DESC, avg_tot_area DESC

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
SELECT 
  	t.type,
  	round(avg(a.lASt_price/f.total_area)::numeric,0) AS price_qm, 
  	round(avg (f.total_area)::numeric,2) AS avg_tot_area
FROM real_estate.advertisement AS a 
LEFT JOIN real_estate.flats AS f USING (id)
LEFT JOIN real_estate.city AS c USING (city_id)
LEFT JOIN real_estate.type AS t USING (type_id)
WHERE a.id IN (SELECT * FROM filtered_id) AND c.city<>'Санкт-Петербург'
GROUP BY t.type
ORDER BY price_qm DESC, avg_tot_area DESC

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
SELECT 
	c.city, 
	round(avg (a.days_exposition)::numeric,0) AS avg_days_exp
FROM real_estate.advertisement AS a 
LEFT JOIN real_estate.flats AS f USING (id)
LEFT JOIN real_estate.city AS c USING (city_id)
WHERE a.id IN (SELECT * FROM filtered_id) AND c.city<>'Санкт-Петербург' AND a.days_exposition IS NOT NULL
GROUP BY c.city
ORDER BY avg_days_exp 

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
SELECT 
	t.type, 
	round(avg (a.days_exposition)::numeric,0) AS avg_days_exp
FROM real_estate.advertisement AS a 
LEFT JOIN real_estate.flats AS f USING (id)
LEFT JOIN real_estate.city AS c USING (city_id)
LEFT JOIN real_estate.type AS t USING (type_id)
WHERE a.id IN (SELECT * FROM filtered_id) AND c.city<>'Санкт-Петербург' AND a.days_exposition IS NOT NULL
GROUP BY t.type
ORDER BY avg_days_exp 
