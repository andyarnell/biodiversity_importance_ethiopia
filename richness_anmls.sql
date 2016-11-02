
---SQL Script created by Andy Arnell -- May 2014---
---Aim: convert landshift data and and species data into values for importance of watersheds for different scenarios---

CREATE SCHEMA IF NOT EXISTS eth; 

--set path for sql processing to act on tables in a specific schema within the database (normally defaults to public otherwise)
SET search_path=eth, public,topology;

--if postgis/postgresql running locally on desktop increase access to memory (RAM) 
SET work_mem TO 120000;
SET maintenance_work_mem TO 120000;
SET client_min_messages TO DEBUG;


drop table if exists species_richness_eth_10km_anmls;
create table species_richness_eth_10km_anmls as
select count(id_no) as richness ,cell_id from out_spp_calc_areacells_eth_10km_2013
 where cell_suitarea_eq_eth_2013>0 group by cell_id;


--join richness layer to shape
drop table if exists species_richness_shpe_eth_10km_anmls;
create table species_richness_shpe_eth_10km_anmls as
select foo1.*, st_transform(foo2.the_geom,4326) as the_geom from
species_richness_eth_10km_anmls as foo1,
cells_eth_10km as foo2
where foo1.cell_id = foo2.cell_id;
--------------------------------------
--endemics

drop table if exists species_richness_eth_10km_anmls_endmc;
create table species_richness_eth_10km_anmls_endmc as
select count(id_no) as richness ,cell_id from (
select foo1.* from out_spp_calc_areacells_eth_10km_2013 as foo1,
eth_endemic_subset_anmls_endmc as foo2 where foo1.id_no=foo2.id_no
) as foo2 where cell_suitarea_eq_eth_2013>0 group by cell_id;

--join richness layer to shape
drop table if exists species_richness_shpe_eth_10km_anmls_endmc;
create table species_richness_shpe_eth_10km_anmls_endmc as
select foo1.*, st_transform(foo2.the_geom,4326) as the_geom from
species_richness_eth_10km_anmls_endmc as foo1,
cells_eth_10km as foo2
where foo1.cell_id = foo2.cell_id;