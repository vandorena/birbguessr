source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3", ">= 8.1.3.1"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
# force_ruby_platform: the precompiled pg-*-arm64-darwin gem segfaults in PG.connect
# when called from a forked child process, which is exactly what Solid Queue's supervisor
# does. Building from source against the local libpq avoids it.
gem "pg", "~> 1.1", force_ruby_platform: true
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Use Dart Sass to compile app/assets/stylesheets [https://github.com/rails/dartsass-rails]
gem "dartsass-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Pin json to 2.x: Ruby 4.0 ships json 3.x as a default gem, but Rails 8.1's
# ActiveSupport::JSON.decode still calls JSON.parse(json, options) with a positional
# options hash, which json 3 rejects. That breaks Solid Queue job deserialization.
gem "json", "~> 3.0"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

# S3-backed Active Storage in production; local disk isn't persisted across
# container redeploys [https://guides.rubyonrails.org/active_storage_overview.html#amazon-s3-service]
gem "aws-sdk-s3", require: false

# Minimal authorization through OO design and pure Ruby classes [https://github.com/varvet/pundit]
gem "pundit"

# Feature flags [https://www.flippercloud.io/docs]
gem "flipper"
gem "flipper-active_record"
gem "flipper-ui"

# Business intelligence / SQL dashboards [https://github.com/ankane/blazer]
gem "blazer"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Load environment variables from .env [https://github.com/bkeepers/dotenv]
  gem "dotenv-rails"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
end
