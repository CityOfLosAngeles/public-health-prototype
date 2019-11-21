# Import homelessness counts for 2017-2019 by census tract
# Assemble and clip to City of LA
# Reshape from long to wide
# Add new columns to visualize: unsheltered density, percent homeless per 1000 residents

import numpy as np
import pandas as pd
import geopandas as gpd
import intake
import boto3

catalog = intake.open_catalog('./catalogs/*.yml')
s3 = boto3.client('s3')
bucket_name = 's3://city-of-los-angeles-data-lake/public-health-dashboard/'


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

pop = pd.read_parquet(f'{bucket_name}data/raw/pop_by_tract2017.parquet') 

# Merge tracts with their 2017 pop
tracts2 = pd.merge(tracts, pop, on = 'GEOID')

# Merge homelessness counts with tract information
df2 = pd.merge(df, tracts2, on = 'GEOID', how = 'inner', validate = 'm:1')


# Only keep tracts that are in City of LA
df2 = df2[df2.CD != 0]

df2 = df2.drop(columns = ['Tract', 'geometry_x'])
df2.rename(columns = {'geometry_y': 'geometry', 'totPeople': 'tot_homeless',
                      'totUnshelt': 'unsheltered', 'totShelt': 'sheltered'}, inplace = True)

df2 = df2.reindex(columns = ['GEOID', 'SPA', 'SD', 'CD', 'year', 'pop', 
                             'unsheltered', 'sheltered', 'tot_homeless', 'full_area', 'clipped_area', 'geometry'])


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


# Export to S3
df3.to_file(driver = 'GeoJSON', filename = './gis/homelessness_la.geojson')
s3.upload_file('./gis/homelessness_la.geojson', 'city-of-los-angeles-data-lake', 
               'public-health-dashboard/gis/raw/homelessness_lacity_2017_2019.geojson')