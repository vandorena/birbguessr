require "test_helper"

class GuessTest < ActiveSupport::TestCase
  test "a player may guess once on a birb they have not played" do
    assert_difference "Guess.count", 1 do
      Guess.create!(birb: birbs(:goose), user: users(:member), **on_campus)
    end
  end

  test "a second guess on the same birb is invalid" do
    guess = Guess.new(birb: birbs(:cardinal), user: users(:member), **on_campus)

    assert_no_difference "Guess.count" do
      assert_not guess.save
    end
    assert_includes guess.errors[:user_id], "has already guessed on this birb"
  end

  test "the database refuses a second guess even when validation is skipped" do
    guess = Guess.new(birb: birbs(:cardinal), user: users(:member), **on_campus)

    # The validation above is for the error message. This is the assertion that
    # the unique index exists, which is what actually holds the line when two
    # tabs submit at once.
    assert_raises ActiveRecord::RecordNotUnique do
      guess.save!(validate: false)
    end
  end

  test "both coordinates are required" do
    guess = Guess.new(birb: birbs(:goose), user: users(:member))

    assert_not guess.valid?
    assert_includes guess.errors[:latitude], "can't be blank"
    assert_includes guess.errors[:longitude], "can't be blank"
  end

  test "a pin off campus is refused, whatever the map allowed" do
    guess = Guess.new(birb: birbs(:goose), user: users(:member),
                      latitude: -77.846401, longitude: 166.676105) # McMurdo Station

    assert_not guess.valid?
    assert_includes guess.errors[:base], "must be somewhere on campus"
  end

  test "to_pin returns floats, so coordinates survive the trip into JSON" do
    pin = guesses(:member_on_cardinal).to_pin

    assert_equal [ Float, Float ], pin.map(&:class)
    # BigDecimal would serialise as a string here and Leaflet would not complain.
    assert_equal "[41.827111,-71.402999]", pin.to_json
  end

  private
    def on_campus
      { latitude: Campus::CENTRE.first, longitude: Campus::CENTRE.last }
    end
end
