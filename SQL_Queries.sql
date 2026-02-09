USE real_estate;


SELECT * FROM chennai;
ALTER TABLE `real_estate`.`bangalore` 
CHANGE COLUMN `ï»¿Price` `Price` INT NULL DEFAULT NULL ;
ALTER TABLE `real_estate`.`delhi` 
CHANGE COLUMN `ï»¿Price` `Price` INT NULL DEFAULT NULL ;
ALTER TABLE `real_estate`.`hyderabad` 
CHANGE COLUMN `ï»¿Price` `Price` INT NULL DEFAULT NULL ;
ALTER TABLE `real_estate`.`kolkata` 
CHANGE COLUMN `ï»¿Price` `Price` INT NULL DEFAULT NULL ;
ALTER TABLE `real_estate`.`mumbai` 
CHANGE COLUMN `ï»¿Price` `Price` INT NULL DEFAULT NULL ;

-- Getting total market evaluation of all metropolition cities

SELECT city_name,total_size as Total_Market_Valuation,number_of_properties,avg_price,
		dense_rank() over(order by total_size desc) as market_positioning
FROM (
select 'Chennai' as city_name, sum(Price) as total_size,count(*) as number_of_properties ,AVG(Price) as avg_price from chennai
union all
select 'Bangalore' ,sum(Price) as total_size,count(*) as number_of_properties,AVG(Price) as avg_price from bangalore
union all
select 'Delhi' ,sum(Price) as total_size,count(*) as number_of_properties,AVG(Price) as avg_price from delhi
union all
select 'Hyderabad' ,sum(Price) as total_size,count(*) as number_of_properties,AVG(Price) as avg_price from hyderabad
union all
select 'Kolkata' ,sum(Price) as total_size,count(*) as number_of_properties,AVG(Price) as avg_price from kolkata
union all
select 'Mumbai' ,sum(Price) as total_size ,count(*) as number_of_properties,AVG(Price) as avg_price from mumbai
) t; 


with total as 
(
select 'Chennai' as city_name, count(*) as number_of_properties from chennai
union all
select 'Bangalore' city_name, count(*) as number_of_properties from bangalore
union all
select 'Delhi' city_name, count(*) as number_of_properties from delhi
union all
select 'Hyderabad' city_name, count(*) as number_of_properties from hyderabad
union all
select 'Kolkata' city_name, count(*) as number_of_properties from kolkata
union all
select 'Mumbai' city_name, count(*) as number_of_properties from mumbai
)
SELECT 
	city_name,number_of_properties,
    (ROUND(number_of_properties/(sum(number_of_properties) over() ) *100,2)) as percentage
    FROM total
    Order by percentage DESC 
    ;
SELECT * FROM chennai;

WITH ranked AS (
    SELECT
        location,
        Price / Area AS ppsf,
        ROW_NUMBER() OVER (PARTITION BY location ORDER BY Price / Area) AS rn_loc,
        COUNT(*) OVER (PARTITION BY location) AS cnt_loc,
        ROW_NUMBER() OVER (ORDER BY Price / Area) AS rn_city,
        COUNT(*) OVER () AS cnt_city
    FROM chennai
    WHERE Area > 0
),

loc_medians AS (
    SELECT
        location,
        AVG(ppsf) AS loc_median
    FROM ranked
    WHERE rn_loc IN (
        FLOOR((cnt_loc + 1) / 2.0),
        FLOOR((cnt_loc + 2) / 2.0)
    )
    GROUP BY location
),

city_median AS (
    SELECT
        AVG(ppsf) AS city_median
    FROM ranked
    WHERE rn_city IN (
        FLOOR((cnt_city + 1) / 2.0),
        FLOOR((cnt_city + 2) / 2.0)
    )
)

SELECT
    l.location,
    l.loc_median,
    c.city_median,
    CONCAT(ROUND(l.loc_median / c.city_median*100,2),'%') AS city_price_index
FROM loc_medians l
CROSS JOIN city_median c
ORDER BY l.loc_median / c.city_median DESC ;



WITH ranked AS (
    SELECT
        location,
        Price / Area AS ppsf,
        ROW_NUMBER() OVER (
            PARTITION BY location
            ORDER BY Price / Area
        ) AS rn,
        COUNT(*) OVER (
            PARTITION BY location
        ) AS cnt
    FROM chennai
    WHERE Area > 0
),

