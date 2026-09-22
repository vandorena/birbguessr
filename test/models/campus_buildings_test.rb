require "test_helper"

class CampusBuildingsTest < ActiveSupport::TestCase
  test "the checked-in geometry is valid GeoJSON with buildings in it" do
    collection = JSON.parse(Campus::Buildings::PATH.read)

    assert_equal "FeatureCollection", collection["type"]
    assert_operator collection["features"].size, :>, 100
  end

  test "every feature is a drawable polygon" do
    features = JSON.parse(Campus::Buildings::PATH.read).fetch("features")

    features.each do |feature|
      assert_includes [ "Polygon", "MultiPolygon" ], feature.dig("geometry", "type")
    end
  end

  test "the buildings are on Brown's campus, not in the ocean" do
    # Catches the classic GeoJSON mistake, which is emitting [lat, lon] instead
    # of [lon, lat] -- that would put every building off the coast of Africa.
    features = JSON.parse(Campus::Buildings::PATH.read).fetch("features")
    points = features.flat_map { |feature| feature["geometry"]["coordinates"].flatten.each_slice(2).to_a }

    longitudes = points.map(&:first)
    latitudes = points.map(&:last)

    assert_operator longitudes.max, :<, -71.0
    assert_operator longitudes.min, :>, -72.0
    assert_operator latitudes.min, :>, 41.0
    assert_operator latitudes.max, :<, 42.0
  end

  test "the checked-in file carries the precision CampusOverpass writes" do
    # Keeps the file and its generator honest: if they disagree, the next
    # `bin/rails campus:buildings` produces a diff that is all noise.
    decimals = JSON.parse(Campus::Buildings::PATH.read)
      .fetch("features")
      .flat_map { |feature| feature["geometry"]["coordinates"].flatten }
      .map { |coordinate| coordinate.to_s.split(".").last.length }

    assert_operator decimals.max, :<=, 6
  end

  test "summary counts every building but only names the named ones" do
    summary = Campus::Buildings.summary

    assert_operator summary.count, :>, summary.names.size
    assert_includes summary.names, "John Hay Library"
  end

  test "summary names are unique and sorted" do
    names = Campus::Buildings.summary.names

    assert_equal names.uniq, names
    assert_equal names.sort, names
  end

  test "the source is a relation, since a node has no area to search inside" do
    assert_match %r{\Arelation/\d+\z}, Campus::Buildings::SOURCE
  end
end
