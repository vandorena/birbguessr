require "test_helper"

class RevealTest < ActiveSupport::TestCase
  test "a player who has not guessed is given nothing at all" do
    reveal = Reveal.new(birbs(:cardinal), users(:other_member))

    assert_not reveal.revealed?
    assert_empty reveal.pins
  end

  test "a player who has guessed is given every pin on the birb" do
    reveal = Reveal.new(birbs(:cardinal), users(:member))

    assert reveal.revealed?
    assert_equal 2, reveal.pins.size
  end

  test "pins say which one is yours, and carry no other identity" do
    pins = Reveal.new(birbs(:cardinal), users(:member)).pins

    mine = pins.find { |pin| pin[:mine] }
    assert_equal guesses(:member_on_cardinal).latitude.to_f, mine[:lat]
    assert_equal 1, pins.count { |pin| pin[:mine] }

    # Nothing identifies the other player. Shipping user_id would let anyone
    # follow one person's pins from photo to photo, and users have no name
    # column, so the id is the identity.
    assert_equal %i[lat lng mine], pins.first.keys
  end

  test "coordinates are floats, not BigDecimals" do
    pin = Reveal.new(birbs(:cardinal), users(:member)).pins.first

    assert_kind_of Float, pin[:lat]
    assert_kind_of Float, pin[:lng]
  end

  test "guessing on one birb reveals nothing about another" do
    reveal = Reveal.new(birbs(:goose), users(:member))

    assert_not reveal.revealed?
    assert_empty reveal.pins
  end
end
