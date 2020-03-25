OUTFILE=city-resources.kml

GRAB_AND_GO_URL="https://www.google.com/maps/d/u/0/kml?mid=1_R_MQhVYaKh3A5_8oAtOtlNK2XWjzP2t"

HANDWASHING_STATIONS_URL="https://services7.arcgis.com/aFfS9FqkIRSo0Ceu/arcgis/rest/services/LAHSA_PROPOSED_HAND_WASHING_LOCATIONS/FeatureServer/0/query?where=1%3D1&objectIds=&time=&geometry=&geometryType=esriGeometryEnvelope&inSR=&spatialRel=esriSpatialRelIntersects&resultType=none&distance=0.0&units=esriSRUnit_Meter&returnGeodetic=false&outFields=*&returnGeometry=true&featureEncoding=esriDefault&multipatchOption=xyFootprint&maxAllowableOffset=&geometryPrecision=&outSR=&datumTransformation=&applyVCSProjection=false&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnExtentOnly=false&returnQueryGeometry=false&returnDistinctValues=false&cacheHint=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=&returnZ=false&returnM=false&returnExceededLimitFeatures=true&quantizationParameters=&sqlFormat=none&f=pgeojson&token="

TIER_1_SHELTERS_URL="https://services1.arcgis.com/X1hcdGx5Fxqn4d0j/ArcGIS/rest/services/COVID_19_Shelters_Tier1/FeatureServer/0/query?where=1%3D1&objectIds=&time=&geometry=&geometryType=esriGeometryEnvelope&inSR=&spatialRel=esriSpatialRelIntersects&resultType=none&distance=0.0&units=esriSRUnit_Meter&returnGeodetic=false&outFields=*&returnGeometry=true&featureEncoding=esriDefault&multipatchOption=xyFootprint&maxAllowableOffset=&geometryPrecision=&outSR=&datumTransformation=&applyVCSProjection=false&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnExtentOnly=false&returnQueryGeometry=false&returnDistinctValues=false&cacheHint=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=&returnZ=false&returnM=false&returnExceededLimitFeatures=true&quantizationParameters=&sqlFormat=none&f=pgeojson&token="

TIER_2_SHELTERS_URL="https://services1.arcgis.com/X1hcdGx5Fxqn4d0j/ArcGIS/rest/services/COVID_19_Shelters_Tier2/FeatureServer/0/query?where=1%3D1&objectIds=&time=&geometry=&geometryType=esriGeometryEnvelope&inSR=&spatialRel=esriSpatialRelIntersects&resultType=none&distance=0.0&units=esriSRUnit_Meter&returnGeodetic=false&outFields=*&returnGeometry=true&featureEncoding=esriDefault&multipatchOption=xyFootprint&maxAllowableOffset=&geometryPrecision=&outSR=&datumTransformation=&applyVCSProjection=false&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnExtentOnly=false&returnQueryGeometry=false&returnDistinctValues=false&cacheHint=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=&returnZ=false&returnM=false&returnExceededLimitFeatures=true&quantizationParameters=&sqlFormat=none&f=pgeojson&token="

# Use ESRI JSON output format to better get field types. Otherwise some strings
# are incorrectly interpreted as times.
SENIOR_NUTRITION_URL="https://services5.arcgis.com/7nsPwEMP38bSkCjy/arcgis/rest/services/Senior_Nutrition_Dining_Sites_COVID19_20200325/FeatureServer/0/query?where=1%3D1&objectIds=&time=&geometry=&geometryType=esriGeometryEnvelope&inSR=&spatialRel=esriSpatialRelIntersects&resultType=none&distance=0.0&units=esriSRUnit_Meter&returnGeodetic=false&outFields=*&returnGeometry=true&featureEncoding=esriDefault&multipatchOption=xyFootprint&maxAllowableOffset=&geometryPrecision=&outSR=&datumTransformation=&applyVCSProjection=false&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnExtentOnly=false&returnQueryGeometry=false&returnDistinctValues=false&cacheHint=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=&returnZ=false&returnM=false&returnExceededLimitFeatures=true&quantizationParameters=&sqlFormat=none&f=json&token="

