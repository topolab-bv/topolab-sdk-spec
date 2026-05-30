# Read Domino's locations into an sf object
library(topolab)

tl <- tl_client(api_key = "tlb_prod_...")
poi <- tl_dataset(tl, "nl-domino-poi") |> as_sf()
plot(poi["city"])