location_median AS (
    SELECT
        location,
        AVG(ppsf) AS location_median_ppsf
    FROM ranked
    WHERE rn IN (
        FLOOR((cnt + 1) / 2.0),
        FLOOR((cnt + 2) / 2.0)
    )
    GROUP BY location
)

SELECT
    p.location,
    p.Price / p.Area AS ppsf,
    lm.location_median_ppsf,

    -- Overpricing Ratio Index
    (p.Price / p.Area) / lm.location_median_ppsf AS ori,

    -- Amenity count
    (
        Gymnasium +
        SwimmingPool +
        Security +
        LiftAvailable +
        CarParking +
        ClubHouse +
        School +
        Hospital +
        Wifi +
        AC
    ) AS amenity_count,

    -- ORI tier
    CASE
        WHEN (p.Price / p.Area) / lm.location_median_ppsf > 1.25 THEN 'Overpriced'
        WHEN (p.Price / p.Area) / lm.location_median_ppsf >= 1.0 THEN 'Premium'
        ELSE 'Value'
    END AS ori_tier

FROM chennai p
JOIN location_median lm
    ON p.location = lm.location
WHERE p.Area > 0;

WITH listing_metrics AS (
    SELECT
        `Location` AS location,
        `Price` / `Area` AS ppsf,

        (
            `Gymnasium` +
            `SwimmingPool` +
            `Security` +
            `LiftAvailable` +
            `CarParking` +
            `ClubHouse` +
            `Wifi` +
            `AC`
        ) AS amenity_count,

        (
            `School` +
            `Hospital` +
            `Security` +
            `Childrens_playarea` +
            `LiftAvailable`
        ) / 5.0 AS fii
    FROM chennai
    WHERE `Area` > 0
),

location_median AS (
    SELECT
        location,
        AVG(ppsf) AS median_ppsf
    FROM (
        SELECT
            location,
            ppsf,
            ROW_NUMBER() OVER (PARTITION BY location ORDER BY ppsf) AS rn,
            COUNT(*) OVER (PARTITION BY location) AS cnt
        FROM listing_metrics
    ) ranked
    WHERE rn IN (
        FLOOR((cnt + 1) / 2),
        FLOOR((cnt + 2) / 2)
    )
    GROUP BY location
),

listing_with_ori AS (
    SELECT
        l.location,
        l.ppsf,
        l.amenity_count,
        l.fii,
        l.ppsf / m.median_ppsf AS ori,

        CASE
            WHEN l.ppsf / m.median_ppsf > 1.25 THEN 'Overpriced'
            WHEN l.ppsf / m.median_ppsf >= 1.0 THEN 'Premium'
            ELSE 'Value'
        END AS ori_tier
    FROM listing_metrics l
    JOIN location_median m
        ON l.location = m.location
)

SELECT
    location,
    COUNT(*) AS total_listings,

    ROUND(
        SUM(CASE WHEN ori_tier = 'Value' THEN 1 ELSE 0 END) / COUNT(*),
        2
    ) AS value_share,

    ROUND(AVG(amenity_count), 1) AS avg_amenities,
    ROUND(AVG(fii), 2) AS avg_fii,
    ROUND(AVG(ppsf), 2) AS avg_ppsf,

    ROUND(
        (0.4 * (
            SUM(CASE WHEN ori_tier = 'Value' THEN 1 ELSE 0 END) / COUNT(*)
        )) +
        (0.3 * AVG(amenity_count)) +
        (0.2 * AVG(fii)) +
        (0.1 * (AVG(ppsf) / 10000)),
        2
    ) AS lias_score

FROM listing_with_ori
GROUP BY location
ORDER BY lias_score DESC;


SELECT
    `No_of_Bedrooms`,
    COUNT(*) AS listings
FROM chennai
GROUP BY `No_of_Bedrooms`
ORDER BY listings DESC;


SELECT
    `Location`,
    ROUND(AVG(`Area`), 0) AS avg_area_sqft
FROM chennai
GROUP BY `Location`
ORDER BY avg_area_sqft DESC;


SELECT
    `Gymnasium`,
    ROUND(AVG(`Price` / `Area`), 2) AS avg_ppsf,
    COUNT(*) AS listings
FROM chennai
WHERE `Area` > 0
GROUP BY `Gymnasium` 
order by Gymnasium desc;


SELECT
    `Location`,
    ROUND(AVG(`Price` / `Area`), 2) AS avg_ppsf
FROM chennai
WHERE `Area` > 0
GROUP BY `Location`
ORDER BY avg_ppsf DESC
LIMIT 5;




