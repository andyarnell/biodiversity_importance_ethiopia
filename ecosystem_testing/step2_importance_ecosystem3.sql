
--set path for sql processing to act on tables in a specific schema within the database (normally defaults to public otherwise)
SET search_path=eth,eth_wkshp1,public,topology;

--if postgis/postgresql running locally on desktop increase access to memory (RAM) 
SET work_mem TO 120000;
SET maintenance_work_mem TO 120000;
SET client_min_messages TO DEBUG;


--full intersection (currently intersection in wgs84 and then areas calculated in mollweide. This version matched better, though not perfectly, with results for vector overlays than converting raster to Mollweide before intersecting)
drop table if exists raw_lc_areas_cells_10km_eth_2013;
CREATE TABLE raw_lc_areas_cells_10km_eth_2013 AS
 SELECT cell_id, 
        sum(st_area(st_transform((gv).geom,54009))) AS area_lc_cell,
        (gv).val as lc
 FROM (SELECT cell_id, 
              /*ST_Intersection(rast, the_geom) AS gv  */ st_dumpaspolygons((St_clip(rast,the_geom))) AS gv  --the st_dumpaspolygons is best if quick (but less accurate) method is needed
       FROM raw.lc_eth_2013_res300,
            (
SELECT cell_id, 
the_geom
--st_buffer(st_transform(the_geom,4326),0) as the_geom  
FROM cells_eth_10km
) as bob
       WHERE ST_Intersects(rast, the_geom)
      ) foo
group by (gv).val, cell_id;

select * from raw_lc_areas_cells_10km_eth_2013;

/*
--make table for importing semi-raw landshift outputs
--(after processing rasters through seperate python script into csv tables --
--and then converting to long format with r script)
DROP TABLE IF EXISTS raw_lc_areas_cells_10km_eth_2013;
CREATE TABLE raw_lc_areas_cells_10km_eth_2013 
(
cell_id VARCHAR,
lc numeric,
area_lc_cell numeric
)
WITH (OIDS=FALSE);
*/
  


ALTER TABLE raw_lc_areas_cells_10km_eth_2013
  OWNER TO postgres;
  

/*
COPY raw_lc_areas_cells_10km_eth_2013
(cell_id,
lc,
area_lc_cell)
FROM
'C:\data\lshift_all\outputs\10km_eth_2013.csv' CSV DELIMITER ',' HEADER;


--Alter table raw_lc_areas_cells_10km_eth_2013
--ADD COLUMN id bigserial NOT NULL,
--ADD constraint raw_lc_areas_cells_10km_eth_2013_pkey PRIMARY KEY (id);

*/

--import tables of landcover/landuse for scenarios and baseline
--use land cover lookup table (lc_lut) to link crosswalk values to all landshift values eg. 100 into 100,101,102...120) (N.B. for natureserve there is no change as glc2000 and no landshift values)
DROP TABLE IF EXISTS lc_areas_cells_eth_10km_2013;
CREATE TABLE lc_areas_cells_eth_10km_2013 AS
SELECT 
b.cell_id as cell_id, 
l.lc_lookup AS lc, 
b.area_lc_cell as area_lc_cell
FROM 
raw_lc_areas_cells_10km_eth_2013 as b, 
lc_lut_eth_10km as l
where b.lc = l.lc_raw;



--this next table creation sql seems to take a lot of time compared to the rest of the simple functions (especially when many cells)
select * from lc_areas_cells_eth_10km_2013;

DROP TABLE IF EXISTS out_spp_allsuitareacells_eth_10km_2013_shr;
CREATE TABLE out_spp_allsuitareacells_eth_10km_2013_shr AS 
SELECT
h.taxonid as id_no,
/*h.species as  firstofspecies, */
lc.cell_id as cell_id, 
sum(lc.area_lc_cell) AS sumofarea_lc_cell 
FROM lc_areas_cells_eth_10km_2013 AS lc 
inner join 
(
select distinct taxonid, /*species,*/ suitlc  
from 
(
select distinct spchabimpdesc, taxonid, suitlc
from habitat_prefs_eth_10km 
where suitlc in ('16','18')
)
as foo1,
(select id_no, species from raw.species_eoo_gridbscale) as foo2
where spchabimpdesc = 'Suitable' 
and foo1.taxonid = foo2.id_no
) AS h 
on lc.lc = h.suitlc
GROUP BY h.taxonid, /*h.species,*/ lc.cell_id;




/*note this is where you filer the ecosystem type*/
                             
