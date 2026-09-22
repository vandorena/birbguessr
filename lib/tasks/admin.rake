namespace :admin do
  desc "List every user and whether they are an admin"
  task list: :environment do
    User.order(admin: :desc, email_address: :asc).each do |user|
      puts "#{user.admin? ? "admin " : "member"}  #{user.email_address}"
    end
  end

  # Granting before the first sign-in is the common case: an account does not
  # exist until someone requests a login code, and the first admin usually has
  # to be in place before that.
  desc "Grant admin to ADDRESS, creating the user if they have not signed in yet"
  task :grant, [ :address ] => :environment do |_task, args|
    address = args[:address].presence || ENV["ADDRESS"].presence
    abort "Usage: bin/rails 'admin:grant[you@brown.edu]'" if address.blank?

    user = User.find_or_initialize_by(email_address: address)
    user.admin = true
    user.save!

    puts "#{user.email_address} is now an admin."
  rescue ActiveRecord::RecordInvalid => e
    abort e.message
  end

  desc "Revoke admin from ADDRESS"
  task :revoke, [ :address ] => :environment do |_task, args|
    address = args[:address].presence || ENV["ADDRESS"].presence
    abort "Usage: bin/rails 'admin:revoke[you@brown.edu]'" if address.blank?

    user = User.find_by(email_address: address)
    abort "No user with address #{address}." if user.nil?

    user.update!(admin: false)
    puts "#{user.email_address} is no longer an admin."
  end
end
