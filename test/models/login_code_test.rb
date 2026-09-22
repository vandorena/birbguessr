require "test_helper"

class LoginCodeTest < ActiveSupport::TestCase
  setup do
    @user = users(:member)
    @record, @code, @link_token, @browser_token = LoginCode.generate_for(@user)
  end

  test "stores only digests, never the plaintext" do
    assert_no_match @code, @record.code_digest
    assert_no_match @link_token, @record.link_token_digest
    assert_no_match @browser_token, @record.browser_token_digest
  end

  test "verifies a correct code in the browser that asked for it" do
    assert @record.verify(code: @code, browser_token: @browser_token)
    refute @record.active?, "code should be burned after use"
  end

  test "accepts the display format with a dash" do
    assert @record.verify(code: LoginCode.format_for_display(@code), browser_token: @browser_token)
  end

  test "rejects a correct code from a different browser" do
    refute @record.verify(code: @code, browser_token: "wrong-token")
    assert @record.active?, "a wrong browser token must not burn the code"
  end

  test "rejects a wrong code" do
    wrong = format("%06d", (@code.to_i + 1) % 1_000_000)

    refute @record.verify(code: wrong, browser_token: @browser_token)
  end

  test "burns the code after MAX_ATTEMPTS wrong guesses" do
    wrong = format("%06d", (@code.to_i + 1) % 1_000_000)
    LoginCode::MAX_ATTEMPTS.times { @record.verify(code: wrong, browser_token: @browser_token) }

    refute @record.verify(code: @code, browser_token: @browser_token),
           "the correct code must not work once the attempt budget is spent"
  end

  test "a used code cannot be reused" do
    @record.verify(code: @code, browser_token: @browser_token)

    refute @record.verify(code: @code, browser_token: @browser_token)
  end

  test "an expired code does not verify" do
    @record.update!(created_at: (LoginCode::EXPIRATION + 1.minute).ago)

    refute @record.verify(code: @code, browser_token: @browser_token)
  end

  test "finds an active row by link token, with no browser binding" do
    assert_equal @record, LoginCode.find_by_link_token(@link_token)
  end

  test "does not find a used, expired, blank or wrong link token" do
    assert_nil LoginCode.find_by_link_token("nonsense")
    assert_nil LoginCode.find_by_link_token(nil)
    assert_nil LoginCode.find_by_link_token("")

    @record.use!
    assert_nil LoginCode.find_by_link_token(@link_token)

    @record.update!(used_at: nil, created_at: (LoginCode::EXPIRATION + 1.minute).ago)
    assert_nil LoginCode.find_by_link_token(@link_token)
  end

  test "MAX_ATTEMPTS stays below the controller's per-IP limit" do
    # The per-row counter must be the thing that burns a guessed code. If the IP
    # limit were lower it would always fire first and this counter would be dead.
    assert LoginCode::MAX_ATTEMPTS < 20
  end
end
