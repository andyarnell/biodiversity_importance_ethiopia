
-----------------------------------------------------------------------------------------------------------
----------------------code for exporting shapefiles - just for normalised anmls currently 
/*

--For exporting using ogr2ogr (osgeo4w command line) into separate shapefiles for change maps

ogr2ogr --config FGDB_BULK_LOAD YES  -progress -f "ESRI Shapefile" -sql "SELECT * FROM eth.out_cell_imp_shape_eth_10km_2013_anmls_endmc" C:\Data\final_bd_results\eth_2013\anmls_endmc PG:"host=localhost user=postgres password=Seltaeb1 dbname=biodiv_processing" -nln out_cell_imp_shape_eth_10km_2013_anmls_endmc -nlt POLYGON -lco "SHPT=POLYGON"  -a_srs "EPSG:4326"

ogr2ogr --config FGDB_BULK_LOAD YES  -progress -f "ESRI Shapefile" -sql "SELECT * FROM eth.out_cell_imp_shape_eth_10km_2013_anmls" C:\Data\final_bd_results\eth_2013\anmls PG:"host=localhost user=postgres password=Seltaeb1 dbname=biodiv_processing" -nln out_cell_imp_shape_eth_10km_2013_anmls -nlt POLYGON -lco "SHPT=POLYGON"  -a_srs "EPSG:4326"


ogr2ogr --config FGDB_BULK_LOAD YES  -progress -f "ESRI Shapefile" -sql "SELECT * FROM eth.out_cell_imp_shape_eth_10km_2013_plnt_endmc" C:\Data\final_bd_results\eth_2013\plnt_endmcs PG:"host=localhost user=postgres password=Seltaeb1 dbname=biodiv_processing" -nln out_cell_imp_shape_eth_10km_2013_plnt_endmc -nlt POLYGON -lco "SHPT=POLYGON"  -a_srs "EPSG:4326"

ogr2ogr --config FGDB_BULK_LOAD YES  -progress -f "ESRI Shapefile" -sql "SELECT * FROM eth.out_cell_imp_shape_eth_10km_2013_plnt" C:\Data\final_bd_results\eth_2013\plnts PG:"host=localhost user=postgres password=Seltaeb1 dbname=biodiv_processing" -nln out_cell_imp_shape_eth_10km_2013_plnt -nlt POLYGON -lco "SHPT=POLYGON"  -a_srs "EPSG:4326"


ogr2ogr --config FGDB_BULK_LOAD YES  -progress -f "ESRI Shapefile" -sql "SELECT * FROM eth.species_richness_shpe_eth_10km_anmls_endmc" C:\Data\final_bd_results\eth_2013\anmls_endmc PG:"host=localhost user=postgres password=Seltaeb1 dbname=biodiv_processing" -nln species_richness_shpe_eth_10km_anmls_endmc -nlt POLYGON -lco "SHPT=POLYGON"  -a_srs "EPSG:4326"

ogr2ogr --config FGDB_BULK_LOAD YES  -progress -f "ESRI Shapefile" -sql "SELECT * FROM eth.species_richness_shpe_eth_10km_anmls" C:\Data\final_bd_results\eth_2013\anmls PG:"host=localhost user=postgres password=Seltaeb1 dbname=biodiv_processing" -nln species_richness_shpe_eth_10km_anmls -nlt POLYGON -lco "SHPT=POLYGON"  -a_srs "EPSG:4326"


ogr2ogr --config FGDB_BULK_LOAD YES  -progress -f "ESRI Shapefile" -sql "SELECT * FROM eth.species_richness_shpe_eth_10km_plnt_endmc" C:\Data\final_bd_results\eth_2013\plnt_endmcs PG:"host=localhost user=postgres password=Seltaeb1 dbname=biodiv_processing" -nln species_richness_shpe_eth_10km_plnt_endmc -nlt POLYGON -lco "SHPT=POLYGON"  -a_srs "EPSG:4326"

ogr2ogr --config FGDB_BULK_LOAD YES  -progress -f "ESRI Shapefile" -sql "SELECT * FROM eth.species_richness_shpe_eth_10km_plnt" C:\Data\final_bd_results\eth_2013\plnts PG:"host=localhost user=postgres password=Seltaeb1 dbname=biodiv_processing" -nln species_richness_shpe_eth_10km_plnt -nlt POLYGON -lco "SHPT=POLYGON"  -a_srs "EPSG:4326"





*/
