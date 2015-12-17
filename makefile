## first we need to install topojson through the terminal
## Install node.js following instructions at https://github.com/mbostock/topojson/wiki/Installation

brew install gdal
brew install node

## Install topojson through terminal
npm install -g topojson

### convert to topojson
# Download the shapefiles and supporting files into the present working directory. 
# Do not store them in a folder in the working directory. 
# It should look like this: wd/xxx.shp or the file won't be read.
# Make sure that any file under the name states1.shp/dbf/shx does not exist within the # folder or we will not be able to create it.
# Make sure that the .shp file is projected under CRS:WGS84.

ogr2ogr states1.shp test1.shp -t_srs "+proj=longlat +ellps=WGS84 +no_defs +towgs84=0,0,0"

# DataMaps knows how to color the map.
# It will do this through id-property
# Need to make sure that the shapefile (dbf) has the CVE_ENT column, NOM_ENT column and OID column
# This can be renamed in QGIS - Table Manager plugin.

topojson -o ccy.json -s 1e-7 -q 1e5 states1.shp -p state_code=+CVE_ENT,name=NOM_ENT --id-property NOM_ENT

# Now have a topojson file "ccy.json"