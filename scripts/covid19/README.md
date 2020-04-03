# COVID-19 City of Los Angeles Resources Map

This assembles a series of resources for the City of Los Angeles COVID-19
emergency response into a single KML file, which can then be uploaded to
a custom Google Map and deployed to city residents.

## Requirements

The scripts here must be run on a POSIX system with working Python and OGR/GDAL
installations. The Python environment must have the `lxml` package installed
for XML parsing.

## Instructions

Run the `city-resources.sh` script.
```bash
./city-resources.sh
```
This will create a `city-resources-styled.kml` KML file,
with styling information targeting Google Maps icons.

You can then import this KML file into Google MyMaps.

## Sources

This script assembles the following data sources:

1. LAUSD Grab & Go Food Centers
1. Handwashing Stations
1. Emergency Shelters
1. Senior Nutrition Dining Sites

## Styling

The script jumps through some extra hoops to add Google-Maps-aware styling
for icons. We created a `style.kml` file by manually adding styles to icons
in Google MyMaps, downloading the resulting KML file, then extracting the
`Style` and `StyleMap` elements from that document. These styling elements
are spliced into the `city-resources.kml` file using the Python script
`splice_styles.py` to produce the final `city-resources-styled.kml` file.

Individual features in the map are associated with `Style`s via the `OGR_STYLE`
attributes, which are attached to the relevant features in the bash script.
Updating icons/colors will mean recreating the `style.kml` file, inspecting
it for style names, and updating the `OGR_STYLE` fields in `city-resources.sh`.
