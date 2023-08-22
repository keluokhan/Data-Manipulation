-- I've downloaded this dataset from kaggle to play around it and practise my PostgreSQL skills
-- Here is the link to the data: https://www.kaggle.com/datasets/nikdavis/steam-store-games to 
-- Many thanks to the owner of the data it gave me a lot of ideas and I've learned quite a lot using it

-- GENARAL INFORMATION ON DATASET
-- Data contains steam store games with release date from 1997-06-30 until 2019-05-01
-- columns hold the following information about games:
-- appid: a unique identifier
-- name: title of a game
-- release_date: release date of the game in the YYYY-MM-DD format
-- english: english language support 1=True
-- developer: Name of developer, semicolon delimited if multiple
-- publisher: Name of publisher, semicolon delimited if multiple
-- platforms: supported platforms, semicolon delimited if multiple
-- required_age: Minimum required age according to PEGI UK standards. Many with 0 are unrated or unsupplied.
-- categories: Semicolon delimited list of game categories, e.g. single-player;multi-player
-- genres: Semicolon delimited list of game genres, e.g. action;adventure
-- steamspy_tags: Semicolon delimited list of top steamspy game tags, similar to genres but community voted, e.g. action;adventure
-- achievements: Number of in-games achievements, if any
-- positive_ratings: Number of positive ratings, from SteamSpy
-- negative_ratings: Number of negative ratings, from SteamSpy
-- average_playtime: Average user playtime, from SteamSpy
-- median_playtime: Median user playtime, from SteamSpy
-- owners: Estimated number of owners. Contains lower and upper bound (like 20000-50000)
-- price: Current full price of title in GBP

select *
from steam

-- Back up 
--CREATE TABLE steam_backup AS
--SELECT * FROM steam;

-- Dividing owners column into lower and upper bounds, casting owners column from text to integer to get average number of owners
WITH cte AS (
    SELECT
        appid,
        (CAST(SUBSTRING(owners FROM POSITION('-' IN owners) + 1) AS INTEGER) + CAST(SUBSTRING(owners FROM 0 FOR POSITION('-' IN owners) - 1) AS INTEGER)) / 2 AS avg_num_owners
    FROM
        steam
)
UPDATE steam AS s
SET owners = cte.avg_num_owners
FROM cte
WHERE s.appid = cte.appid;


with cte as
(select appid, (cast(substring(owners from position('-' in owners)+1 for length(owners)) as int)+cast(substring(owners from 0 for position('-' in owners)-1) as int))/2 as avg_num_owners
from steam)
update steam as s
inner join cte 
on s.appid=cte.appid
set s.owners = cte.avg_num_owners;

-- altering owners column to integer dtype
ALTER TABLE steam
ALTER COLUMN owners TYPE integer USING owners::integer;

-- comparing updated owners column to 
select s.owners, sb.owners
from steam s
join steam_backup sb 
on s.appid=sb.appid  

-- temporary table of top rated games by player ratings excluding where average_playtime is 0 and total ratings are equal to or more than 100
drop table rated_games;
create table rated_games
(
appid int,
release_date date,
name text,
developer text,
platforms text,
steamspy_tags text,
total_ratings int,
rating numeric
);

insert into rated_games
select appid, release_date, name, developer, platforms, steamspy_tags, (positive_ratings + negative_ratings) as total_ratings,
ROUND(positive_ratings*100/(positive_ratings + negative_ratings), 0) as rating
from steam
where average_playtime <> 0 and (positive_ratings + negative_ratings) >= 100
order by rating desc, release_date desc;

select *
from rated_games;

-- top rated MMORPGs
select *
from rated_games
where steamspy_tags like '%MMORPG%' and rating>70
order by release_date desc;

-- average number of owners of top rate MMORPGs
select s.name, rg.total_ratings, rg.rating, s.owners
from steam s 
join rated_games rg
on s.appid = rg.appid
where rg.steamspy_tags like '%MMORPG%' and rg.rating>70
order by s.release_date desc;

-- list of games at 0 cost which are worth playing or not
select s.appid, s.release_date, s.name, s.developer, s.steamspy_tags, owners, price, total_ratings, rating,
case when rating>=90 then 'wow'
	 when rating<90 and rating>=70 then 'good game'
	 when rating<70 and rating>=50 then 'not bad'
	 when rating<50 and rating>=30 then 'bad game'
	 else 'trash' end as worthplaying
from steam s 
join rated_games rg
on s.appid = rg.appid
where s.price=0
order by rating desc, owners desc;

-- game suggestion function/procedure, enter a game tag you would like to play to get the list of games ordered by rating and owners
CREATE OR REPLACE FUNCTION what_to_play(in_mood_for_tag text)
RETURNS TABLE (
    appid int,
    release_date date,
    name text,
    developer text,
    steamspy_tags text,
    owners int,
    price real,
    total_ratings int,
    rating numeric,
    worthplaying text
) AS
$$
BEGIN
    RETURN QUERY
    SELECT
        s.appid,
        s.release_date,
        s.name,
        s.developer,
        s.steamspy_tags,
        s.owners,
        s.price,
        rg.total_ratings,
        rg.rating,
        CASE
            WHEN rg.rating >= 90 THEN 'wow'
            WHEN rg.rating < 90 AND rg.rating >= 70 THEN 'good game'
            WHEN rg.rating < 70 AND rg.rating >= 50 THEN 'not bad'
            WHEN rg.rating < 50 AND rg.rating >= 30 THEN 'bad game'
            ELSE 'trash'
        END AS worthplaying
    FROM
        steam s
    JOIN
        rated_games rg ON s.appid = rg.appid
    WHERE
        s.steamspy_tags LIKE '%' || in_mood_for_tag || '%'
    ORDER BY
        rg.rating DESC,
        s.owners DESC;
END;
$$
LANGUAGE plpgsql;

SELECT * FROM what_to_play('Action');

-- Playing around data
select count(distinct categories) as num_of_cat, count(distinct genres) as num_of_genres, Count(distinct steamspy_tags) as num_of_st
from steam s

select appid, categories, genres, steamspy_tags
from steam s 
where length(categories) = 
(select min(length(categories)) from steam)
UNION
select appid, categories, genres, steamspy_tags
from steam s 
where length(genres) = 
(select min(length(genres)) from steam)
UNION
select appid, categories, genres, steamspy_tags
from steam s 
where length(steamspy_tags) = 
(select min(length(steamspy_tags)) from steam);

select name, english, genres
from steam
where length(genres) = 
(select max(length(genres)) from steam)


