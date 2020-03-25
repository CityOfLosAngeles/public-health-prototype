from lxml import etree

# Load the style data
style_tree = etree.parse("style.kml")

# Get the XML namespace
ns = next(iter(style_tree.getroot().nsmap.values()))

# Find all the styles associated with the document
styles = style_tree.findall(f".//{{{ns}}}Style") + style_tree.findall(
    f".//{{{ns}}}StyleMap"
)

# Open the resources KML
resources_tree = etree.parse("city-resources.kml")
# Insert the styles
doc = resources_tree.getroot()[0]
for style in styles:
    doc.insert(0, style)

# Write the new styled resources.
resources_tree.write("city-resources-styled.kml")
