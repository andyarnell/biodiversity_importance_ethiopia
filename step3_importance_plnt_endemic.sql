
                        --set path for sql processing to act on tables in a specific schema within the database (normally defaults to public otherwise)
SET search_path=eth,lvb_wkshp1,public,topology;

--if postgis/postgresql running locally on desktop increase access to memory (RAM) 
SET work_mem TO 120000;
SET maintenance_work_mem TO 120000;
SET client_min_messages TO DEBUG;

/*
--find subset of species that are endemic
drop table if exists eth_endemic_subset_plnt_endmc;
create table eth_endemic_subset_plnt_endmc as
select foo1.id_no
--,foo3.sumofarea/foo1.eoo_area as endemic
from 
(select st_union(the_geom) as the_geom, id_no from raw.iucn_2014_red_list_plants_ethiopia_prj group by id_no)
 as foo1,
eth_adm0 as foo2,
out_spp_allarearegion_eth_10km AS foo3
where 
foo3.id_no=foo1.id_no and
st_within(foo1.the_geom,foo2.the_geom);

*/

/*
--alternative method but less precise 
drop table if exists eth_endemic_subset_plnt_endmc;
create table eth_endemic_subset_plnt_endmc as
SELECT
spo.id_no,
osrun.sumofarea/spo.eoo_area as endemic
FROM
iucn_2014_red_list_plants_ethiopia_prj_eoo_area AS spo,
out_spp_allarearegion_eth_10km_plnt AS osrun
where
spo.id_no = osrun.id_no 
AND osrun.sumofarea/spo.eoo_area >=0.99999
order by 
osrun.sumofarea/spo.eoo_area desc
;
*/ 


--importance script which calculates importance for subsets: i)  all species ii) IUCN threatened (CR EN VU)  species, iii) mammals, iv) birds, and v) amphibians 
DROP TABLE IF EXISTS out_sppimp_eth_10km_2013_plnt_endmc;
CREATE TABLE out_sppimp_eth_10km_2013_plnt_endmc AS 
SELECT /*osrd.species,*/ osrd.id_no, osrd.cell_id, osrd.cell_sp,
CASE WHEN 
osra.sumofcell_suitarea_eq_eth_2013_pln=0 
THEN 0 ELSE ((osrd.cell_prop/osra.sumofcell_suitarea_eq_eth_2013_pln)*(osrun.sumofarea/spo.eoo_area)) END 
AS sppimp_eq
FROM
iucn_2014_red_list_plants_ethiopia_prj_eoo_area AS spo,
species_overlap_eth_10km_plnt AS osrd,
out_spp_allsuitarearegion_eth_10km_2013_plnt AS osra,
out_spp_allarearegion_eth_10km_plnt AS osrun
, /*statusandtaxonomy AS st*/ 
(
select distinct id_no--, class as class_name, category as code
from
iucn_2014_red_list_plants_ethiopia_prj_eoo_area
) as st
, eth_endemic_subset_plnt_endmc as ends
WHERE
/*osrd.species = osra.species AND
osrun.species = osrd.species AND
spo.species = osrun.species AND
lower(st.friendly_name) = lower(osrd.species)*/
osrd.id_no = osra.id_no AND
osrun.id_no = osrd.id_no AND
spo.id_no = osrun.id_no AND
st.id_no = osrd.id_no AND
ends.id_no=osrd.id_no

--AND lower(st.class_name) in ('amphibia','aves','mammalia');
--view subset of result to check it worked - 
-- SELECT * FROM out_sppimp_eth_10km_2013_plnt_endmc ORDER BY cell_sp LIMIT 1000;


--see how many species have values 
-- SELECT COUNT(1) from (select /*species as species*/ id_no from out_sppimp_eth_10km_2013_plnt_endmc group by id_no/*species*/) as foo;


--should be same as the count on the input table out_spp_calc_areacells_eth_10km_2013_plnt_endmc
-- SELECT count(1) from (select /*species as species*/ id_no from out_spp_calc_areacells_eth_10km_2013_plnt_endmc group by id_no/*species*/) as foo;

 
--see if null rows are null in all columns
-- SELECT * FROM out_sppimp_eth_10km_2013_plnt_endmc WHERE sppimp_eq IS NULL ORDER BY cell_sp;


--make final importance values for watersheds by grouping by watershed ids
DROP TABLE IF EXISTS out_cell_imp_eth_10km_2013_plnt_endmc;
CREATE TABLE out_cell_imp_eth_10km_2013_plnt_endmc AS
SELECT o.cell_id, SUM(o.sppimp_eq) AS cellimp_eq--, SUM(o.sppimp_max) AS cellimp_max, SUM(o.sppimp_min) AS cellimp_min 
FROM out_sppimp_eth_10km_2013_plnt_endmc as o
GROUP BY o.cell_id;


--join final results to watershed polygons for viewing
DROP TABLE IF EXISTS out_cell_imp_shape_eth_10km_2013_plnt_endmc;
CREATE TABLE out_cell_imp_shape_eth_10km_2013_plnt_endmc AS 
SELECT o.*, p.the_geom as the_geom  
FROM 
out_cell_imp_eth_10km_2013_plnt_endmc AS o,
cells_eth_10km AS p 
WHERE o.cell_id=p.cell_id;

--convert to wgs84 for viewing purposes
ALTER TABLE out_cell_imp_shape_eth_10km_2013_plnt_endmc
 ALTER COLUMN the_geom TYPE geometry(MultiPolygon,4326) 
  USING ST_Transform(the_geom,4326);
  