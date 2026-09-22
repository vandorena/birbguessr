# Where the game is played: Brown's main campus, on College Hill.
#
# The sibling `are-you-in` app finds a campus by storing an OpenStreetMap
# way/relation id on the school and fetching its outline from the Overpass API
# in a background job, caching the result as jsonb. That buys a drawn campus
# boundary. This game only needs to frame a map and fence it, so it is four
# constants instead of a fetcher, a job, a state machine and a cache column.
module Campus
  # Roughly the Van Wickle Gates, which sit at 41.826124, -71.404499.
  CENTRE = [ 41.8268, -71.4025 ].freeze

  # [[south, west], [north, east]] -- the order Leaflet's fitBounds and
  # maxBounds both take. Sized from the campus's published ~146 acres, so this
  # is an approximation: check it by eye and widen it if it clips Pembroke or
  # the Sciences Library.
  BOUNDS = [ [ 41.8215, -71.4085 ], [ 41.8330, -71.3965 ] ].freeze

  DEFAULT_ZOOM = 16

  TILE_URL = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"

  # Required, not decorative: OpenStreetMap data is ODbL-licensed and
  # displaying it obliges us to credit it. Leaflet renders this into the
  # corner of the map.
  TILE_ATTRIBUTION = %(&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors).freeze

  SOUTH_WEST, NORTH_EAST = BOUNDS

  def self.contains?(latitude, longitude)
    return false if latitude.blank? || longitude.blank?

    latitude.between?(SOUTH_WEST.first, NORTH_EAST.first) &&
      longitude.between?(SOUTH_WEST.last, NORTH_EAST.last)
  end
end
