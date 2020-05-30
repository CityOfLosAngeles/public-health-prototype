#!/bin/bash

OUTFILE=city-resources.kml

GRAB_AND_GO_URL="https://www.google.com/maps/d/u/0/kml?mid=1_R_MQhVYaKh3A5_8oAtOtlNK2XWjzP2t"

HANDWASHING_URL="https://services1.arcgis.com/X1hcdGx5Fxqn4d0j/ArcGIS/rest/services/LASANHandwashingStations/FeatureServer/0/query?where=1%3D1&objectIds=&time=&geometry=&geometryType=esriGeometryEnvelope&inSR=&spatialRel=esriSpatialRelIntersects&resultType=none&distance=0.0&units=esriSRUnit_Meter&returnGeodetic=false&outFields=*&returnGeometry=true&featureEncoding=esriDefault&multipatchOption=xyFootprint&maxAllowableOffset=&geometryPrecision=&outSR=&datumTransformation=&applyVCSProjection=false&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnExtentOnly=false&returnQueryGeometry=false&returnDistinctValues=false&cacheHint=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=&returnZ=false&returnM=false&returnExceededLimitFeatures=true&quantizationParameters=&sqlFormat=none&f=pgeojson&token="

RESTROOM_URL="https://services1.arcgis.com/X1hcdGx5Fxqn4d0j/ArcGIS/rest/services/LASANPublicPortableToilets/FeatureServer/0/query?where=1%3D1&objectIds=&time=&geometry=&geometryType=esriGeometryEnvelope&inSR=&spatialRel=esriSpatialRelIntersects&resultType=none&distance=0.0&units=esriSRUnit_Meter&returnGeodetic=false&outFields=*&returnGeometry=true&featureEncoding=esriDefault&multipatchOption=xyFootprint&maxAllowableOffset=&geometryPrecision=&outSR=&datumTransformation=&applyVCSProjection=false&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnExtentOnly=false&returnQueryGeometry=false&returnDistinctValues=false&cacheHint=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=&returnZ=false&returnM=false&returnExceededLimitFeatures=true&quantizationParameters=&sqlFormat=none&f=pgeojson&token="

EMERGENCY_SHELTERS_URL="https://services7.arcgis.com/aFfS9FqkIRSo0Ceu/ArcGIS/rest/services/LARAP%20COVID19%20MPOD%20Public/FeatureServer/0/query?where=1%3D1&objectIds=&time=&geometry=&geometryType=esriGeometryEnvelope&inSR=&spatialRel=esriSpatialRelIntersects&resultType=none&distance=0.0&units=esriSRUnit_Meter&returnGeodetic=false&outFields=*&returnGeometry=true&featureEncoding=esriDefault&multipatchOption=xyFootprint&maxAllowableOffset=&geometryPrecision=&outSR=&datumTransformation=&applyVCSProjection=false&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnExtentOnly=false&returnQueryGeometry=false&returnDistinctValues=false&cacheHint=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=&returnZ=false&returnM=false&returnExceededLimitFeatures=true&quantizationParameters=&sqlFormat=none&f=pgeojson&token="

echo "Downloading resources"

rm -f grabngo.kmz
curl -s -J -L $GRAB_AND_GO_URL -o grabngo.kmz

rm -f handwashing.geojson
curl -s -J -L $HANDWASHING_URL -o handwashing.geojson

rm -f restroom.geojson
curl -s -J -L $RESTROOM_URL -o restroom.geojson

rm -f shelters.geojson
curl -s -J -L $EMERGENCY_SHELTERS_URL -o shelters.geojson

rm -f $OUTFILE

echo "Assembling layers into $OUTFILE"

##################################
# LAUSD Grab and Go Food Centers #
##################################

echo "Writing Grab and Go Layer"

# Merge the sublayers into one.
rm -f grabngo-merged.kmz
ogrmerge.py \
    -f "LIBKML" \
    -single \
    -nln "LAUSD Grab & Go Food Centers" \
    -o grabngo-merged.kmz \
    grabngo.kmz 2> /dev/null # Redirect invalid warning about type conversion
rm grabngo.kmz

# Convert to GeoJSON for the purpose of dropping
# existing styles on the features and adding our
# own. Also add a description field for the final
# KML file.
rm -f grabngo.geojson
ogr2ogr \
    -f "GeoJSON" \
    -fieldTypeToString DateTime \
    -sql "SELECT *, 'Nutritious meals available to all students on weekdays from 7 a.m. to 11 a.m.' AS Description, '@icon-1682-9C27B0' as OGR_STYLE from \"LAUSD Grab & Go Food Centers\"" \
    grabngo.geojson \
    grabngo-merged.kmz
