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


# ----------------------------------------------------------------#
# Import dfs and merge
# ----------------------------------------------------------------#
homeless = pd.read_parquet(f'{bucket_name}gis/intermediate/homelessness_lacity_2017_2019.parquet')

care = gpd.read_file(f'{bucket_name}gis/intermediate/care311_tracts.geojson')

df = pd.merge(homeless, care, on = ['GEOID', 'year', 'geometry', 'full_area', 'clipped_area'], how = 'left', validate = '1:1')

print(df.head())

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