# Fetch all NL Domino's locations and write to disk
from topolab import Client

tl = Client(api_key="tlb_prod_...")
df = tl.dataset("nl-domino-poi").to_geodataframe()
df.to_file("dominos-nl.geojson")
