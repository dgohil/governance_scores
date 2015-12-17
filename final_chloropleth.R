# Get data

library(plyr)
library(XLConnect)
gov <- loadWorkbook("~/Documents/NRT/scomms/Github/governance/gov_scores.xlsx")
gov1 <- readWorksheet(gov, 1)
# Do not convert data to factor. ichoropleth only recognizes numeric or character data

library(rgdal)
library(foreign) # To read the dbf file
# "GeoJSON" %in% ogrDrivers()$name
# ogrDrivers() checks whether the drivers are present

# The dbf from the state shapefile needed to merge with the df state_code and names
codes <- read.dbf("states1.dbf")
#names(codes)
codes$NOM_ENT <- iconv(codes$NOM_ENT, "windows-1252", "utf-8")
codes$CVE_ENT <- as.numeric(codes$CVE_ENT)
codes$OID <- NULL
names(codes) <- c("state_code","area", "name", "pop","yr_reg","area_km")

# Replace all spaces in state names with "_" in the topojson file
library(stringr)
con <- file("ccy.json", "r") # get an incomplete final line error.
tpjson <- readLines(con)
close(con)
for(i in 1:19) {
  tpjson <- str_replace_all(tpjson, codes$name[i],
                            str_replace_all(codes$name[i], " ", "_"))
}

# Sum performance_score by conservancy,nrt_area etc and group by conservancy and nrt_area and year
# We first need make reshape the data to make it "long". This will allow us to crete dropdown menu to change
# the data that displays.

library(reshape)
gov2 <- reshape(gov1,
                varying=c("registration",
                          "agm",
                          "community_support",
                          "board_rotation",
                          "hr_procedures",
                          "annual_audit",
                          "budget_process",
                          "budget_execution",
                          "revenue_sharing_bylaws",
                          "revenue_publication",
                          "quarterly_reporting",
                          "fundraising",
                          "donor_relations",
                          "asset_management",
                          "partnerships",
                          "performance_score"),
                v.names="gov_score",
                timevar="gov_parameter",
                times=c("registration",
                        "agm",
                        "community_support",
                        "board_rotation",
                        "hr_procedures",
                        "annual_audit",
                        "budget_process",
                        "budget_execution",
                        "revenue_sharing_bylaws",
                        "revenue_publication",
                        "quarterly_reporting",
                        "fundraising",
                        "donor_relations",
                        "asset_management",
                        "partnerships",
                        "performance_score"),
                direction="long")


library(data.table) # For below setnames command
setnames(gov2, "conservancy", "name")

# Subsets for only performance_score
gov3 <- subset(gov2, gov_parameter == "performance_score")

library(dplyr)
gov_all <- gov3 %>%
  filter(year %in% 2012:2014) %>% 
  group_by(nrt_area, name, year) %>%
  arrange(name)

# Names needed for the map
gov_final <- plyr::join(gov_all, codes)

# Cut the data into quantiles
gov_map <- transform(gov_all,
                 fillKey = cut(gov_score, breaks = 5, labels = LETTERS[1:5])
                 )


keyNames <- levels(gov_map$fillKey)

# Associate fill colors
library(RColorBrewer)
colourCount = 5
getPalette = colorRampPalette(brewer.pal(9, "Reds"))
#my_cols <- rev(getPalette(colourCount)) # if you want to reverse palette
my_cols <- getPalette(colourCount)
my_cols[6] <- c("#E5E5E5") # Greys out areas where there's no data

library(RColorBrewer)
fills = setNames(
  c(my_cols),
  c(levels(gov_map$fillKey), 'defaultFill')
)
  
gov_map1 <- plyr::dlply((gov_map), "year", function(x){
  y = rCharts::toJSONArray2(x, json = F)
  names(y) = lapply(y, '[[', 'name')
  return(y)
})

# Below code creates the animated choropleth map
library(rMaps)
d1 <- Datamaps$new()
d1$set(
  geographyConfig = list(
    dataUrl = "ccy.json",
    popupTemplate =  "#! function(geography, data) { //this function should just return a string
          return '<div class=hoverinfo><strong>' + geography.properties.name + '</strong></div>';
    }  !#"
  ),
  dom='chart_1',
  scope = 'states1',
  labels=TRUE,
  bodyattrs = "ng-app ng-controller=rChartsCtrl",  
  setProjection = '#! function( element, options ) {
   var projection, path;
   projection = d3.geo.mercator()
    .center([38, 1.3]) //centers the map on the conservancies
    .scale(10000) // makes it larger
    .translate([element.offsetWidth / 2, element.offsetHeight / 2]);

   path = d3.geo.path().projection( projection );

   return {path: path, projection: projection};

  } !#',
  fills = fills,
  data = gov_map1[[1]],
  legend = TRUE,
  labels = TRUE
)
d1$save('governance.html', cdn = TRUE)

d1$addAssets(
  jshead = "http://cdnjs.cloudflare.com/ajax/libs/angular.js/1.2.1/angular.min.js"
)
d1$setTemplate(chartDiv = "
               <div class='container'>
               <input id='slider' type='range' min=2012 max=2014 ng-model='year' width=200>
               <span ng-bind='year'></span>
               <div id = 'chart_1' class = 'rChart datamaps'>
               <script>
               function rChartsCtrl($scope){
               $scope.year = '2012';
               $scope.$watch('year', function(newYear){
               mapchart_1.updateChoropleth(chartParams.newData[newYear]);
               })
               }
               </script>
               </div>   "
)
d1$set(newData = gov_map1)
d1$save("governance.html", cdn = TRUE, standalone=TRUE)