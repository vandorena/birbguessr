# What one player is allowed to see of everyone else's guesses on one birb.
#
# The rule is stated once, here, because it is the only rule in the game: you
# see the crowd only after you have committed a guess of your own. Guessing is
# final, so a leak is unrecoverable -- a player who sees the pins first can
# simply copy them.
#
# The defence is absence, not concealment. When this returns [], no coordinate
# appears anywhere in the response: not in the HTML, not in a data attribute,
# not in a comment. Rendering the pins and hiding them with CSS would not be
# hiding them, and "view source" is all it would take.
#
# There is deliberately no JSON endpoint for birbs or guesses. jbuilder is in
# the Gemfile, and a `respond_to :json` on BirbsController#show that reached for
# `@birb.guesses` would reopen this in a single line.
class Reveal
  def initialize(birb, user)
    @birb = birb
    @user = user
  end

  def pins
    return [] unless revealed?

    # user_id is deliberately not selected. Sending it would let a player
    # correlate one person's pins across every photo, and since users have no
    # name column, the id *is* the identity. Whose pin is whose collapses to a
    # single boolean, decided here rather than in the browser.
    @birb.guesses.pluck(:id, :latitude, :longitude).map do |id, latitude, longitude|
      { lat: latitude.to_f, lng: longitude.to_f, mine: id == own_guess_id }
    end
  end

  def revealed?
    own_guess_id.present?
  end

  private
    def own_guess_id
      # One query, hitting the unique index directly. Memoised against false so
      # a player with no guess does not re-ask on every call.
      return @own_guess_id unless @own_guess_id.nil?

      @own_guess_id = @birb.guesses.where(user: @user).pick(:id) || false
    end
end
