list.of.packages <- c("data.table", "httr","XML","jsonlite","sp", "rgdal", "openxlsx")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)
lapply(list.of.packages, require, character.only=T)

wd = "/home/alex/git/IATI-VCE-Chad-Geo"
setwd(wd)

locats = fread("location_data.csv")
# Commented out so you can use "geonames.RData" below. But demonstrates how API works
# Make sure to replace "demo" with your geonames username

# admin = subset(locats,code!="")
# 
# geonames = subset(admin,vocabulary=="G1")
# osm = subset(admin,vocabulary=="G2")
# iso = subset(admin,vocabulary=="A4")
# 
# geonames$country = NA
# geonames$name = NA
# 
# unique_geonames = unique(subset(geonames,is.na(country))$code)
# bad_codes = c("07", "01", "0", "PPLC")
# unique_geonames = setdiff(unique_geonames, bad_codes)
# 
# base_url = "http://api.geonames.org/getJSON?username=demo&id="
# 
# for(unique_geoname in unique_geonames){
#   geonames_id = as.integer(unique_geoname)
#   geonames_url = paste0(base_url,geonames_id)
#   if(GET(geonames_url)$status==200){
#     geonames_contents = fromJSON(geonames_url)
#     name = geonames_contents$asciiName
#     country = geonames_contents$countryCode
#     lat = geonames_contents$lat
#     long = geonames_contents$lng
#     geonames$name[which(geonames$code==unique_geoname)] = name
#     geonames$country[which(geonames$code==unique_geoname)] = country
#     geonames$lat[which(geonames$code==unique_geoname)] = lat
#     geonames$long[which(geonames$code==unique_geoname)] = long
#     Sys.sleep(5)
#   }
# }
# 
# save(geonames,file="geonames.RData")
load("geonames.RData")
td_geonames = subset(geonames,country=="TD")
fwrite(td_geonames,"td_geonames.csv")
geonames_coords = td_geonames[,c("iati_identifier", "lat", "long")]
geonames_coords$lat = as.numeric(geonames_coords$lat)
geonames_coords$long = as.numeric(geonames_coords$long)
geonames_coords = subset(geonames_coords,!is.na(lat) & !is.na(long))
geonames_coords$source = "Geonames"

coords = subset(locats,!is.na(lat) & !is.na(long))
coords$code = NULL
coords$level = NULL
coords$vocabulary = NULL
coords$name = NULL
coords$source = "point/pos"
coords = rbind(coords,geonames_coords)
coordinates(coords)=~long+lat

td = readOGR("chad_shapefile/tcd_admbnda_adm1_ocha.shp")
proj4string(coords) = proj4string(td)
over_dat = over(coords,td)
coords$adm1 = over_dat$admin1Name

plot(td)
td_coords = subset(coords,!is.na(adm1))
points(td_coords)

td_coords_df = td_coords@data
td_coords_df$lat = td_coords$lat
td_coords_df$long = td_coords$long

fwrite(td_coords_df,"td_coords.csv")

td_coords = data.table(td_coords_df[,c("iati_identifier", "adm1")])

td_coords[,location_count := .N, by = .(iati_identifier)]

transactions = read.xlsx("TD_14092021_2016-2021.xlsx", check.names=F, sep.names=" ")

setnames(
  td_coords,
  "iati_identifier",
  "IATI Identifier"
)

transactions = merge(
  transactions,
  td_coords,
  by="IATI Identifier",
  all.x=T
)

names(transactions) = make.names(names(transactions))

transactions = subset(
  transactions,
  Transaction.Type %in% c("2 - Outgoing Commitment", "4 - Expenditure") &
    adm1 != "No subnational locations"
)

trans.tab = data.table(transactions)[,.(value = sum(Value..USD., na.rm=T)), by=.(adm1)]
trans.tab$value = trans.tab$value / 1000000

td.f = fortify(td,region="admin1Name")
setnames(td.f,"id","adm1")

td.f = merge(td.f,trans.tab,by="adm1",all.x=T)

# Set our stops for the legend
palbins = c(1, 2, 10, 50, 80, 200, 1500)
names(palbins)=c("> 1", "< 2", "10", "50", "80", "200", "> 1,500")
pal = brewer_pal()(length(palbins))

# And draw a map using geom_polygon
ggplot(td.f)+
  geom_polygon( aes(x=long,y=lat,group=group,fill=value,color="#eeeeee",size=0.21))+
  coord_fixed(1) + # 1 to 1 ratio for longitude to latitude
  # or coord_cartesian() +
  scale_fill_gradientn(
    na.value="#d0cccf",
    guide="legend",
    breaks=palbins,
    colors=pal,
    values=rescale(palbins)
  ) +
  scale_color_identity()+
  scale_size_identity()+
  expand_limits(x=td.f$long,y=td.f$lat)+
  theme_classic()+
  theme(axis.line = element_blank(),axis.text=element_blank(),axis.ticks = element_blank())+
  guides(fill=guide_legend(title="USD millions"))+
  labs(x="",y="")
