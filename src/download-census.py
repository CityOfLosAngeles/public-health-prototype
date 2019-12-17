# Download Census population data by tract 
## Upload population data and census boundary files to S3 

import numpy as np
import pandas as pd
import geopandas as gpd
import intake
import boto3
import census
from us import states


# Set env 
# Can't figure out how to read the API key from env
c = census.Census('2dacc2d1fe8ae85c99e2f934a70576d6f731bb0f', year = 2017)
catalog = intake.open_catalog('./catalogs/*.yml')
s3 = boto3.client('s3')


#----------------------------------------------------------------#
# Download 2017 ACS 5-year population data
#----------------------------------------------------------------#
# 2018 is not available for ACS 5-year
# ACS 1-year doesn't have tract-level data
raw = c.acs5.state_county_tract('B01003_001E', states.CA.fips, '037', census.ALL)
df = pd.DataFrame(raw)


# Subset for LA County
df['GEOID'] = df.state + df.county + df.tract
df = df[['GEOID', 'B01003_001E']]
df.rename(columns = {'B01003_001E': 'pop'}, inplace = True)
df = df.sort_values('GEOID', ascending = True)


df.to_parquet('s3://public-health-dashboard/data/raw/pop_by_tract2017.parquet')

"""
# The syntax from censusdata is more similar to the R packages
# But, cleaning GEOID from censusdata package is difficult

pop = pd.DataFrame()

for y in range(2017, 2018):
    data = censusdata.download('acs5', y, 
                               censusdata.censusgeo([('state', '06'), ('county', '037'), ('tract', '*')]), 
                               ['B01003_001E'])
    data['year'] = y

pop = pop.append(data)
"""

#----------------------------------------------------------------#
# Import census tracts and clip to City of LA
#----------------------------------------------------------------#
tract = gpd.read_file('s3://public-health-dashboard/gis/raw/tl_2019_06_tract/').to_crs({'init':'epsg:2229'})
city_boundary = catalog.city_boundary.read().to_crs({'init':'epsg:2229'})

# Number of square feet in one square mile
sqft_to_sqmi = 2.788e+7


# Subset to LA County
tract = tract[tract.COUNTYFP == '037']


# Clip tracts to City of LA. Keep if centroid falls within boundary.
centroids = tract.centroid
centroids = pd.DataFrame(centroids)
centroids.rename(columns = {0: 'tract_center'}, inplace = True)


# Merge centroids back on with df
gdf = pd.merge(tract, centroids, left_index = True, right_index = True)
gdf['full_area'] = gdf.geometry.area / sqft_to_sqmi


# Extract the geomery to use to test for intersection
boundary = city_boundary.geometry.iloc[0]


# Test whether centroid is in the city boundary
gdf = gdf.set_geometry('tract_center')
gdf['in_city'] = gdf.within(boundary)


# Only keep tracts whose centroid is within City of LA
tracts_la = gdf.loc[gdf.in_city == True]

# Add clipped geometry and area
tracts_la = tracts_la.set_geometry('geometry')
tracts_la = tracts_la.reset_index()


# Add the geometry for tracts that intersect with boundary (this is all of them, since we already clipped them)
tracts_la['clipped_geom'] = tracts_la[tracts_la.intersects(boundary)].intersection(boundary)
tracts_la['clipped_area'] = tracts_la.set_geometry('clipped_geom').area / sqft_to_sqmi
tracts_la = tracts_la.set_geometry('clipped_geom')


# Clean up columns
keep = ['GEOID', 'clipped_geom', 'full_area', 'clipped_area']
tracts_la = tracts_la[keep]

tracts_with_pop = pd.merge(tracts_la, df, how = 'left', on = 'GEOID', validate = '1:1')


# Write to S3
tracts_with_pop.to_file(driver = 'GeoJSON', filename = './gis/census_tracts.geojson')
s3.upload_file('./gis/census_tracts.geojson', 'public-health-dashboard', 
               'gis/raw/census_tracts.geojson')