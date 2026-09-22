namespace :campus do
  desc "Refetch Brown's buildings from OpenStreetMap into app/assets/campus"
  task buildings: :environment do
    path = Campus::Buildings::PATH
    puts "asking Overpass for #{Campus::Buildings::SOURCE}..."

    collection = CampusOverpass.fetch
    path.write(JSON.generate(collection))

    named = collection["features"].count { |feature| feature.dig("properties", "name").present? }
    puts "wrote #{collection['features'].size} buildings (#{named} named), #{path.size} bytes to #{path.relative_path_from(Rails.root)}"
    puts "restart the server: Campus::Buildings memoizes this for the life of the process."
  rescue CampusOverpass::Failure => e
    # Leaving the existing file alone is the point. Overpass rate-limits at two
    # concurrent queries per IP, so a failure here is usually "try again in a
    # minute", not "the campus has changed".
    abort "Failed, and #{path.basename} is untouched: #{e.message}"
  end
end
