--metadata fro species numbers 
CREATE SCHEMA IF NOT EXISTS eth; 

--set path for sql processing to act on tables in a specific schema within the database (normally defaults to public otherwise)
SET search_path=eth, public,topology;

--if postgis/postgresql running locally on desktop increase access to memory (RAM) 
SET work_mem TO 120000;
SET maintenance_work_mem TO 120000;
SET client_min_messages TO DEBUG;

--all animals overlapping with regoion
select count(distinct id_no) from
species_overlap_eth_10km;


--add a normal index on column (as used in subsequent joins with large tables)
create index species_overlap_eth_10km_id_no_index
ON species_overlap_eth_10km (id_no);

--breakdown of classes for fauna
select count (distinct (foo1.id_no,foo2.class)), foo2.class from 
species_overlap_eth_10km as foo1  
join 
(select distinct id_no, class from raw.species_seperate_polygons_gridbscale) as foo2
on foo1.id_no=foo2.id_no
group by foo2.class;

--with land cover and links
select count (distinct (foo1.id_no,foo2.class)), foo2.class from 
(select distinct id_no from (select count(distinct foo1.id_no) from 
out_spp_calc_areacells_eth_10km_2013 as foo1,
eth_endemic_subset_anmls_endmc as foo2 where foo1.id_no=foo2.id_no)) as foo1  
join 
(select distinct id_no, class from raw.species_seperate_polygons_gridbscale) as foo2
on foo1.id_no=foo2.id_no
group by foo2.class;

select count(distinct foo1.id_no) from 
out_spp_calc_areacells_eth_10km_2013 as foo1,
eth_endemic_subset_anmls_endmc as foo2
where foo1.id_no=foo2.id_no;




--and for endemic fauna
select count (distinct (foo1.id_no,foo2.class)), foo2.class from 
eth_endemic_subset_anmls_endmc as foo1  
join 
(select distinct id_no, class from raw.species_seperate_polygons_gridbscale) as foo2
on foo1.id_no=foo2.id_no
group by foo2.class;

--overall counts

select count(distinct id_no) from
species_overlap_eth_10km_plnt

select count(distinct id_no) from
eth_endemic_subset_plnt_endmc

--with links to land cover
select count(distinct id_no) from 
out_spp_calc_areacells_eth_10km_2013

select count(distinct foo1.id_no) from 
out_spp_calc_areacells_eth_10km_2013 as foo1,
eth_endemic_subset_anmls_endmc as foo2
where foo1.id_no=foo2.id_no;



select count(distinct id_no) from
eth_endemic_subset_anmls_endmc