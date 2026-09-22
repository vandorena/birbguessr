ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    # Minitest's parallel runner forks, and this machine cannot fork a process
    # that has opened a libpq connection -- the child segfaults inside
    # PG.connect. It is the same bug HANDOFF.md records for Solid Queue's
    # supervisor, and it stayed invisible here only because the suite sat under
    # the 50-test threshold that turns parallelism on. Linux (CI, Docker) is
    # unaffected, so this is scoped to macOS rather than switched off.
    parallelize(workers: RUBY_PLATFORM.include?("darwin") ? 1 : :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
