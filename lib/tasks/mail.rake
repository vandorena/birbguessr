namespace :mail do
  desc "Show how mail is currently configured (delivery method, SES host, sender)"
  task config: :environment do
    puts "delivery_method: #{ActionMailer::Base.delivery_method}"

    case ActionMailer::Base.delivery_method
    when :smtp
      settings = ActionMailer::Base.smtp_settings
      puts "host:            #{settings[:address]}:#{settings[:port]}"
      puts "starttls:        #{settings[:enable_starttls_auto]}"
      puts "username:        #{settings[:user_name]}"
      puts "password:        #{settings[:password].present? ? "(set, #{settings[:password].length} chars)" : "(MISSING)"}"
    when :file
      puts "location:        #{ActionMailer::Base.file_settings[:location]}"
      puts "(no SMTP credentials configured, so nothing is sent over the network)"
    end

    puts "from:            #{ApplicationMailer.default[:from]}"
    puts "intercept_to:    #{ENV['MAIL_INTERCEPT_TO'].presence || '(none)'}"
  end

  desc "Send a real sign-in email to ADDRESS, to test delivery end to end"
  task :test, [ :address ] => :environment do |_task, args|
    address = args[:address].presence || ENV["ADDRESS"].presence
    abort "Usage: bin/rails 'mail:test[you@brown.edu]'" if address.blank?

    Rake::Task["mail:config"].invoke
    puts "\nsending to:      #{address}"

    user = User.find_or_initialize_by(email_address: address)
    user.save! if user.new_record?

    # Real credentials, so this exercises the same path the login flow uses.
    _record, code, link_token = LoginCode.generate_for(user)
    LoginMailer.sign_in(user, code, link_token).deliver_now

    puts "\nSent. code=#{LoginCode.format_for_display(code)}"
    puts "link=#{Rails.application.routes.url_helpers.login_link_url(token: link_token, host: ActionMailer::Base.default_url_options[:host], port: ActionMailer::Base.default_url_options[:port])}"
  rescue StandardError => e
    abort "\nDelivery FAILED: #{e.class}: #{e.message}"
  end
end
