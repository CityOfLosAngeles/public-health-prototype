"""
Functions to create county or state-specific indicators.
Use JHU county data.
"""
import altair as alt
import pandas as pd

from IPython.display import display

US_COUNTY_URL = (
    "http://lahub.maps.arcgis.com/sharing/rest/content/items/"
    "8aba663239fc428f8bcdc48e213e3172/data"
)

LA_CITY_URL = (
    "http://lahub.maps.arcgis.com/sharing/rest/content/items/"
    "7175fba373f541a7a19df56b6a0617f4/data"
)

TESTING_URL = (
    "http://lahub.maps.arcgis.com/sharing/rest/content/items/"
    "158dab4a07b04ecb8d47fea1746303ac/data")

HOSPITAL_URL = (
    "http://lahub.maps.arcgis.com/sharing/rest/content/items/"
    "3da1eb3e13a14743973c96b945bd1117/data"
)

CROSSWALK_URL = (
    "https://raw.githubusercontent.com/CityOfLosAngeles/aqueduct/master/dags/"
    "public-health/covid19/msa_county_pop_crosswalk.csv"
)

# Define colors
navy = "#0A4C6A"
maroon = "#A30F23"


# County-level case data
def case_indicators_county(county_name, start_date):
    county_df = pd.read_csv(US_COUNTY_URL, dtype={"fips": "str"})

    keep_cols = [
        "county",
        "state",
        "fips",
        "date",
        "Lat",
        "Lon",
        "cases",
        "deaths",
        "new_cases",
        "new_deaths",
    ]

    county_df["date"] = pd.to_datetime(county_df.date)

    df = (
        county_df[((county_df.county == county_name) | 
                   (county_df.fips == county_name))
                  & (county_df.date >= start_date)][
            keep_cols
        ]
        .sort_values(["county", "state", "fips", "date"])
        .reset_index(drop=True)
    )

    # Derive new columns
    df = df.assign(
        # 7-day rolling average for new cases
        cases_avg7=df.new_cases.rolling(window=7).mean(),
        # 3-day rolling average for new deaths
        deaths_avg3=df.new_deaths.rolling(window=3).mean(),
    )

    # Make cases charts
    cases_chart = (
        alt.Chart(df)
        .mark_line()
        .encode(
            x=alt.X("date", timeUnit="monthdate", title="date"),
            y=alt.Y("cases_avg7", title="7-day avg"),
            color=navy,
        )
        .properties(title=f"{county_name} County: New Cases",)
        .configure_title(fontSize=14, font="Roboto", anchor="middle", color="Black")
        .configure_axis(gridOpacity=0.4,)
    )

    # Make deaths chart
    deaths_chart = (
        alt.Chart(df)
        .mark_line()
        .encode(
            x=alt.X("date", timeUnit="monthdate", title="date"),
            y=alt.Y("deaths_avg3", title="3-day avg"),
            color=maroon,
        )
        .properties(title=f"{county_name} County: Deaths",)
        .configure_title(fontSize=14, font="Roboto", anchor="middle", color="Black")
        .configure_axis(gridOpacity=0.4,)
    )

    display(cases_chart)
    display(deaths_chart)

    return df


# State-level case data
def case_indicators_state(state_name, start_date):
    county_df = pd.read_csv(US_COUNTY_URL, dtype={"fips": "str"})

    keep_cols = [
        "state",
        "date",
        "state_cases",
        "state_deaths",
        "new_state_cases",
        "new_state_deaths",
    ]

    county_df["date"] = pd.to_datetime(county_df.date)

    df = (
        county_df[(county_df.state == state_name) & (county_df.date >= start_date)][
            keep_cols
        ]
        .sort_values(["state", "date"])
        .drop_duplicates()
        .rename(
            columns={
                "state_cases": "cases",
                "state_deaths": "deaths",
                "new_state_cases": "new_cases",
                "new_state_deaths": "new_deaths",
            }
        )
        .reset_index(drop=True)
    )

    # Derive new columns
    df = df.assign(
        # 7-day rolling average for new cases
        cases_avg7=df.new_cases.rolling(window=7).mean(),
        # 3-day rolling average for new deaths
        deaths_avg3=df.new_deaths.rolling(window=3).mean(),
    )

    # Make cases charts
    cases_chart = (
        alt.Chart(df)
        .mark_line()
        .encode(
            x=alt.X("date", timeUnit="monthdate", title="date"),
            y=alt.Y("cases_avg7", title="7-day avg"),
            color=navy,
        )
        .properties(title=f"{state_name}: New Cases",)
        .configure_title(fontSize=14, font="Roboto", anchor="middle", color="Black")
        .configure_axis(gridOpacity=0.4,)
    )

    # Make deaths chart
    deaths_chart = (
        alt.Chart(df)
        .mark_line()
        .encode(
            x=alt.X("date", timeUnit="monthdate", title="date"),
            y=alt.Y("deaths_avg3", title="3-day avg"),
            color=maroon,
        )
        .properties(title=f"{state_name}: Deaths",)
        .configure_title(fontSize=14, font="Roboto", anchor="middle", color="Black")
        .configure_axis(gridOpacity=0.4,)
    )

    display(cases_chart)
    display(deaths_chart)

    return df