--add column 
ALTER TABLE out_spp_allsuitareacells_eth_10km_2013_shr 
ADD cell_sp varchar;
--add unique id for combination of cell and species
UPDATE out_spp_allsuitareacells_eth_10km_2013_shr
SET 
cell_sp = (cell_id/*::numeric(20,4)*/)  || '_' || id_no /*firstofspecies*/;



-- add an index
ALTER TABLE out_spp_allsuitareacells_eth_10km_2013_shr
ADD COLUMN id bigserial NOT NULL,
ADD constraint out_spp_allsuitareacells_eth_10km_2013_shr_pkey PRIMARY KEY (id);



--view subset of result to check
-- SELECT * FROM out_spp_allsuitareacells_eth_10km_2013_shr LIMIT 1000; 
/*SELECT os.*, (os.sumofarea_lc_cell/c.cell_area) as prop, c.cell_area 
FROM (select * from out_spp_allsuitareacells_eth_10km_2013_shr) os, cells_eth_10km as c  
WHERE c.cell_id=os.cell_id /*and (os.sumofarea_lc_cell/c.cell_area) >1 */ order by c.cell_id;
*/

/*
From Access notes:
To reduce the species table to just those species/watershed combinations where the species occurs in the watershed 
(i.e. the overlap proportion is greater than zero) and calculate the area of suitable habitat within the watershed for a species.
Currently the suitable areas table does not account for the overlap of the species and the watershed. This is included in this output table.
The area of suitable habitat can be calculated using:
(1) Equal distribution assumption: Assumes that the distribution of the land covers is equal across the species overlap. 
For example, a species overlapping half of a watershed where forest was its only suitable habitat would overlap half of the total forest area.
(2) Maximal distribution assumption: Assumes that the species preferentially occurs in suitable habitat
(3) Minimum distribution assumption: Assumes that the species overlaps unsuitable habitat
*/

--This query will create a table with equal, min and max suitable area options described above
DROP TABLE IF EXISTS  out_spp_calc_areacells_eth_10km_2013_shr;
CREATE TABLE out_spp_calc_areacells_eth_10km_2013_shr AS
select 
/*sp.species, */
sp.id_no,
sp.cell_sp, 
sp.cell_prop, 
(sp.cell_prop::numeric) * op.sumofarea_lc_cell as cell_suitarea_eq_eth_2013,
CASE WHEN sp.area<op.sumofarea_lc_cell THEN
sp.area ELSE op.sumofarea_lc_cell END as cell_suitarea_max_eth_2013,
CASE WHEN sp.area>((c.cell_area)-(op.sumofarea_lc_cell)) THEN
(sp.area-(c.cell_area-op.sumofarea_lc_cell)) ELSE 0 END as cell_suitarea_min_eth_2013,
sp.cell_id 
FROM 
species_overlap_eth_10km AS sp 
INNER JOIN 
out_spp_allsuitareacells_eth_10km_2013_shr as op 
ON sp.cell_sp = op.cell_sp
INNER JOIN 
cells_eth_10km AS c ON op.cell_id = c.cell_id
WHERE (((sp.cell_prop)<>0));

--add an id column as a primary key
ALTER TABLE out_spp_calc_areacells_eth_10km_2013_shr
ADD COLUMN id bigserial NOT NULL,
ADD constraint out_spp_calc_areacells_eth_10km_2013_shr_pkey PRIMARY KEY (id);


--check how many remain
-- SELECT count(1) from (select species from out_spp_calc_areacells_eth_10km_2013_shr group by species) as foo;

--view subset of result to check it worked - 
-- SELECT * FROM out_spp_calc_areacells_eth_10km_2013_shr LIMIT 1000;


--checking orignal species overlap with watershed areas and the proportions between them 
--occasionally a mismatch (cell_prop > 1) between these as calculated in different software --ideally all processing is in postgis so should agree
--SELECT sp.*, c.cell_area FROM species_overlap_eth_10km sp, cells_eth_10km c WHERE sp.cell_id = c.cell_id and sp.cell_prop >.9999; 


--Calculate the total area of suitable habitat in the region
DROP TABLE IF EXISTS  out_spp_allsuitarearegion_eth_10km_2013;
CREATE TABLE out_spp_allsuitarearegion_eth_10km_2013 AS
SELECT /*o.species, */ o.id_no,
SUM(o.cell_suitarea_max_eth_2013) AS sumofcell_suitarea_max_eth_2013, 
SUM(o.cell_suitarea_eq_eth_2013) AS sumofcell_suitarea_eq_eth_2013, 
SUM(o.cell_suitarea_min_eth_2013) AS sumofcell_suitarea_min_eth_2013 
FROM out_spp_calc_areacells_eth_10km_2013_shr AS o
GROUP BY o.id_no/*, o.species*/;
