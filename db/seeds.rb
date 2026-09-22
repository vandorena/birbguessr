# Idempotent development seeds: `bin/rails db:seed`.
#
# There are no passwords -- sign-in is an emailed link or code. Use these
# addresses at /login; in development the email is written to tmp/mails.
if Rails.env.local?
  admin = User.find_or_initialize_by(email_address: "admin@brown.edu")
  admin.update!(admin: true)

  member = User.find_or_initialize_by(email_address: "plain@brown.edu")
  member.update!(admin: false)

  puts "Seeded #{User.count} users (admin@brown.edu, plain@brown.edu)"
end