echo "Downloading resources"

rm -f grabngo.kmz
curl -s -J -L $GRAB_AND_GO_URL -o grabngo.kmz

rm -f handwashing.geojson
curl -s -J -L $HANDWASHING_STATIONS_URL -o handwashing.geojson

rm -f tier1.geojson
curl -s -J -L $TIER_1_SHELTERS_URL -o tier1.geojson

rm -f tier2.geojson
curl -s -J -L $TIER_2_SHELTERS_URL -o tier2.geojson

rm -f seniors.json
curl -s -J -L $SENIOR_NUTRITION_URL -o seniors.json

rm -f $OUTFILE

echo "Assembling layers into $OUTFILE"

##################################
# LAUSD Grab and Go Food Centers #
##################################

echo "Writing Grab and Go Layer"

# Merge the sublayers into one
rm -f grabngo-merged.kmz
ogrmerge.py \
    -f "LIBKML" \
    -single \
    -nln "LAUSD Grab & Go Food Centers" \
    -o grabngo-merged.kmz \
    grabngo.kmz
rm grabngo.kmz

# Convert to GeoJSON for the sole purpose of dropping
# existing styles on the features.
rm -f grabngo.geojson
ogr2ogr \
    -f "GeoJSON" \
    -fieldTypeToString DateTime \
    grabngo.geojson \
    grabngo-merged.kmz
rm grabngo-merged.kmz

# Add to the output layer with our own styling.
ogr2ogr \
    -f "LIBKML" \
    -sql "SELECT *, '@icon-1682-9C27B0' as OGR_STYLE from \"LAUSD Grab & Go Food Centers\"" \
    $OUTFILE \
    grabngo.geojson
rm grabngo.geojson

#############################
# Handwashing station layer #
#############################

echo "Writing Handwashing Layer"

# Add to the output layer, including our own styling.
LIBKML_NAME_FIELD="Descriptio" \
    ogr2ogr \
     -f "LIBKML" \
    -append \
    -sql "SELECT *, '@icon-1703-01579B' as OGR_STYLE from handwashing" \
    -nln "Handwashing Stations" \
    $OUTFILE \
    handwashing.geojson
rm handwashing.geojson

############################
# Emergency shelters layer #
############################

echo "Writing Emergency Shelter Layer"

# Merge the tier 1 and tier 2 shelters.
rm -f shelters.geojson
ogrmerge.py \
     -f "GeoJSON" \
    -single \
    -nln "Emergency Shelters" \
    -o shelters.geojson \
    tier1.geojson \
    tier2.geojson
rm tier1.geojson tier2.geojson

# Add to our output layer, including styling
LIBKML_NAME_FIELD="Location" \
    ogr2ogr \
    -f "LIBKML" \
    -append \
    -sql "SELECT *, '@icon-1602-A52714' as OGR_STYLE from \"Emergency Shelters\"" \
    -nln "Emergency Shelters" \
    $OUTFILE \
    shelters.geojson
rm shelters.geojson

##################################
# Senior nutrition centers layer #
##################################

echo "Writing Senior Nutrition Layer"

# Add to out output layer, including styling.
LIBKML_NAME_FIELD="NAME" \
    ogr2ogr \
     -f "LIBKML" \
    -s_srs "EPSG:3857" \
    -t_srs "EPSG:4326" \
    -append \
    -sql "SELECT *, '@icon-1578-0F9D58' as OGR_STYLE from seniors" \
    -nln "Senior Nutrition Dining Sites" \
    $OUTFILE \
    seniors.json
rm seniors.json

##################
# Postprocessing #
##################
echo "Adding styling information"
python splice_style.py
