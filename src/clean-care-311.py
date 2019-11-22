# Import 311 CARE/CARE+ Requests and clean

import numpy as np
import pandas as pd
import geopandas as gpd
import intake
from shapely.geometry import Point
import boto3

catalog = intake.open_catalog('./catalogs/*.yml')
bucket_name = 's3://city-of-los-angeles-data-lake/public-health-dashboard/'
s3 = boto3.client('s3')

df = catalog.care311.read()

for col in ['createddate', 'updateddate', 'closeddate', 'servicedate']:
    df[col] = pd.to_datetime(df[col])

# Extract year
df['year'] = df['createddate'].dt.year


#-----------------------------------------------------------#
# Create new columns
#-----------------------------------------------------------#
# Define a function that will aggregate Request Type
def request_type(row):
    
    encampment = 0
    bulky = 0
    illegal = 0
    other = 0
    
    if row.requesttype == 'Homeless Encampment':
        encampment = 1
    elif (row.requesttype == 'Bulky Items'):
        bulky = 1
    elif 'Illegal Dumping' in row.requesttype:
        illegal = 1
    elif ((row.requesttype == 'Service Not Complete') or 
          (row.requesttype == 'Metal/Household Appliances') or 
          (row.requesttype == 'Electronic Waste') or 
          (row.requesttype == 'Dead Animal Removal')):
        other = 1
    
    return pd.Series([encampment, bulky, illegal, other], index=['encampment', 'bulky', 'illegal', 'other'])

requests = df.apply(request_type, axis = 1)
df = pd.concat([df, requests], axis = 1)

# Drop if geom is null
df = df[df.geom.notna()]
    
    
#-----------------------------------------------------------#
# Spatial join with census tracts
#-----------------------------------------------------------#
tracts = gpd.read_file(f'{bucket_name}gis/raw/census_tracts.geojson').to_crs({'init':'epsg:4326'})


m1 = gpd.sjoin(df, tracts, how = 'inner', op = 'intersects')

pivot1 = m1.pivot_table(index = ['GEOID', 'year'], 
               values = ['encampment', 'bulky', 'illegal', 'other'], aggfunc = 'sum').reset_index().sort_values(['GEOID', 'year'])


# Pivot wouldn't work with a geometry column. 
# Merge geometry column for tracts back in
pivot1 = pd.merge(pivot1, tracts, on = 'GEOID', validate = 'm:1')

pivot1 = gpd.GeoDataFrame(pivot1)
pivot1.crs = {'init':'epsg:4326'}

            
# Export to S3
pivot1.to_crs({'init':'epsg:2229'}).to_file(driver = 'GeoJSON', filename = './gis/care311_tracts.geojson')

s3.upload_file('./gis/care311_tracts.geojson', 'city-of-los-angeles-data-lake', 
               'public-health-dashboard/gis/intermediate/care311_tracts.geojson')