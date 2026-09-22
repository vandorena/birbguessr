require "test_helper"

class CampusOverpassTest < ActiveSupport::TestCase
  # No network anywhere in here: every test feeds `collection` a body of the
  # shape Overpass returns.

  test "the query scopes buildings to the campus area rather than by tag" do
    query = CampusOverpass.query("relation/13816239")

    assert_match "relation(13816239)", query
    assert_match "map_to_area->.campus", query
    assert_match "(area.campus)", query
  end

  test "a closed way becomes a polygon, in lon/lat order" do
    collection = CampusOverpass.collection(
      "elements" => [ way(id: 1, name: "Sayles Hall", points: square) ]
    )

    feature = collection["features"].sole

    assert_equal "Polygon", feature.dig("geometry", "type")
    assert_equal [ -71.4, 41.8 ], feature.dig("geometry", "coordinates", 0, 0)
    assert_equal "Sayles Hall", feature.dig("properties", "name")
    assert_equal "way/1", feature.dig("properties", "osm")
  end

  test "an unclosed way is dropped rather than drawn as a building" do
    # A fence or a wall fragment. Filling it would invent a building.
    open_way = way(id: 2, name: "A wall", points: square.first(3))

    error = assert_raises(CampusOverpass::Failure) do
      CampusOverpass.collection("elements" => [ open_way ])
    end

    assert_match "no buildings", error.message
  end

  test "a relation with an inner ring becomes a multipolygon with a hole" do
    collection = CampusOverpass.collection(
      "elements" => [ {
        "type" => "relation", "id" => 3, "tags" => { "name" => "Quad" },
        "members" => [
          { "type" => "way", "role" => "outer", "geometry" => square },
          { "type" => "way", "role" => "inner", "geometry" => square(offset: 0.0002) }
        ]
      } ]
    )

    polygons = collection["features"].sole.dig("geometry", "coordinates")

    assert_equal "MultiPolygon", collection["features"].sole.dig("geometry", "type")
    assert_equal 1, polygons.size
    assert_equal 2, polygons.first.size, "the inner ring should be a hole in the outer one"
  end

  test "an in-band remark is a failure, not a smaller campus" do
    # Overpass answers 200 with a `remark` when a query outruns its budget after
    # it has started streaming. Trusting it would silently shrink the campus.
    error = assert_raises(CampusOverpass::Failure) do
      CampusOverpass.collection(
        "remark" => "runtime error: Query timed out",
        "elements" => [ way(id: 4, name: "The only one that made it", points: square) ]
      )
    end

    assert_match "timed out", error.message
  end

  test "unnamed buildings are kept, since they are still buildings" do
    collection = CampusOverpass.collection("elements" => [ way(id: 5, name: nil, points: square) ])

    assert_nil collection["features"].sole.dig("properties", "name")
  end

  test "coordinates are rounded to the precision a guess is stored at" do
    precise = [ { "lat" => 41.81234567, "lon" => -71.40123456 } ] * 3
    precise << precise.first

    collection = CampusOverpass.collection("elements" => [ way(id: 6, name: "Rounded", points: precise) ])

    assert_equal [ -71.401235, 41.812346 ], collection["features"].sole.dig("geometry", "coordinates", 0, 0)
  end

  private
    def square(offset: 0)
      points = [ [ 41.8, -71.4 ], [ 41.8, -71.399 ], [ 41.801, -71.399 ], [ 41.801, -71.4 ] ]
      ring = points.map { |lat, lon| { "lat" => lat + offset, "lon" => lon + offset } }

      ring + [ ring.first ]
    end

    def way(id:, name:, points:)
      { "type" => "way", "id" => id, "tags" => { "name" => name }.compact, "geometry" => points }
    end
end
