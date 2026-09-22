require "test_helper"

class BirbsControllerTest < ActionDispatch::IntegrationTest
  test "signed-out visitors are sent to sign in" do
    get birbs_path
    assert_redirected_to new_login_path

    get birb_path(birbs(:cardinal))
    assert_redirected_to new_login_path
  end

  test "the gallery lists birbs newest first" do
    sign_in_as users(:member)

    get birbs_path

    assert_response :success
    assert_match(/#{birbs(:cardinal).caption}.*#{birbs(:goose).caption}/m, response.body)
  end

  # The rule the whole game rests on. A guess is final, so a player who sees the
  # crowd before committing can simply copy it -- and there is no taking that
  # back. The pins must be absent from the response, not hidden in it.
  test "a player who has not guessed is sent nobody else's pins" do
    sign_in_as users(:other_member)

    get birb_path(birbs(:cardinal))

    assert_response :success
    assert_select "form" # they are offered a guess of their own

    # Asserted against the raw body, not the rendered elements, so a pin that is
    # present but hidden -- in a data attribute, a comment, a <template> -- fails
    # this test. "View source" is the attack, so view source is the assertion.
    assert_not_includes response.body, "827111"
    assert_not_includes response.body, "402999"
    assert_not_includes response.body, "828222"

    # And the channel the map actually reads is empty, stated explicitly.
    assert_select "[data-birb-map-pins-value=?]", "[]"
  end

  test "a player who has guessed is sent every pin" do
    sign_in_as users(:member)

    get birb_path(birbs(:cardinal))

    assert_response :success
    assert_includes response.body, "827111" # their own
    assert_includes response.body, "828222" # somebody else's
    assert_select "form", false # and they cannot guess again
  end

  test "guessing on one birb reveals nothing about another" do
    sign_in_as users(:member)

    get birb_path(birbs(:goose))

    assert_response :success
    assert_not_includes response.body, "827111"
  end

  test "only admins are offered the upload form" do
    sign_in_as users(:member)
    get new_birb_path
    assert_redirected_to root_path

    sign_in_as users(:admin)
    get new_birb_path
    assert_response :success
  end

  test "a non-admin cannot post a birb" do
    sign_in_as users(:member)

    assert_no_difference "Birb.count" do
      post birbs_path, params: { birb: { caption: "Mine now", photo: uploaded_photo } }
    end
  end

  test "an admin posts a birb and it lands at the top of the gallery" do
    sign_in_as users(:admin)

    assert_difference "Birb.count", 1 do
      post birbs_path, params: { birb: { caption: "A newer birb", photo: uploaded_photo } }
    end

    assert_redirected_to Birb.recent.first
    assert Birb.recent.first.photo.attached?
  end

  test "a birb with no photo is refused" do
    sign_in_as users(:admin)

    assert_no_difference "Birb.count" do
      post birbs_path, params: { birb: { caption: "Nothing attached" } }
    end
    assert_response :unprocessable_entity
  end

  test "the map points the browser at the campus buildings, and lists them as text" do
    sign_in_as users(:member)

    get birb_path(birbs(:cardinal))

    # A digested asset URL, fetched by the browser and cached -- not 165 KB of
    # geometry inlined into every birb page.
    assert_select "[data-birb-map-buildings-url-value]" do |elements|
      assert_match %r{\A/assets/brown-buildings-[0-9a-f]+\.json\z}, elements.sole["data-birb-map-buildings-url-value"]
    end

    # The canvas is nothing to a screen reader, so the names exist as text too.
    assert_select "details summary", /#{Campus::Buildings.summary.count} buildings on campus/
    assert_select "details li", "John Hay Library"
  end

  private
    def uploaded_photo
      fixture_file_upload("birb.png", "image/png")
    end
end
