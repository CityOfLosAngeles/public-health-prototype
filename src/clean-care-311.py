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

df = pd.read_csv(f'{bucket_name}data/raw/MyLA311_Service_Requests.csv')

for col in ['CreatedDate', 'UpdatedDate', 'ClosedDate', 'ServiceDate']:
    df[col] = pd.to_datetime(df[col])
    

# Create geometry column from lat/long
df['geometry'] = df.dropna(subset=['Latitude', 'Longitude']).apply(
    lambda x: Point(x.Longitude, x.Latitude), axis = 1)


# Convert to GeoDataFrame
df = gpd.GeoDataFrame(df)
df.crs = {'init':'epsg:4326'}

df = df[df.geometry.notna()]
df = df.to_crs({'init':'epsg:2229'})


#-----------------------------------------------------------#
# Create new columns
#-----------------------------------------------------------#
# Define a function that will aggregate Request Type
def request_type(row):
    
    homeless = 0
    bulky = 0
    illegal = 0
    other = 0
    
    if row.RequestType == 'Homeless Encampment':
        homeless = 1
    elif (row.RequestType == 'Bulky Items'):
        bulky = 1
    elif 'Illegal Dumping' in row.RequestType:
        illegal = 1
    elif ((row.RequestType == 'Service Not Complete') or 
          (row.RequestType == 'Metal/Household Appliances') or 
          (row.RequestType == 'Electronic Waste') or 
          (row.RequestType == 'Dead Animal Removal')):
        other = 1
    
    return pd.Series([homeless, bulky, illegal, other], index=['homeless', 'bulky', 'illegal', 'other'])

requests = df.apply(request_type, axis = 1)
df = pd.concat([df, requests], axis = 1)


# Extract year 
for col in ['CreatedDate', 'UpdatedDate']:
    df[col] = pd.to_datetime(df[col])

    
#-----------------------------------------------------------#
# Spatial join with census tracts
#-----------------------------------------------------------#
tracts = gpd.read_file(f'{bucket_name}gis/raw/census_tracts.geojson')
df['year'] = df.CreatedDate.dt.year

m1 = gpd.sjoin(df, tracts, how = 'inner', op = 'intersects')

pivot1 = m1.pivot_table(index = ['GEOID', 'year'], 
               values = ['homeless', 'bulky', 'illegal', 'other'], aggfunc = 'sum').reset_index().sort_values(['GEOID', 'year'])

# Pivot wouldn't work with a geometry column. 
# Merge geometry column for tracts back in
pivot1 = pd.merge(pivot1, tracts, on = 'GEOID', validate = 'm:1')

pivot1 = gpd.GeoDataFrame(pivot1)
pivot1.crs = {'init':'epsg:2229'}


# Export to S3
pivot1.to_file(driver = 'GeoJSON', filename = './gis/care311_tracts.geojson')

s3.upload_file('./gis/care311_tracts.geojson', 'city-of-los-angeles-data-lake', 
               'public-health-dashboard/gis/intermediate/care311_tracts.geojson')