# City of LA case data
def case_indicators_lacity(start_date):
    city_df = pd.read_csv(LA_CITY_URL)

    city_df["date"] = pd.to_datetime(city_df.Date)

    df = (
        city_df[city_df.date >= start_date]
        .rename(
            columns={"City of LA Cases": "cases", "City of LA New Cases": "new_cases"}
        )
        .sort_values("date")
        .reset_index(drop=True)
    )

    # Derive new columns
    df = df.assign(
        # 7-day rolling average for new cases
        cases_avg7=df.new_cases.rolling(window=7).mean(),
    )

    # Make cases charts
    cases_chart = (
        alt.Chart(df)
        .mark_line()
        .encode(
            x=alt.X("date:T", timeUnit="monthdate", title="date"),
            y=alt.Y("cases_avg7", title="7-day avg"),
            color=navy,
        )
        .properties(title="City of LA: New Cases",)
        .configure_title(fontSize=14, font="Roboto", anchor="middle", color="Black")
        .configure_axis(gridOpacity=0.4,)
    )

    display(cases_chart)

    return df


def case_indicators_msa(msa_name, start_date):
    msa_name = "Los Angeles"
    group_cols = ["msa", "msa_pop", "date"]
    msa_group_cols = ["msa", "msa_pop"]

    # Merge county to MSA using crosswalk
    county_df = pd.read_csv(US_COUNTY_URL, dtype={"fips": "str"})
    county_df["date"] = pd.to_datetime(county_df.date)

    pop = pd.read_csv(CROSSWALK_URL, dtype={"county_fips": "str", "cbsacode": "str"},)

    pop = (pop[(pop.cbsatitle==msa_name) | 
               (pop.cbsatitle.str.contains(msa_name)) | 
               (pop.cbsacode==msa_name)]
           [["cbsacode", "cbsatitle", "msa_pop", "county_fips"]]
           .assign(msa = pop.cbsatitle)
          )

    cbsa_name = pop.cbsatitle.iloc[0]

    final_df = pd.merge(
        county_df,
        pop,
        left_on="fips",
        right_on="county_fips",
        how="inner",
        validate="m:1",
    )

    df = (
        final_df[final_df.date >= start_date]
        .groupby(group_cols)
        .agg({"cases": "sum", "deaths": "sum"})
        .reset_index()
    )
    
    # Create new cases and new deaths columns
    df = df.assign(
        new_cases=(
            df.sort_values(group_cols)
                .groupby(msa_group_cols)["cases"]
                .diff(periods=1)
            ),
        new_deaths=(
            df.sort_values(group_cols)
                .groupby(msa_group_cols)["deaths"]
                .diff(periods=1)
            ),
    )

    # Derive new columns
    df = df.assign(
        # 7-day rolling average for new cases
        cases_avg7=df.new_cases.rolling(window=7).mean(),
        # 3-day rolling average for new deaths
        deaths_avg3=df.new_deaths.rolling(window=3).mean(),
    )

    # Make cases charts
    cases_chart = (
        alt.Chart(df)
        .mark_line()
        .encode(
            x=alt.X("date", timeUnit="monthdate", title="date"),
            y=alt.Y("cases_avg7", title="7-day avg"),
            color=navy,
        )
        .properties(title=f"{cbsa_name}: New Cases",)
        .configure_title(fontSize=14, font="Roboto", anchor="middle", color="Black")
        .configure_axis(gridOpacity=0.4,)
    )

    # Make deaths chart
    deaths_chart = (
        alt.Chart(df)
        .mark_line()
        .encode(
            x=alt.X("date", timeUnit="monthdate", title="date"),
            y=alt.Y("deaths_avg3", title="3-day avg"),
            color=maroon,
        )
        .properties(title=f"{cbsa_name}: New Deaths",)
        .configure_title(fontSize=14, font="Roboto", anchor="middle", color="Black")
        .configure_axis(gridOpacity=0.4,)
    )

    display(cases_chart)
    display(deaths_chart)
    
    return df


# Make daily testing chart for City of LA
def daily_test_lacity(start_date):
    df = pd.read_csv(TESTING_URL)
    df = df.assign(
            Date = pd.to_datetime(df.Date).dt.strftime("%-m/%d/%y")
        )
    df = df[df.Date >= start_date]

    # Make daily testing bar chart
    bar = (alt.Chart(df)
           .mark_bar(color=navy)
           .encode(
               x=alt.X("Date", timeUnit="monthdate", title="date", 
                       axis=alt.Axis(format="%m/%d")
                      ),
               y=alt.Y('Performed:Q', title="Daily Tests")
           )
    )

    line1 = (alt.Chart(pd.DataFrame({'y':[10_000]}))
             .mark_rule(color=maroon, strokeDash=[5,2])
             .encode(y='y')
    )
    line2 = (alt.Chart(pd.DataFrame({'y':[16_667]}))
             .mark_rule(color=maroon, strokeDash=[5,2])
             .encode(y='y')
    )

    testing_chart = ((bar + line1 + line2)
                     .properties(title="City of LA Testing",width=600)
                     .configure_title(fontSize=14, font="Roboto", anchor="middle", color="Black")
                     .configure_axis(gridOpacity=0.4,)
    )

    display(testing_chart)
    
    return df