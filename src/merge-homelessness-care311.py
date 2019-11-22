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


# Export to S3
# Use WGS84 so folium and ipyleaflet maps can display
m2.to_crs({'init':'epsg:4326'}).to_file(driver = 'GeoJSON', filename = './gis/homelessness_care_tracts.geojson')

s3.upload_file('./gis/homelessness_care_tracts.geojson', 'city-of-los-angeles-data-lake', 
               'public-health-dashboard/gis/intermediate/homelessness_care_tracts.geojson')



""" 
# Homelessness 

# ----------------------------------------------------------------#
# Reshape data from long to wide
# ----------------------------------------------------------------#
tract_characteristics = df2[['GEOID', 'SPA', 'SD', 'CD', 'pop', 'full_area', 'clipped_area', 'geometry']].drop_duplicates()
unshelt = df2[['GEOID', 'year', 'unsheltered']]

unshelt_wide = unshelt.pivot(index = 'GEOID', columns = 'year', values = 'unsheltered').reset_index()
unshelt_wide.rename(columns = {2017: 'unsheltered2017', 2018: 'unsheltered2018', 
                      2019: 'unsheltered2019'}, inplace = True)

# Add change (absolute count differences between years)
unshelt_wide['change_1718'] = unshelt_wide.unsheltered2018 - unshelt_wide.unsheltered2017
unshelt_wide['change_1819'] = unshelt_wide.unsheltered2019 - unshelt_wide.unsheltered2018


# Merge tract characteristics back in and convert into gdf
df3 = pd.merge(tract_characteristics, unshelt_wide, on = 'GEOID', how = 'left', validate = 'm:1')
df3 = gpd.GeoDataFrame(df3)
df3.crs = {'init':'epsg:2229'}


# ----------------------------------------------------------------#
# Add new columns
# ----------------------------------------------------------------#
# Unsheltered density (unsheltered per sq mi); percent unsheltered per 1000 in tract (unsheltered / pop * 1000)
for y in range(2017, 2020):
    unshelt_col = f'unsheltered{y}'
    density_col = f'unshelt_density{y}'
    pct_col = f'pct_unshelt{y}'
    df3[density_col] = df3[unshelt_col] / df3.clipped_area
    df3[pct_col] = df3[unshelt_col] / df3['pop'] * 1000

"""