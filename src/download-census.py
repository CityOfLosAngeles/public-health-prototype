# Download Census population data by tract 
# Upload population data and census boundary files to S3

import numpy as np
import pandas as pd
import geopandas as gpd
import os
import boto3
import census
from us import states


# Set env 
# Can't figure out how to read the API key from env
c = census.Census('2dacc2d1fe8ae85c99e2f934a70576d6f731bb0f', year = 2017)
s3 = boto3.client('s3')


# Download 2017 ACS 5-year population data
# 2018 is not available for ACS 5-year
# ACS 1-year doesn't have tract-level data
raw = c.acs5.state_county_tract('B01003_001E', states.CA.fips, '037', census.ALL)
df = pd.DataFrame(raw)


# Subset for LA County
df['GEOID'] = df.state + df.county + df.tract
df = df[['GEOID', 'B01003_001E']]
df = df.sort_values('GEOID', ascending = True)


df.to_parquet('s3://city-of-los-angeles-data-lake/public-health-dashboard/data/raw/pop_by_tract2017.parquet')



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


# Import census tract boundary file
tract = gpd.read_file('s3://city-of-los-angeles-data-lake/public-health-dashboard/gis/source/tl_2019_06_tract/')

# Subset to LA County
tract = tract[tract.COUNTYFP == '037']

keep_me = ['GEOID', 'geometry']
tract = tract[keep_me]

# Write to S3
tract.to_crs({'init':'epsg:2229'}).to_file(driver = 'GeoJSON', filename = './gis/census_tracts.geojson')
s3.upload_file('./gis/census_tracts.geojson', 'city-of-los-angeles-data-lake', 
               'public-health-dashboard/gis/raw/census_tracts.geojson')