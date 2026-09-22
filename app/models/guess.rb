class Guess < ApplicationRecord
  belongs_to :birb
  belongs_to :user

  validates :latitude, :longitude, presence: true
  validates :user_id, uniqueness: { scope: :birb_id,
                                    message: "has already guessed on this birb" }
  validate :must_be_on_campus

  # Guesses are immutable on purpose: there is no edit or update route, because
  # seeing the crowd is what a guess buys and revising afterwards would undo
  # that. The unique index in the migration is what actually enforces it.

  # BigDecimal#as_json returns a *String*, so handing latitude and longitude
  # straight to to_json emits ["41.827111", "-71.402999"] and Leaflet quietly
  # mishandles it. Every coordinate crosses into JSON through here.
  def to_pin
    [ latitude.to_f, longitude.to_f ]
  end

  private
    # The map pans freely and fences nothing, so this is not a backstop -- it is
    # the only thing keeping a pin out of Antarctica.
    def must_be_on_campus
      return if latitude.blank? || longitude.blank?
      return if Campus.contains?(latitude, longitude)

      errors.add(:base, "must be somewhere on campus")
    end
end
