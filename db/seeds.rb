# Idempotent development seeds: `bin/rails db:seed`.
#
# Kept runnable and idempotent because `bin/ci` runs `db:seed:replant`, so a
# seed that only works against an empty database fails there and nowhere else.
#
# There are no passwords -- sign-in is an emailed link or code. Use these
# addresses at /login; in development the email is written to tmp/mails.

# A guess somewhere plausible on campus: clustered around the Green rather than
# spread evenly over the bounding box, because people guess at buildings and an
# even scatter puts a quarter of the pins in the river.
#
# Box-Muller, so the cloud has a centre and a tail. Clamped rather than
# resampled: Campus.contains? is what a real guess is held to, and a pin exactly
# on the fence still passes it.
def scattered_guess(random)
  south, west = Campus::BOUNDS.first
  north, east = Campus::BOUNDS.last

  # A third of the box, so the tail reaches the edges without piling up there.
  spread = ->(low, high) { (high - low) / 6.0 }

  latitude = Campus::CENTRE.first + gaussian(random) * spread.call(south, north)
  longitude = Campus::CENTRE.last + gaussian(random) * spread.call(west, east)

  [ latitude.clamp(south, north).round(6), longitude.clamp(west, east).round(6) ]
end

def gaussian(random)
  Math.sqrt(-2 * Math.log(random.rand)) * Math.cos(2 * Math::PI * random.rand)
end

if Rails.env.local?
  admin = User.find_or_initialize_by(email_address: "admin@brown.edu")
  admin.update!(admin: true)

  member = User.find_or_initialize_by(email_address: "plain@brown.edu")
  member.update!(admin: false)

  puts "Seeded the two accounts you sign in as: admin@brown.edu, plain@brown.edu"

  # Two birbs, so the gallery has something in it and its newest-first ordering
  # is visible. The images are generated placeholders, not photographs -- they
  # exist so the map has something to hang off, and the captions say so. Replace
  # them with real photos through /birbs/new.
  #
  # Ordered oldest first: `recent` sorts by created_at descending, so the last
  # one created is the one that leads the gallery.
  [
    [ "birb-goose.png",    "Placeholder: a goose outside the Ratty" ],
    [ "birb-cardinal.png", "Placeholder: a cardinal on the Green" ]
  ].each do |filename, caption|
    birb = Birb.find_or_initialize_by(caption: caption)
    birb.user = admin

    # Only attach when there is nothing attached. Re-running the seeds would
    # otherwise orphan a blob per birb per run.
    unless birb.photo.attached?
      birb.photo.attach(io: Rails.root.join("db/seeds", filename).open,
                        filename: filename, content_type: "image/png")
    end

    birb.save!
  end

  puts "Seeded #{Birb.count} birbs (placeholder images)"

  # A crowd, so a revealed birb shows what the feature is actually for: a cloud
  # of pins with yours somewhere in it. One pin proves nothing about whether the
  # map reads well at a hundred.
  #
  # A hundred guesses needs a hundred users, because Guess is unique per user
  # per birb -- that constraint is the reason this is not simply a loop over
  # `admin`.
  CROWD = 100

  crowd = (1..CROWD).map do |number|
    User.find_or_create_by!(email_address: format("crowd-%03d@brown.edu", number))
  end

  # Neither admin@brown.edu nor plain@brown.edu guesses. Reveal hides the crowd
  # until you have committed a guess of your own, and leaving both accounts
  # unguessed is what lets you sign in, place one, and watch the other hundred
  # appear -- which is the thing worth looking at.
  Birb.order(:id).each_with_index do |birb, index|
    # Seeded per birb rather than left to chance, so `db:seed:replant` produces
    # the same map twice. Two birbs with the same scatter would look like a bug.
    random = Random.new(index)

    guesses = crowd.filter_map do |user|
      next if birb.guesses.exists?(user: user)

      latitude, longitude = scattered_guess(random)
      { birb_id: birb.id, user_id: user.id, latitude:, longitude:,
        created_at: Time.current, updated_at: Time.current }
    end

    # One INSERT rather than a hundred. These skip validations, so the
    # coordinates are checked above instead -- see scattered_guess.
    Guess.insert_all!(guesses) if guesses.any?
  end

  puts "Seeded #{Guess.count} guesses across #{Birb.count} birbs, from #{crowd.size} crowd users"
end
