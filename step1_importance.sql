
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
--accidental editing - need to revert to animal datraset-- select st_makevalid(st_buffer((st_tranform(the_geom,54009)),0)) as the_geom, id_no, binomial as species from raw.iucn_2014_red_list_plants_ethiopia_prj_clp
)
 as sp,
(select st_union(the_geom) as the_geom from cells_eth_10km) as r 
where ST_INTERSECTS (r.the_geom, sp.the_geom)
) as sel;

select * from raw.IUCN_2014_red_list_plants_Ethiopia_prj_clp

select count(*) from species_intersecting_eth_10km_temp;

-- these three steps should create and clean up spatial index

CREATE INDEX species_intersecting_eth_10km_temp_geom_gist ON species_intersecting_eth_10km_temp USING GIST (the_geom);
CLUSTER species_intersecting_eth_10km_temp USING species_intersecting_eth_10km_temp_geom_gist;
ANALYZE species_intersecting_eth_10km_temp;


--add a normal index on column (as used in subsequent joins with large tables)
create index species_intersecting_eth_10km_temp_id_no_index
ON species_intersecting_eth_10km_temp (id_no);


--temporary stop to code - this is an important part if not already run
-- creating intersect of cells and species 
--with only those species intersecting the region 
--to speed up intersection results there is a nested of 'case when st_within'
--this is to avoid the comparatively slow processing of the st_intersection function where possible
DROP TABLE IF EXISTS species_overlap_eth_10km;
create table species_overlap_eth_10km as 
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
species_intersecting_eth_10km_temp
--raw.species_seperate_polygons_gridbscale
 AS c 
on p.the_geom && c.the_geom and ST_Intersects(p.the_geom,c.the_geom)
GROUP BY c.id_no,c.species, p.cell_id;


-- add columns to table and update these
ALTER TABLE species_overlap_eth_10km
drop column if exists cell_sp,
drop column if exists cell_prop,
ADD COLUMN cell_sp varchar,
ADD COLUMN cell_prop numeric;
--update id column
UPDATE species_overlap_eth_10km 
SET cell_sp = cell_id || '_' || id_no /*species*/;
--update proportion columns from cell areas
UPDATE species_overlap_eth_10km 
SET cell_prop = species_overlap_eth_10km.area/cells_eth_10km.cell_area 
from cells_eth_10km where species_overlap_eth_10km.cell_id=cells_eth_10km.cell_id;

--add a normal index on column (as used in subsequent joins with large tables)
create index species_overlap_eth_10km_cell_sp_index
ON species_overlap_eth_10km (cell_sp);

CLUSTER species_overlap_eth_10km USING species_overlap_eth_10km_cell_sp_index;
ANALYZE species_overlap_eth_10km;

select * from species_overlap_eth_10km limit 1000;

--backup results in text file as there can be a long processing time for making this table 
-- can choose location and name,
--though when storing locally the my documents folder may have permission issues regular folders in C: drive normally fine though)
COPY species_overlap_eth_10km
TO 'C:\data\backups\species_eth_10km_overlap_postgis_figs_backup.txt' CSV DELIMITER ';' HEADER;


-- TO SAVE HARD DISK SPACE - can remove the temp file assuming all worked ok
DROP TABLE IF EXISTS species_intersecting_eth_10km_temp;			


----------------------------------------------------------------------------------------------------------------------------------------
--AIM: create table to calculate area (m2) of species overlap within whole reggion --i.e. does not depend on suitable habitat
--this becomes part of main importance formula
DROP TABLE IF EXISTS out_spp_allarearegion_eth_10km;
CREATE TABLE out_spp_allarearegion_eth_10km AS
SELECT /*sp.species,*/ sp.id_no, sum(sp.area) AS sumofarea
FROM species_overlap_eth_10km AS sp
GROUP BY /*sp.species*/ sp.id_no;
--add an id column as a primary key
ALTER TABLE out_spp_allarearegion_eth_10km
ADD COLUMN id bigserial NOT NULL,
ADD CONSTRAINT out_spp_allarearegion_eth_10km_pkey PRIMARY KEY (id);


--view subset of result to check it worked - 
-- SELECT * FROM out_spp_allarearegion_eth_10km LIMIT 1000;

---------------------------------------------------------------------------------------------------------------------

