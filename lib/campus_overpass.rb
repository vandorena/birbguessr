require "net/http"

# Regenerates app/assets/campus/brown-buildings.json from OpenStreetMap.
#
# Ported from the sibling `are-you-in` app's CampusMap, minus everything this
# game does not need: no outline, because Campus::BOUNDS already fences the map,
# and no framing maths, because Campus::BOUNDS already frames it. What is left
# is the Overpass query and the OSM-to-GeoJSON conversion.
#
# This never runs in a request. It is a build step -- `bin/rails campus:buildings`
# -- and the app reads its output. Overpass allows two concurrent queries per IP
# and answers 429 to the third, which is the reason the geometry is a file in
# the repo rather than something fetched on demand.
#
# Plain functions, like MailDelivery, so the conversion is unit testable without
# a network -- see test/lib/campus_overpass_test.rb.
module CampusOverpass
  ENDPOINT = "https://overpass-api.de/api/interpreter"

  OPEN_TIMEOUT = 3
  READ_TIMEOUT = 25
  # Overpass's own server-side budget, kept under READ_TIMEOUT on purpose so a
  # slow-but-working query gets to finish rather than being cut off a moment
  # early.
  QUERY_TIMEOUT = 20

  USER_AGENT = "Birbguessr/1.0 (+https://github.com/vandorena/birbguessr)"

  Failure = Class.new(StandardError)

  module_function

  # Reads in four steps:
  #
  #   1. select the campus relation
  #   2. turn it into an area -- the step the whole thing rests on
  #   3. ask for every building inside that area
  #   4. emit them with geometry
  #
  # Step 2 is why the reference has to be a way or a relation. A node is a
  # point, has no area to map to, and would yield nothing.
  def query(reference = Campus::Buildings::SOURCE)
    type, id = reference.split("/")

    <<~OVERPASS
      [out:json][timeout:#{QUERY_TIMEOUT}];
      #{type}(#{id});
      map_to_area->.campus;
      (
        way["building"](area.campus);
        relation["building"](area.campus);
      );
      out geom;
    OVERPASS
  end

  def fetch(reference = Campus::Buildings::SOURCE)
    uri = URI(ENDPOINT)

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                               open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
      request = Net::HTTP::Post.new(uri, "User-Agent" => USER_AGENT, "Accept" => "application/json")
      request.set_form_data(data: query(reference))

      http.request(request)
    end

    raise Failure, "Overpass answered #{response.code}" unless response.is_a?(Net::HTTPOK)

    collection(JSON.parse(response.body))
  end

  # Overpass reports a failed query IN BAND once it has started streaming, so a
  # query that outruns its budget comes back as HTTP 200 with a `remark` and
  # fewer buildings than there are. Writing that to the file would silently
  # replace 279 buildings with some smaller number that looks plausible.
  def collection(body)
    raise Failure, "Overpass: #{body['remark']}" if body["remark"].present?

    features = Array(body["elements"]).filter_map { |element| feature(element) }
    raise Failure, "no buildings came back" if features.empty?

    { "type" => "FeatureCollection", "features" => features }
  end

  def feature(element)
    geometry = geometry_for(element)
    return nil if geometry.nil?

    {
      "type" => "Feature",
      "geometry" => geometry,
      # Named buildings get a tooltip and a line in the page's fallback list;
      # the rest are drawn but not annotated.
      "properties" => { "name" => element.dig("tags", "name"), "osm" => "#{element['type']}/#{element['id']}" }
    }
  end

  def geometry_for(element)
    case element["type"]
    when "way"      then way_geometry(element["geometry"])
    when "relation" then relation_geometry(element["members"])
    end
  end

  def way_geometry(geometry)
    points = ring(geometry)
    return nil unless closed?(points)

    # An open way is a wall or a fence fragment. Drawing it as a filled shape
    # would invent a building that is not there -- and unlike are-you-in, which
    # draws those as lines, this map has no use for a fence.
    { "type" => "Polygon", "coordinates" => [ points ] }
  end

  # KNOWN SIMPLIFICATION, inherited from are-you-in. A multipolygon whose
  # outline is split across several ways needs those stitched end to end before
  # it is a ring, and that is not done here: only members that are already
  # closed become polygons. That covers courtyard buildings, which is what the
  # `inner` role is nearly always for on a campus, and loses the rare building
  # traced as a chain of separate ways.
  def relation_geometry(members)
    outer, inner = Array(members)
      .select { |member| member["type"] == "way" }
      .map { |member| [ member["role"], ring(member["geometry"]) ] }
      .select { |_role, points| closed?(points) }
      .partition { |role, _points| role != "inner" }

    return nil if outer.empty?

    polygons = outer.map { |_role, points| [ points ] }
    polygons.first.concat(inner.map { |_role, points| points })

    { "type" => "MultiPolygon", "coordinates" => polygons }
  end

  # OSM gives [{lat:, lon:}]; GeoJSON wants [lon, lat]. Getting that pair the
  # wrong way round puts the whole campus in the ocean, which is at least a bug
  # that announces itself.
  #
  # Six decimal places is ~0.1 m -- finer than the tracing, the same precision
  # the game stores a guess in, and a third off the file size.
  def ring(geometry)
    Array(geometry).filter_map do |point|
      [ point["lon"].round(6), point["lat"].round(6) ] if point["lon"] && point["lat"]
    end
  end

  def closed?(points) = points.size >= 4 && points.first == points.last
end
