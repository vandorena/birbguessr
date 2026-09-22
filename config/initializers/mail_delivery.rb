# Email *is* the login mechanism here, so a silently dropped message is a total
# outage. This picks a delivery method explicitly and fails loudly.
#
# Mail goes out through Amazon SES's SMTP endpoint. Set SES_REGION plus a pair
# of SES SMTP credentials to send for real; with SMTP_USERNAME unset, development
# writes to tmp/mails/<address> and nothing is attempted over the network.
#
# Values come from ENV first, then Rails encrypted credentials
# (`bin/rails credentials:edit`) under an `smtp:` key, so production needs no
# environment variables:
#
#   smtp:
#     region: us-east-1
#     user_name: AKIA...          # SES SMTP username, not an IAM key
#     password: BForwarded...     # SES SMTP password
#     from: "birbguessr <login@yourdomain.com>"
#
# The settings themselves are built in lib/mail_delivery.rb so they can be unit
# tested -- see test/lib/mail_delivery_test.rb.
require Rails.root.join("lib/mail_delivery")

Rails.application.configure do
  credentials = Rails.application.credentials.smtp
  settings = MailDelivery.smtp_settings(credentials: credentials)

  if settings
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = settings
  elsif Rails.env.development?
    # development only, NOT `Rails.env.local?` -- that includes test, and
    # initializers run after config/environments/*, so this would silently
    # override test.rb's `delivery_method = :test` and empty out
    # ActionMailer::Base.deliveries for every mailer test.
    config.action_mailer.delivery_method = :file
    config.action_mailer.file_settings = { location: Rails.root.join("tmp/mails") }
  end

  # Deliberately true even in development. A sign-in email that fails to send
  # must raise, not vanish.
  config.action_mailer.raise_delivery_errors = true

  config.action_mailer.default_options = { from: MailDelivery.from(credentials: credentials) }
end

# Route all mail to one inbox so a non-production environment can never email a
# real user by accident. Useful while SES is still in the sandbox.
if (intercept = ENV["MAIL_INTERCEPT_TO"].presence)
  Rails.application.config.after_initialize do
    ActionMailer::Base.register_interceptor(MailDelivery.interceptor_for(intercept))
  end
end