-- AIM: this section of sql creates a status and taxonomy lookup table and imports taxonomic and iucn status data from text file
-- this is used in later steps (importance and change scripts) and enables splitting into subsets when looking at results, by either status or taxonomy.
-- at this stage in processing it also allows you to check you to look at general species composition for those species that overlap area (i.e. species_eoo)
-- ideally filtering of relevant species (e.g. extant etc) from IUCN should have been carried out prior to upload of shapefiles/text files into database

-- create table to store text file of taxonomic info and status from IUCN
/*
DROP TABLE IF EXISTS statusandtaxonomy;
CREATE TABLE statusandtaxonomy
(
id numeric,
kingdom_name varchar, 
phylum_name varchar, 
class_name varchar, 
order_name varchar, 
family_name varchar, 
genus_name varchar, 
species_name varchar, 
friendly_name varchar, 
code varchar,
CONSTRAINT statusandtaxonomy_pkey primary key (friendly_name)
)
WITH (OIDS=FALSE);
ALTER TABLE statusandtaxonomy
  OWNER TO postgres;
*/
-- import info from text file into new table
/*
COPY statusandtaxonomy 
(id,
kingdom_name, 
phylum_name, 
class_name, 
order_name, 
family_name, 
genus_name, 
species_name, 
friendly_name, 
code) FROM
'C:\Data\Taxonomic_data_for_import\wcmc_taxonomy_edt1.csv' delimiter ',' header CSV; */


------------------------------------------------------------------------------------------------------
--AIM: importing and crosswalking IUCN habitat data with LCCS/landshift output
--ONCE CORRECT (FOR MACARTHUR PROJECT) THIS SECTION FOR CODING AND CROSSWALK CAN STAY THE SAME FOR ALL SCENARIOS AND REGIONS

--make a table to store csv habitat info before importing cleaned info into habitat_prefs_eth_10km table
DROP TABLE IF EXISTS habitat_prefs_eth_10km_cleaning;
CREATE TABLE habitat_prefs_eth_10km_cleaning (
id bigserial NOT NULL,
taxonid BIGINT,
friendly_name VARCHAR,
suitability VARCHAR,
habitatsclass VARCHAR,
season VARCHAR,
majorimportance VARCHAR,
CONSTRAINT habitat_prefs_eth_10km_cleaning_pkey PRIMARY KEY (id)
)
WITH (OIDS=FALSE);
ALTER TABLE habitat_prefs_eth_10km_cleaning
  OWNER TO postgres;



--import data from the text file of habitat preferences into the habitat_prefs_eth_10km_cleaning table
COPY habitat_prefs_eth_10km_cleaning (taxonid,friendly_name,habitatsclass,suitability,season,majorimportance) 
FROM
'C:\Data\Habitats_IUCN_for_import\nature_serve_new_habitat_affiliations\WCMC_Habitat_Info2_Aug2014_AA.csv' delimiter ',' CSV HEADER ;


----add a normal index on column (as used in subsequent joins with large tables)
--create index habitat_prefs_eth_10km_cell_sp_index
--ON habitat_prefs_eth_10km_cell_sp_index (cell_sp);



--prior to importing to dbase make sure a version of the crosswalk from xls file into a text file format compatible (i.e. text tab delimited) for upload with only necessary columns i.e. no spaces in titles
--make a table to help convert iucn habitat affiliations to glc2000 classes (from lndshift output) via crosswalk text file (columns made to fit those from text file)
--N.B. sense checks should be made on results of crosswalks
DROP TABLE IF EXISTS iucn_crosswalk_eth_10km;
CREATE TABLE iucn_crosswalk_eth_10km (
id bigserial NOT NULL,
iucn_middle_level_code VARCHAR,
iucndescription VARCHAR,
glc2000code VARCHAR,
glc2000description VARCHAR,
CONSTRAINT iucn_crosswalk_eth_10km_pkey PRIMARY KEY (id)
)
WITH (OIDS=FALSE);
ALTER TABLE iucn_crosswalk_eth_10km
  OWNER TO postgres;



-- need to remove spaces from titles and they must match the ones here 
--N.B. don't reimport this as you can end up with multiple crosswalks in one table - rememeber to delete and rebuild this table (sql above) if need to update this --(in future could implement a unique code to be present when importing to stop this)
COPY iucn_crosswalk_eth_10km (iucn_middle_level_code,iucndescription,glc2000code,glc2000description) 
FROM
'C:\Data\GLC2000_crosswalk_for_import\GLCCrossWalk_Updated_20150310.txt' delimiter '	' CSV HEADER ;


