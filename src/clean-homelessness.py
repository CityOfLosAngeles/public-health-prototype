# Import homelessness counts for 2017-2019 by census tract
# Assemble and clip to City of LA

import numpy as np
import pandas as pd
import geopandas as gpd
import intake
import boto3

catalog = intake.open_catalog('./catalogs/*.yml')
s3 = boto3.client('s3')


# ----------------------------------------------------------------#
# Import homelessness data and append
# ----------------------------------------------------------------#
y2017 = catalog.homeless_2017.read().to_crs({'init':'epsg:2229'})
y2018 = catalog.homeless_2018.read().to_crs({'init':'epsg:2229'})
y2019 = catalog.homeless_2019.read().to_crs({'init':'epsg:2229'})

city_boundary = catalog.city_boundary.read().to_crs({'init':'epsg:2229'})


# Number of square feet in one square mile
sqft_to_sqmi = 2.788e+7


# Make the 3 dfs uniform, then append into one df
raw_dfs = {'2017': y2017, '2018': y2018, '2019': y2019}

df = pd.DataFrame()

for key, value in raw_dfs.items():
    yr = f"{key}"
    new_df = value.copy()
    new_df['year'] = int(yr) 
    # Rename columns
    keep = ['Tract', 'SPA', 'SD', 'CD', 'totUnshelt', 'totShelt', 'totPeople', 'geometry', 'year']
    if key == '2017':
        new_df.rename(columns = {'totSheltPe': 'totShelt'}, inplace = True)
    elif key == '2018':
        new_df.rename(columns = {'Tract_N': 'Tract'}, inplace = True)
    elif key == '2019':
        new_df.rename(columns = {'Tract_N': 'Tract', 'totUnshe_1': 'totUnshelt', 
                                 'totShelt_1': 'totShelt', 'totPeopl_1': 'totPeople'}, inplace = True)
    # Just keep needed columns
    new_df = new_df[keep]
    # Append to existing df
    df = df.append(new_df)

    
# Make GEOID    
df['GEOID'] = '06037' + df.Tract.astype(str)   
    
df = df.to_crs({'init':'epsg:2229'}) 


# Sort
df = df.sort_values(['GEOID', 'year'])

# Export to S3
df.to_file(driver = 'GeoJSON', filename = './gis/homelessness.geojson')
s3.upload_file('./gis/homelessness.geojson', 'city-of-los-angeles-data-lake', 
               'public-health-dashboard/gis/raw/homelessness_2017_2019.geojson')


# ----------------------------------------------------------------#
# Merge homelessness with clipped census tracts
# ----------------------------------------------------------------#
tracts = gpd.read_file('s3://city-of-los-angeles-data-lake/public-health-dashboard/gis/raw/census_tracts.geojson')

final = pd.merge(df, tracts, on = 'GEOID', how = 'inner', validate = 'm:1')

final = final.drop(columns = ['Tract', 'geometry_x'])
final.rename(columns = {'geometry_y': 'geometry'}, inplace = True)

final = final.reindex(columns=['GEOID', 'SPA', 'SD', 'CD', 'year', 
                               'totUnshelt', 'totShelt', 'totPeople', 'full_area', 'clipped_area', 'geometry'])


# Export to S3
final.to_file(driver = 'GeoJSON', filename = './gis/homelessness_la.geojson')
s3.upload_file('./gis/homelessness_la.geojson', 'city-of-los-angeles-data-lake', 
               'public-health-dashboard/gis/raw/homelessness_lacity_2017_2019.geojson')