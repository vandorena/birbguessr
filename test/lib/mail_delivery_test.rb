require "test_helper"
require Rails.root.join("lib/mail_delivery")

class MailDeliveryTest < ActiveSupport::TestCase
  test "returns nil when nothing is configured" do
    assert_nil MailDelivery.smtp_settings(env: {}, credentials: {})
  end

  test "a region alone is not enough to start sending" do
    # Otherwise every development machine would try to reach SES with no
    # credentials, instead of writing to tmp/mails.
    assert_nil MailDelivery.smtp_settings(env: { "SES_REGION" => "eu-west-1" }, credentials: {})
  end

  test "derives the SES host from the region once credentials exist" do
    settings = MailDelivery.smtp_settings(
      env: { "SES_REGION" => "eu-west-1", "SMTP_USERNAME" => "AKIAEXAMPLE", "SMTP_PASSWORD" => "secret" },
      credentials: {}
    )

    assert_equal "email-smtp.eu-west-1.amazonaws.com", settings[:address]
    assert_equal 587, settings[:port]
    assert_equal true, settings[:enable_starttls_auto]
    assert_equal "AKIAEXAMPLE", settings[:user_name]
    assert_equal :plain, settings[:authentication]
  end

  test "falls back to the default region" do
    settings = MailDelivery.smtp_settings(env: { "SMTP_USERNAME" => "u", "SMTP_PASSWORD" => "p" }, credentials: {})

    assert_equal "email-smtp.#{MailDelivery::DEFAULT_REGION}.amazonaws.com", settings[:address]
  end

  test "credentials work with no environment variables at all" do
    settings = MailDelivery.smtp_settings(
      env: {},
      credentials: { region: "us-west-2", user_name: "AKIA", password: "secret" }
    )

    assert_equal "email-smtp.us-west-2.amazonaws.com", settings[:address]
    assert_equal "AKIA", settings[:user_name]
  end

  test "SMTP_ADDRESS overrides SES, for a local catcher" do
    settings = MailDelivery.smtp_settings(
      env: { "SMTP_ADDRESS" => "localhost", "SMTP_PORT" => "1025", "SMTP_TLS" => "false" },
      credentials: {}
    )

    assert_equal "localhost", settings[:address]
    assert_equal 1025, settings[:port]
    assert_equal false, settings[:enable_starttls_auto]
  end

  test "omits authentication when there is no username" do
    # Setting `authentication:` unconditionally makes the mail gem raise
    # "SMTP-AUTH requested but missing user name" against auth-less catchers.
    settings = MailDelivery.smtp_settings(env: { "SMTP_ADDRESS" => "localhost" }, credentials: {})

    refute settings.key?(:authentication)
    refute settings.key?(:user_name)
  end

  test "from prefers env, then credentials, then the default" do
    assert_equal "a@b.com", MailDelivery.from(env: { "MAIL_FROM" => "a@b.com" }, credentials: { from: "c@d.com" })
    assert_equal "c@d.com", MailDelivery.from(env: {}, credentials: { from: "c@d.com" })
    assert_equal MailDelivery::DEFAULT_FROM, MailDelivery.from(env: {}, credentials: {})
  end

  test "the interceptor rewrites every recipient to one address" do
    interceptor = MailDelivery.interceptor_for("catch@brown.edu")
    message = Mail.new(to: "real@brown.edu", cc: "cc@brown.edu", subject: "Hi")

    interceptor.delivering_email(message)

    assert_equal [ "catch@brown.edu" ], message.to
    assert_nil message.cc
    assert_includes message.subject, "real@brown.edu"
  end
end

# Regression guard for the whole initializer, not just MailDelivery. dotenv loads
# .env in the test environment as well, so once real SES credentials existed the
# initializer flipped this to :smtp and the suite began attempting live sends.
class MailDeliveryEnvironmentTest < ActiveSupport::TestCase
  test "the test environment never sends mail for real" do
    assert_equal :test, ActionMailer::Base.delivery_method,
                 "config/initializers/mail_delivery.rb must not override test.rb's :test delivery"
  end
end
