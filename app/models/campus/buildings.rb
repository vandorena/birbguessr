# Every building on Brown's campus, traced in OpenStreetMap, drawn underneath
# the guessing map so the campus reads as a campus rather than as a beige
# rectangle with roads on it.
#
# Where this comes from: the sibling `are-you-in` app asks the Overpass API for
# the buildings inside a school's campus polygon. The scoping there is the
# interesting part and is worth restating, because it is not obvious --
# `amenity=university` sits on the campus *site polygon*, while the buildings
# inside it carry `building=*` and nothing naming the university. So the
# buildings cannot be selected by tag; they are selected geographically, by
# turning the site polygon into an Overpass `area` and asking what is inside it.
# SOURCE below is the polygon that defines "Brown" for that query, and it is the
# same reference are-you-in stores on its Brown row.
#
# Unlike are-you-in, this app has exactly one campus that will never change, so
# the answer is a checked-in file rather than a jsonb column, a warming job and
# a state machine. `bin/rails campus:buildings` regenerates it.
#
# The browser fetches the geometry itself, as a digested asset it can cache
# forever; nothing here is inlined into the page. What this class is for is the
# text version -- a canvas full of shapes is nothing at all to a screen reader.
module Campus
  module Buildings
    # way ids and relation ids are separate sequences, so the type matters as
    # much as the number: way/13816239 is somewhere else entirely.
    SOURCE = "relation/13816239"

    # Flat, because Propshaft's logical paths are relative to each load path
    # root and `app/assets/campus` is one of them -- so this file is
    # `brown-buildings.json` to `asset_path`, not `campus/brown-buildings.json`.
    ASSET = "brown-buildings.json"
    PATH = Rails.root.join("app/assets/campus", ASSET)

    # Plenty of campus buildings are traced but unnamed, so `names` is shorter
    # than `count` -- 181 of 279 today. The page prints both rather than
    # implying the list is the whole campus.
    Summary = Data.define(:count, :names)

    # Memoized for the life of the process: this is a build artifact, and the
    # only thing that changes it is the rake task, which you follow with a
    # restart anyway. Parsing 165 KB on every page view to print a list of names
    # would be the alternative.
    def self.summary
      @summary ||= begin
        features = JSON.parse(PATH.read).fetch("features")

        Summary.new(
          count: features.size,
          names: features.filter_map { |feature| feature.dig("properties", "name").presence }.uniq.sort
        )
      end
    end
  end
end
