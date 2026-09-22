# The `flipper-active_record` gem registers itself as Flipper's default adapter when it
# loads, so flags live in `flipper_features` / `flipper_gates` with no wiring needed here.
# Flipper's engine likewise installs Flipper::Middleware::Memoizer on its own
# (config.flipper.memoize and .preload both default to true).
#
# What is left is the dashboard mounted at /flipper — see config/routes.rb, where it sits
# behind AdminConstraint.
require "flipper/ui"

Flipper::UI.configure do |config|
  config.banner_text = "#{Rails.env} environment"
  config.banner_class = Rails.env.production? ? "danger" : "warning"
  config.descriptions_source = ->(_keys) { {} }
  config.show_feature_description_in_list = true
end
