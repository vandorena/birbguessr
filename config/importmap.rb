# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

# Leaflet, for the campus map. Vendored into vendor/javascript rather than
# pinned at a CDN, so a player's browser only ever loads it from us.
pin "leaflet" # @1.9.4
