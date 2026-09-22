require "test_helper"

class GuessesControllerTest < ActionDispatch::IntegrationTest
  test "signed-out visitors cannot guess" do
    assert_no_difference "Guess.count" do
      post birb_guess_path(birbs(:goose)), params: { guess: on_campus }
    end
    assert_redirected_to new_login_path
  end

  test "a player guesses once and is sent to the reveal" do
    sign_in_as users(:member)

    assert_difference "Guess.count", 1 do
      post birb_guess_path(birbs(:goose)), params: { guess: on_campus }
    end

    assert_redirected_to birbs(:goose)
    assert_equal users(:member), Guess.order(:created_at).last.user
  end

  test "the guess belongs to the signed-in player, whatever the params claim" do
    sign_in_as users(:member)

    post birb_guess_path(birbs(:goose)),
         params: { guess: on_campus.merge(user_id: users(:admin).id) }

    assert_equal users(:member), birbs(:goose).guesses.sole.user
  end

  test "guessing is what opens the reveal" do
    sign_in_as users(:other_member)

    get birb_path(birbs(:cardinal))
    assert_not_includes response.body, "827111"

    post birb_guess_path(birbs(:cardinal)), params: { guess: on_campus }
    follow_redirect!

    assert_includes response.body, "827111"
  end

  test "a second guess on the same birb changes nothing and does not blow up" do
    sign_in_as users(:member)

    assert_no_difference "Guess.count" do
      post birb_guess_path(birbs(:cardinal)), params: { guess: on_campus }
    end

    assert_redirected_to birbs(:cardinal)
  end

  test "a pin off campus is refused" do
    sign_in_as users(:member)

    assert_no_difference "Guess.count" do
      post birb_guess_path(birbs(:goose)),
           params: { guess: { latitude: -77.846401, longitude: 166.676105 } }
    end

    assert_redirected_to birbs(:goose)
    assert_match "on campus", flash[:alert]
  end

  private
    def on_campus
      { latitude: Campus::CENTRE.first, longitude: Campus::CENTRE.last }
    end
end
