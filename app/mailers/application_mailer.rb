class ApplicationMailer < ActionMailer::Base
  # No `default from:` here on purpose -- a mailer-level default silently
  # overrides `config.action_mailer.default_options`, which is where the sender
  # is configured (config/initializers/mail_delivery.rb).
  layout "mailer"
end
