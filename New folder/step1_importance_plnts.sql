
---SQL Script created by Andy Arnell -- May 2014---
---Aim: convert landshift data and and species data into values for importance of watersheds for different scenarios---

CREATE SCHEMA IF NOT EXISTS eth; 

--set path for sql processing to act on tables in a specific schema within the database (normally defaults to public otherwise)
SET search_path=eth, public,topology;

--if postgis/postgresql running locally on desktop increase access to memory (RAM) 
SET work_mem TO 120000;
SET maintenance_work_mem TO 120000;
SET client_min_messages TO DEBUG;

/*
--manually import shapefile of watersheds (already in mollweide in this case - otherwise need to transform)
--create table of cells and calculate areas column (metres) from imported shapefile of watersheds (already in world mollweide)
--may need to adapt the where clause to suit cell_ids
drop table if exists cells_eth_10km;
create table cells_eth_10km as
select cell_id as cell_id, the_geom as the_geom, 
(st_area(the_geom)::numeric)
 as cell_area from lev08_cells_all_prj
where lower(cell_id) like 'lvb%';
*/
----------------------

--add a normal index on column (as used in subsequent joins with large tables)
create index cells_eth_10km_cell_id_index
ON cells_eth_10km (cell_id);

-------------------------

-- these three steps should create and clean up spatial index
CREATE INDEX cells_eth_10km_geom_gist ON cells_eth_10km USING GIST (the_geom);
CLUSTER cells_eth_10km USING cells_eth_10km_geom_gist;
ANALYZE cells_eth_10km;


DROP TABLE IF EXISTS species_intersecting_eth_10km_temp_plnt;
CREATE TABLE species_intersecting_eth_10km_temp_plnt as
select st_buffer((the_geom),0) as the_geom, id_no, binomial as species from raw.iucn_2014_red_list_plants_ethiopia_prj_clp;

--calculate total area of species (eoo) range by summing across polygons
DROP TABLE IF EXISTS iucn_2014_red_list_plants_ethiopia_prj_eoo_area;
CREATE TABLE iucn_2014_red_list_plants_ethiopia_prj_eoo_area as
select 
id_no, 
sum(st_area(the_geom)) as eoo_area from raw.iucn_2014_red_list_plants_ethiopia_prj group by id_no;

-- make a temporary table of species intersecting the resion/cells of interest to put into intersection query 
-- this should increase efficiency for the following steps where processing intersection,
-- as this step reduces dataset to only those polygons that intersect the region
DROP TABLE IF EXISTS raw.species_intersecting_eth_10km_temp;
CREATE TABLE raw.species_intersecting_eth_10km_temp as
SELECT id_no, species, the_geom
FROM 
(
select distinct sp.* 
from 
--raw.species_seperate_polygons_gridbscale as sp, 
(
select st_makevalid(st_buffer((st_tranform(the_geom,54009)),0)) as the_geom, id_no, binomial as species from raw.iucn_2014_red_list_plants_ethiopia_prj_clp
)
 as sp,
(select st_union(the_geom) as the_geom from cells_eth_10km) as r 
where ST_INTERSECTS (r.the_geom, sp.the_geom)
) as sel;

select * from raw.IUCN_2014_red_list_plants_Ethiopia_prj_clp

select count(*) from species_intersecting_eth_10km_plnt_temp;

-- these three steps should create and clean up spatial index

CREATE INDEX species_intersecting_eth_10km_plnt_temp_geom_gist ON species_intersecting_eth_10km_temp USING GIST (the_geom);
CLUSTER species_intersecting_eth_10km_plnt_temp USING species_intersecting_eth_10km_temp_plnt_geom_gist;
ANALYZE species_intersecting_eth_10km_plnt_temp;


--add a normal index on column (as used in subsequent joins with large tables)
create index species_intersecting_eth_10km_temp_id_no_index
ON species_intersecting_eth_10km_temp (id_no);


--temporary stop to code - this is an important part if not already run
-- creating intersect of cells and species 
--with only those species intersecting the region 
--to speed up intersection results there is a nested of 'case when st_within'
--this is to avoid the comparatively slow processing of the st_intersection function where possible
DROP TABLE IF EXISTS species_overlap_eth_10km_plnt;
create table species_overlap_eth_10km_plnt as 
SELECT c.id_no,c.species as species, 
sum(st_area (case when st_within(p.the_geom,c.the_geom) 
then p.the_geom else 
(
case when st_within(c.the_geom,p.the_geom) 
then c.the_geom else st_intersection (p.the_geom,c.the_geom) end 
)
end )) AS area, 
cell_id
FROM cells_eth_10km AS p 
inner join 
species_intersecting_eth_10km_temp_plnt
--raw.species_seperate_polygons_gridbscale
 AS c 
on p.the_geom && c.the_geom and ST_Intersects(p.the_geom,c.the_geom)
GROUP BY c.id_no,c.species, p.cell_id;


-- add columns to table and update these
ALTER TABLE species_overlap_eth_10km_plnt
drop column if exists cell_sp,
drop column if exists cell_prop,
ADD COLUMN cell_sp varchar,
ADD COLUMN cell_prop numeric;
--update id column
UPDATE species_overlap_eth_10km_plnt 
SET cell_sp = cell_id || '_' || id_no /*species*/;
--update proportion columns from cell areas
UPDATE species_overlap_eth_10km_plnt 
SET cell_prop = species_overlap_eth_10km_plnt.area/cells_eth_10km.cell_area 
from cells_eth_10km where species_overlap_eth_10km_plnt.cell_id=cells_eth_10km.cell_id;

--add a normal index on column (as used in subsequent joins with large tables)
create index species_overlap_eth_10km_plnt_cell_sp_index
ON species_overlap_eth_10km_plnt (cell_sp);

CLUSTER species_overlap_eth_10km_plnt USING species_overlap_eth_10km_plnt_cell_sp_index;
ANALYZE species_overlap_eth_10km_plnt;

select * from species_overlap_eth_10km_plnt limit 1000;

--backup results in text file as there can be a long processing time for making this table 
-- can choose location and name,
--though when storing locally the my documents folder may have permission issues regular folders in C: drive normally fine though)
COPY species_overlap_eth_10km_plnt
TO 'C:\data\backups\species_eth_10km_overlap_postgis_figs_backup.txt' CSV DELIMITER ';' HEADER;


-- TO SAVE HARD DISK SPACE - can remove the temp file assuming all worked ok
DROP TABLE IF EXISTS species_intersecting_eth_10km_temp;			


----------------------------------------------------------------------------------------------------------------------------------------
--AIM: create table to calculate area (m2) of species overlap within whole reggion --i.e. does not depend on suitable habitat
--this becomes part of main importance formula
DROP TABLE IF EXISTS out_spp_allarearegion_eth_10km_plnt;
CREATE TABLE out_spp_allarearegion_eth_10km_plnt AS
SELECT /*sp.species,*/ sp.id_no, sum(sp.area) AS sumofarea
FROM species_overlap_eth_10km_plnt AS sp
GROUP BY /*sp.species*/ sp.id_no;
--add an id column as a primary key
ALTER TABLE out_spp_allarearegion_eth_10km_plnt
ADD COLUMN id bigserial NOT NULL,
ADD CONSTRAINT out_spp_allarearegion_eth_10km_plnt_pkey PRIMARY KEY (id);
