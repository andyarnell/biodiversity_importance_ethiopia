
--set path for sql processing to act on tables in a specific schema within the database (normally defaults to public otherwise)
SET search_path=eth,eth_wkshp1,public,topology;

--if postgis/postgresql running locally on desktop increase access to memory (RAM) 
SET work_mem TO 120000;
SET maintenance_work_mem TO 120000;
SET client_min_messages TO DEBUG;



--Calculate the total area of suitable habitat in the region
DROP TABLE IF EXISTS  out_spp_allsuitarearegion_eth_10km_2013_plnt;
CREATE TABLE out_spp_allsuitarearegion_eth_10km_2013_plnt AS
SELECT o.id_no,
SUM(o.area) AS sumofcell_suitarea_eq_eth_2013_pln
FROM species_overlap_eth_10km_plnt AS o
GROUP BY o.id_no/*, o.species*/;
