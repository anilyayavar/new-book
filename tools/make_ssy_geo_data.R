# Creates simulated map data for the imaginary state of the Sarvajan Swasthya Yojana
# (SSY), used in the chapter on maps. Coordinates are in kilometres on a flat local
# grid, not latitude and longitude. All shapes and locations are made up.
# Needs Data/ssy_hospitals.csv and Data/ssy_claims.csv.
#   Rscript tools/make_ssy_geo_data.R
# Writes Data/ssy_map.gpkg (layers "state" and "districts"),
# Data/ssy_hospital_locations.csv, Data/ssy_patient_homes.csv, Data/ssy_inspections.csv

suppressPackageStartupMessages({library(tidyverse); library(sf)})
set.seed(808)

# A flat grid measured in kilometres. The state is imaginary, so the grid is
# not tied to any real place that matters.
km_crs <- st_crs("+proj=tmerc +lat_0=0 +lon_0=0 +k=1 +x_0=0 +y_0=0 +ellps=WGS84 +units=km")

hospitals <- read_csv("Data/ssy_hospitals.csv", show_col_types = FALSE)
claims    <- read_csv("Data/ssy_claims.csv", show_col_types = FALSE)
camp_ids  <- c("H116", "H071", "H070", "H098", "H063", "H066")

# ---- State outline: an irregular blob about 300 km by 240 km --------------------
angles <- seq(0, 2 * pi, length.out = 61)[-61]
radius <- 120 + 25 * sin(3 * angles) + 15 * cos(5 * angles) + rnorm(60, 0, 4)
outline <- cbind(150 + 1.25 * radius * cos(angles), 120 + radius * sin(angles))
outline <- rbind(outline, outline[1, ])
state <- st_sf(state = "Sarvajan Pradesh", geometry = st_sfc(st_polygon(list(outline)), crs = km_crs))

# ---- Districts: Voronoi cells around eight seed points, clipped to the state ---
seeds <- tibble(
  district = c("Amarpur", "Belapur", "Chandpur", "Devgarh",
               "Fatehpur", "Gopalganj", "Haripur", "Kishanpur"),
  x = c(60, 120, 190, 245, 70, 140, 210, 150),
  y = c(170, 200, 195, 140, 80, 120, 60, 40)
)
seed_pts <- st_as_sf(seeds, coords = c("x", "y"), crs = km_crs)
cells <- st_voronoi(st_union(seed_pts), envelope = st_geometry(state)) |>
  st_collection_extract("POLYGON")
districts <- st_sf(geometry = st_intersection(cells, st_geometry(state)))
districts$district <- seeds$district[st_nearest_feature(st_centroid(districts), seed_pts)]
districts <- districts |>
  mutate(population_lakh = round(c(18, 22, 15, 26, 20, 31, 17, 24)[match(district, seeds$district)] *
                                   runif(n(), 0.95, 1.05), 1)) |>
  select(district, population_lakh, geometry)

# ---- Random point inside a polygon ----------------------------------------------
point_in <- function(poly, n = 1) st_coordinates(st_sample(poly, n, exact = TRUE))

# ---- Hospital locations, inside their own district ------------------------------
hosp_loc <- hospitals |>
  rowwise() |>
  mutate(xy = list(point_in(districts$geometry[districts$district == district]))) |>
  ungroup() |>
  mutate(x_km = round(map_dbl(xy, 1), 2), y_km = round(map_dbl(xy, 2), 2)) |>
  select(hospital_id, x_km, y_km)

# ---- Patient home locations for a sample of claims ------------------------------
# Most patients live near their hospital. Patients of camp hospitals are often
# brought from far-off districts.
smp <- claims |>
  slice_sample(n = 4000) |>
  left_join(hosp_loc, by = "hospital_id") |>
  mutate(camp = hospital_id %in% camp_ids)

far_far <- function(n) runif(n, 60, 200)
homes <- smp |>
  mutate(dist = if_else(camp & runif(n()) < 0.6, far_far(n()), rexp(n(), 1 / 12)),
         angle = runif(n(), 0, 2 * pi),
         hx = x_km + dist * cos(angle),
         hy = y_km + dist * sin(angle))

# Keep homes inside the state. A home that falls outside is redrawn in another
# direction, at the same distance; if that keeps failing, the distance is halved.
is_inside <- function(x, y) {
  st_within(st_as_sf(tibble(x, y), coords = c("x", "y"), crs = km_crs), state, sparse = FALSE)[, 1]
}
for (attempt in 1:60) {
  out <- which(!is_inside(homes$hx, homes$hy))
  if (length(out) == 0) break
  if (attempt %% 15 == 0) homes$dist[out] <- homes$dist[out] / 2
  homes$angle[out] <- runif(length(out), 0, 2 * pi)
  homes$hx[out] <- homes$x_km[out] + homes$dist[out] * cos(homes$angle[out])
  homes$hy[out] <- homes$y_km[out] + homes$dist[out] * sin(homes$angle[out])
}
out <- which(!is_inside(homes$hx, homes$hy))
homes$hx[out] <- homes$x_km[out]
homes$hy[out] <- homes$y_km[out]
patient_homes <- homes |>
  transmute(claim_id, hospital_id, home_x_km = round(hx, 2), home_y_km = round(hy, 2))

# ---- Inspection photos with geotags ---------------------------------------------
# Every hospital is inspected twice a year. Photos are normally taken at the
# hospital. A few inspections were apparently done without visiting.
desk_inspections <- sample(hosp_loc$hospital_id, 7)
inspections <- hosp_loc |>
  slice(rep(seq_len(n()), each = 2)) |>
  mutate(inspection_no = rep(1:2, length.out = n()),
         inspection_date = as.Date("2024-04-01") + sample(0:360, n(), replace = TRUE),
         off = if_else(hospital_id %in% desk_inspections & inspection_no == 2,
                       runif(n(), 25, 90), abs(rnorm(n(), 0, 0.15))),
         a = runif(n(), 0, 2 * pi),
         photo_x_km = round(x_km + off * cos(a), 3),
         photo_y_km = round(y_km + off * sin(a), 3),
         inspector = sample(c("INS-01", "INS-02", "INS-03", "INS-04", "INS-05"), n(), replace = TRUE)) |>
  select(hospital_id, inspection_no, inspection_date, inspector, photo_x_km, photo_y_km)

# ---- Write -----------------------------------------------------------------------
unlink("Data/ssy_map.gpkg")
st_write(state, "Data/ssy_map.gpkg", layer = "state", quiet = TRUE)
st_write(districts, "Data/ssy_map.gpkg", layer = "districts", quiet = TRUE, append = TRUE)
write_csv(hosp_loc, "Data/ssy_hospital_locations.csv")
write_csv(patient_homes, "Data/ssy_patient_homes.csv")
write_csv(inspections, "Data/ssy_inspections.csv")
cat("districts:", nrow(districts), " hospitals:", nrow(hosp_loc),
    " homes:", nrow(patient_homes), " inspections:", nrow(inspections), "\n")
cat("desk inspections at:", sort(desk_inspections), "\n")