rm grabngo-merged.kmz

# Add to the output layer with our own styling.
LIBKML_DESCRIPTION_FIELD="Description" LIBKML_NAME_FIELD="Name" \
    ogr2ogr \
    -f "LIBKML" \
    -sql "SELECT Name, Description FROM \"LAUSD Grab & Go Food Centers\"" \
    $OUTFILE \
    grabngo.geojson
rm grabngo.geojson

#############################
# Handwashing station layer #
#############################

echo "Writing Handwashing Layer"

# Add to the output layer, including our own styling.
# We pipe it through two ogr2ogr commands in order to
# invoke OGR SQL twice. The first adds a new OGR_STYLE
# column which allows us to target an icon style.
# The second selects final columns for display.
rm -f handwashing2.geojson
ogr2ogr \
    -f "GeoJSON" \
    -fieldTypeToString DateTime \
    -sql "SELECT *, 'Handwashing Station' AS description, '@icon-1703-01579B' AS OGR_STYLE FROM handwashing WHERE Status_Existing = 'ACTIVE'" \
    handwashing2.geojson \
    handwashing.geojson && \
    LIBKML_NAME_FIELD="Address" LIBKML_DESCRIPTION_FIELD="description" \
    ogr2ogr \
    -f "LIBKML" \
    -append \
    -sql "SELECT Address, description FROM handwashing" \
    -nln "Handwashing Stations" \
    $OUTFILE \
    handwashing2.geojson
rm handwashing.geojson handwashing2.geojson

##################
# Restroom layer #
##################

echo "Writing Portable Toilet Layer"

# Add to the output layer, including our own styling.
# We pipe it through three ogr2ogr commands in order to
# invoke SQL three times. The first adds some new columns of
# data to be displayed (such as more user-friendly ADA info).
# The second adds a new OGR_STYLE
# column which allows us to target an icon style.
# The third selects final columns for display.
rm -f restroom2.geojson restroom3.geojson
ogr2ogr \
    -f "GeoJSON" \
    -sql "SELECT *, 'Portable Toilet' as Descriptio, CASE Asset_Type WHEN 'ADA' THEN 'Yes' ELSE 'No' END \"ADA Accessible?\" FROM restroom WHERE Status_Existing = 'ACTIVE'" \
    -dialect SQLITE \
    -nln "Portable Toilets" \
    restroom2.geojson \
    restroom.geojson && \
    ogr2ogr \
    -sql "SELECT *, '@icon-1733-424242' AS OGR_STYLE FROM \"Portable Toilets\"" \
    restroom3.geojson \
    restroom2.geojson && \
    LIBKML_NAME_FIELD="Address" LIBKML_DESCRIPTION_FIELD="Descriptio" \
    ogr2ogr \
    -f "LIBKML" \
    -append \
    -sql "SELECT Descriptio, Address, \"ADA Accessible?\" FROM \"Portable Toilets\"" \
    $OUTFILE \
    restroom3.geojson
rm restroom.geojson restroom2.geojson restroom3.geojson

############################
# Emergency shelters layer #
############################

echo "Writing Emergency Shelter Layer"

# Add to our output layer, including styling.
# We pipe it through two ogr2ogr commands in order to
# invoke OGR SQL two times. The first adds a new OGR_STYLE
# column which allows us to target an icon style.
# The second selects final columns for display.
ogr2ogr \
    -f "GeoJSON" \
    -sql "SELECT *, 'Emergency Shelter' as Description, '@icon-1602-A52714' as OGR_STYLE from shelters" \
    -fieldTypeToString "DateTime" \
    -nln "shelters" \
    shelters2.geojson \
    shelters.geojson &&
    LIBKML_NAME_FIELD="FacilityName" LIBKML_DESCRIPTION_FIELD="Description" \
    ogr2ogr \
    -f "LIBKML" \
    -sql "SELECT FacilityName, Description, Address, ShelterCapacity AS Capacity FROM shelters" \
    -append \
    -nln "Emergency Shelters" \
    $OUTFILE \
    shelters2.geojson
rm shelters.geojson shelters2.geojson

##################
# Postprocessing #
##################
echo "Adding styling information"
python splice_style.py
