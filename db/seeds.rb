# Idempotent development seeds: `bin/rails db:seed`.
#
# Two accounts, both with the password "password123". The admin one is what gets you
# into /flipper and /blazer.
if Rails.env.local?
  admin = User.find_or_initialize_by(email_address: "admin@birbguessr.test")
  admin.update!(password: "password123", admin: true)

  member = User.find_or_initialize_by(email_address: "plain@birbguessr.test")
  member.update!(password: "password123", admin: false)

  puts "Seeded #{User.count} users (admin@birbguessr.test / plain@birbguessr.test, password123)"
end