--make habitat_prefs_eth_10km table from selected columns out of -
--the habitat_prefs_eth_10km_cleaning table and joined to the crosswalk table -
--by iucn code (iucn code extracted using split_part function)
DROP TABLE IF EXISTS habitat_prefs_eth_10km;
CREATE TABLE habitat_prefs_eth_10km AS
SELECT
hc.taxonid as taxonid,
/*hc.friendly_name AS species, */ 
hc.suitability AS spchabimpdesc, 
split_part(hc.habitatsclass,' ',1) AS iucn_code, 
hc.habitatsclass as iucn_desc,
cw.glc2000code AS suitlc,
cw.glc2000description as glc2000description
FROM 
habitat_prefs_eth_10km_cleaning AS hc, 
iucn_crosswalk_eth_10km AS cw 
WHERE split_part(hc.habitatsclass,' ',1) = cw.iucn_middle_level_code;

--add primary key and id column to habitat_prefs_eth_10km table
ALTER TABLE habitat_prefs_eth_10km
ADD COLUMN id bigserial NOT NULL,
ADD CONSTRAINT habitat_prefs_eth_10km_pkey PRIMARY KEY (id);

--add a normal index on column (as used in subsequent joins with large tables)
create index habitat_prefs_eth_10km_taxonid_index
ON habitat_prefs_eth_10km (taxonid);

--add a normal index on column (as used in subsequent joins with large tables)
create index habitat_prefs_eth_10km_suitlc_index
ON habitat_prefs_eth_10km (suitlc);

CLUSTER habitat_prefs_eth_10km USING habitat_prefs_eth_10km_taxonid_index;
CLUSTER habitat_prefs_eth_10km USING habitat_prefs_eth_10km_suitlc_index;
ANALYZE habitat_prefs_eth_10km;

/* -- -- not needed as using id_no to split and identify species
UPDATE habitat_prefs_eth_10km
SET species = trim(initcap(split_part (species,' ',1))||' '||  lower(split_part (species,' ',2)));

*/
--also check crosswalk visually and for NULLs - ie. where affiliations exist but crosswalk has nothing 
--(this first select should give no result if all is well)
SELECT iucn_desc, glc2000description FROM habitat_prefs_eth_10km WHERE glc2000description IS NULL GROUP BY iucn_desc, glc2000description order by iucn_desc, glc2000description;

--ideally such a step is not needed as the crosswalk table should be comprehensive for all codes coming out of the land use model
--AIM: creating a lookup table to code changes to some (crops, grazing etc) of the lshifts outputs to fit LCCS classification into a code that links to glc2000 crosswalk with IUCN
-- e.g. makes crops combined and coded as 100 for use in crosswalk, when actually all numbers between 100 and 120 are crop types in landshift outputs

DROP TABLE IF EXISTS lc_lut_eth_10km;
CREATE TABLE lc_lut_eth_10km (
id bigserial NOT NULL,
lc_raw integer,
lc_lookup varchar,
CONSTRAINT lc_lut_eth_10km_pkey PRIMARY KEY (id)
)
WITH (OIDS=FALSE);
ALTER TABLE lc_lut_eth_10km
 OWNER TO postgres;
   


--lookup table for converting. 
--N.B. don't reimport this as you can end up with multiple crosswalks in one table - remember to delete and rebuild this table (sql above) if need to update this --(in future could implement a unique code to be present when importing to stop this)
-- used the values between 100 and 120 (crop) as 100 in the lookup table for glc2000. 
-- used 201 (grazing) as 200, and 200 as 200
--don't 
-- set-aside left as 99 (i.e. not counted).
INSERT INTO lc_lut_eth_10km (lc_raw,lc_lookup) VALUES 
(0,0),
(1,1),
(2,2),
(3,3),
(4,4),
(5,5),
(6,6),
(7,7),
(8,8),
(9,9),
(10,10),
(11,11),
(12,12),
(13,13),
(14,14),
(15,15),
(16,16),
(17,17),
(18,18),
(19,19),
(20,20),
(21,21),
(22,22),
(23,23),
(99,200),
(100,100),
(101,100),
(102,100),
(103,100),
(104,100),
(105,100),
(106,100),
(107,100),
(108,100),
(109,100),
(110,100),
(111,100),
(112,100),
(113,100),
(114,100),
(115,100),
(116,100),
(117,100),
(118,100),
(119,100),
(120,100),
(200,200),
(201,200);


