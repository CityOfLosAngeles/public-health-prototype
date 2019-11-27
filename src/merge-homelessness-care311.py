# Merge homelessness counts with CARE/CARE+ data at the tract-year level
# Reshape from long to wide?
import numpy as np
import pandas as pd
import geopandas as gpd
import intake
import boto3

catalog = intake.open_catalog('./catalogs/*.yml')
s3 = boto3.client('s3')
bucket_name = 's3://city-of-los-angeles-data-lake/public-health-dashboard/'


homeless = pd.read_parquet(f'{bucket_name}gis/intermediate/homelessness_2017_2019.parquet')

care = gpd.read_file(f'{bucket_name}gis/intermediate/care311_tracts.geojson')

tracts = gpd.read_file(f'{bucket_name}gis/raw/census_tracts.geojson')


# Merge homelessness counts with tract information (keep left because that's the full list of tracts with centroids in City of LA)
m1 = pd.merge(tracts, homeless, on = 'GEOID', how = 'left', validate = '1:m')


# Merge CARE requests with tract information (keep left because that's the full list of tracts with centroids in City of LA)
m2 = pd.merge(m1, care, on = ['GEOID', 'year', 'pop', 'full_area', 'clipped_area'], how = 'left', validate = '1:1')

m2 = m2.drop(columns = ['geometry_y'])
m2.rename(columns = {'geometry_x': 'geometry'}, inplace = True)


# Fill in NaNs with zeroes for CARE service requests
for col in ['bulky', 'encampment', 'illegal', 'other']:
    m2[col] = m2[col].fillna(0)  


# Re-order columns
col_order = ['GEOID', 'SPA', 'SD', 'CD', 'year',
            'unsheltered', 'sheltered', 'tot_homeless', 
            'bulky', 'encampment', 'illegal', 'other', 
            'pop', 'full_area', 'clipped_area', 'geometry']

m2 = m2.reindex(columns = col_order)


# Only keep if there is a CD attached
m2 = m2[m2.CD.notna()]


# Set column types
for col in ['SPA', 'SD', 'CD', 'year', 'bulky', 'encampment', 'illegal', 'other', 'pop']:
    m2[col] = m2[col].astype(int)


# Export to S3
# Use WGS84 so folium and ipyleaflet maps can display
m2.to_crs({'init':'epsg:4326'}).to_file(driver = 'GeoJSON', filename = './gis/homelessness_care_tracts.geojson')

s3.upload_file('./gis/homelessness_care_tracts.geojson', 'city-of-los-angeles-data-lake', 
               'public-health-dashboard/gis/intermediate/homelessness_care_tracts.geojson')