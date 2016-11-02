--richness layer creation

CREATE SCHEMA IF NOT EXISTS eth; 

--set path for sql processing to act on tables in a specific schema within the database (normally defaults to public otherwise)
SET search_path=eth, public,topology;

--if postgis/postgresql running locally on desktop increase access to memory (RAM) 
SET work_mem TO 120000;
SET maintenance_work_mem TO 120000;
SET client_min_messages TO DEBUG;

drop table if exists species_richness_eth_10km_plnt;
create table species_richness_eth_10km_plnt as
select count(id_no) as richness ,cell_id from species_overlap_eth_10km_plnt where area>0 group by cell_id;

--join richness layer to shape
drop table if exists species_richness_shpe_eth_10km_plnt;
create table species_richness_shpe_eth_10km_plnt as
select foo1.*, st_transform(foo2.the_geom,4326) as the_geom from
species_richness_eth_10km_plnt as foo1,
cells_eth_10km as foo2
where foo1.cell_id = foo2.cell_id;
--------------------------------------
--endemics

drop table if exists species_richness_eth_10km_plnt_endmc;
create table species_richness_eth_10km_plnt_endmc as
select count(id_no) as richness ,cell_id from (
select foo1.* from species_overlap_eth_10km_plnt as foo1,
eth_endemic_subset_plnt_endmc as foo2 where foo1.id_no=foo2.id_no
) as foo2 where area>0 group by cell_id;

--join richness layer to shape
drop table if exists species_richness_shpe_eth_10km_plnt_endmc;
create table species_richness_shpe_eth_10km_plnt_endmc as
select foo1.*, st_transform(foo2.the_geom,4326) as the_geom from
species_richness_eth_10km_plnt_endmc as foo1,
cells_eth_10km as foo2
where foo1.cell_id = foo2.cell_id;