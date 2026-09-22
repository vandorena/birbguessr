# Builds ActionMailer's SMTP settings for Amazon SES.
#
# This lives here, as plain functions, rather than inline in the initializer so
# it can be unit tested -- see test/lib/mail_delivery_test.rb. Boot-time config
# is exactly the code that is easiest to get subtly wrong and hardest to notice.
#
# SES is reached over its SMTP endpoint, so the only things that must be
# configured are a region and a pair of SES SMTP credentials. Note that SES SMTP
# credentials are NOT an IAM access key pair -- they are generated specifically
# for SMTP in the SES console, and the username looks like an access key ID
# while the password is derived from the secret.
module MailDelivery
  DEFAULT_PORT = 587
  DEFAULT_REGION = "us-east-1"
  DEFAULT_FROM = "birbguessr <login@birbguessr.test>"

  module_function

  def ses_smtp_host(region)
    "email-smtp.#{region}.amazonaws.com"
  end

  def region(env: ENV, credentials: {})
    credentials ||= {}
    env["SES_REGION"].presence || credentials[:region].presence || DEFAULT_REGION
  end

  # Returns nil when nothing is configured, which the caller treats as "write to
  # tmp/mails in development, and fail loudly anywhere else".
  #
  # SES_REGION alone is enough: the host is derived from it. SMTP_ADDRESS is
  # still honoured so a local catcher (Mailpit) or a different provider can be
  # dropped in without touching this file.
  def smtp_settings(env: ENV, credentials: {})
    credentials ||= {}

    address = env["SMTP_ADDRESS"].presence ||
              credentials[:address].presence ||
              (ses_configured?(env:, credentials:) ? ses_smtp_host(region(env:, credentials:)) : nil)
    return nil unless address

    settings = {
      address: address,
      port: (env["SMTP_PORT"].presence || credentials[:port] || DEFAULT_PORT).to_i,

      # SES requires STARTTLS on 587. SMTP_TLS=false exists only for a local
      # catcher with no certificate.
      enable_starttls_auto: env.fetch("SMTP_TLS", "true") != "false"
    }

    user_name = env["SMTP_USERNAME"].presence || credentials[:user_name].presence
    return settings unless user_name

    # Only request SMTP-AUTH when a username exists. Setting `authentication:`
    # unconditionally makes the mail gem raise "SMTP-AUTH requested but missing
    # user name" against servers that accept mail with no credentials.
    settings.merge(
      user_name: user_name,
      password: env["SMTP_PASSWORD"].presence || credentials[:password],
      authentication: (env["SMTP_AUTHENTICATION"].presence || credentials[:authentication] || :plain).to_sym
    )
  end

  # SES is "configured" once there are credentials to send with. The region has
  # a default, so it cannot be the signal on its own -- otherwise every
  # development machine would try to reach SES with no credentials.
  def ses_configured?(env: ENV, credentials: {})
    credentials ||= {}
    (env["SMTP_USERNAME"].presence || credentials[:user_name].presence).present?
  end

  def from(env: ENV, credentials: {})
    credentials ||= {}
    env["MAIL_FROM"].presence || credentials[:from].presence || DEFAULT_FROM
  end

  # Rewrites every recipient to one address so a non-production environment can
  # never email a real person. The original recipients survive in the subject.
  def interceptor_for(address)
    Class.new do
      define_singleton_method(:delivering_email) do |message|
        original = Array(message.to).join(", ")
        message.subject = "[#{Rails.env} → #{original}] #{message.subject}"
        message.to = [ address ]
        message.cc = nil
        message.bcc = nil
      end
    end
  end
end
