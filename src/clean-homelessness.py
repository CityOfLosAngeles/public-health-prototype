# Import homelessness counts for 2017-2019 by census tract
# Assemble and clip to City of LA

import numpy as np
import pandas as pd
import geopandas as gpd
import intake

catalog = intake.open_catalog('./catalogs/*.yml')
bucket_name = 's3://city-of-los-angeles-data-lake/public-health-dashboard/'


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
    keep = ['Tract', 'SPA', 'SD', 'CD', 'totUnshelt', 'totShelt', 'totPeople', 'year']
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
    

# Only keep tracts that are in City of LA
df = df[df.CD != 0]

df = df.drop(columns = ['Tract'])
df.rename(columns = {'totPeople': 'tot_homeless', 'totUnshelt': 'unsheltered', 
                    'totShelt': 'sheltered'}, inplace = True)

df = df.reindex(columns = ['GEOID', 'SPA', 'SD', 'CD', 'year', 'pop', 
                             'unsheltered', 'sheltered', 'tot_homeless'])

df = df.sort_values(['GEOID', 'year'])


# Export to S3
df.to_parquet(f'{bucket_name}gis/intermediate/homelessness_2017_2019.parquet')