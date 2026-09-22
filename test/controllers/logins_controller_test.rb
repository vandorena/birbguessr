require "test_helper"

class LoginsControllerTest < ActionDispatch::IntegrationTest
  setup { ActionMailer::Base.deliveries.clear }

  # Pulls the plaintext code and link token back out of the delivered email,
  # which is the only place they exist -- the row holds digests.
  def sent_credentials
    mail = ActionMailer::Base.deliveries.last
    # Multipart, so `body` on the container is empty -- read the text part.
    body = mail.text_part.body.to_s
    code = body[/\d{3}-\d{3}/].to_s.delete("-")
    token = body[%r{/login/([A-Za-z0-9]+)}, 1]

    [ code, token ]
  end

  def request_code(email)
    post login_path, params: { login: { email_address: email } }
  end

  test "requesting a code creates the account and sends one email" do
    assert_difference -> { User.count }, 1 do
      assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
        request_code("newbie@brown.edu")
      end
    end

    assert_redirected_to verify_login_path
    assert_equal "newbie@brown.edu", User.last.email_address
  end

  test "requesting a code for an existing account does not create a second one" do
    assert_no_difference -> { User.count } do
      request_code(users(:member).email_address)
    end
  end

  test "a non-Brown address is refused and sends nothing" do
    assert_no_difference [ -> { User.count }, -> { ActionMailer::Base.deliveries.size } ] do
      request_code("someone@gmail.com")
    end

    assert_redirected_to new_login_path
    assert_match(/Brown email address/, flash[:alert])
  end

  test "a malformed address is refused" do
    request_code("not-an-email")

    assert_redirected_to new_login_path
    assert_empty ActionMailer::Base.deliveries
  end

  test "the emailed code signs you in" do
    request_code(users(:member).email_address)
    code, _token = sent_credentials

    post complete_login_path, params: { code: code }

    assert_redirected_to root_url
    follow_redirect!
    assert_match users(:member).email_address, response.body
  end

  test "the magic link signs you in" do
    request_code(users(:member).email_address)
    _code, token = sent_credentials

    get login_link_path(token: token)

    assert_redirected_to root_url
    follow_redirect!
    assert_match users(:member).email_address, response.body
  end

  test "the magic link works from a browser that never asked" do
    request_code(users(:member).email_address)
    _code, token = sent_credentials
    reset!  # new session and cookie jar, as if the email were opened on a phone

    get login_link_path(token: token)

    assert_redirected_to root_url
  end

  test "the typed code does NOT work from a different browser" do
    request_code(users(:member).email_address)
    code, _token = sent_credentials
    reset!

    post complete_login_path, params: { code: code }

    # No pending row in this session at all, so it reads as expired.
    assert_redirected_to new_login_path
  end

  test "a wrong code does not sign you in" do
    request_code(users(:member).email_address)
    code, _token = sent_credentials
    wrong = format("%06d", (code.to_i + 1) % 1_000_000)

    post complete_login_path, params: { code: wrong }

    assert_redirected_to verify_login_path
    assert_match(/not valid/, flash[:alert])
  end

  test "a magic link cannot be replayed" do
    request_code(users(:member).email_address)
    _code, token = sent_credentials

    get login_link_path(token: token)
    delete logout_path
    get login_link_path(token: token)

    assert_redirected_to new_login_path
    assert_match(/expired or has already been used/, flash[:alert])
  end

  test "redeeming the link also burns the typed code" do
    request_code(users(:member).email_address)
    code, token = sent_credentials

    get login_link_path(token: token)
    delete logout_path
    post complete_login_path, params: { code: code }

    assert_redirected_to new_login_path
  end

  test "an unknown magic link token is refused" do
    get login_link_path(token: "nonsense")

    assert_redirected_to new_login_path
  end

  test "the verify page is not reachable without asking first" do
    get verify_login_path

    assert_redirected_to new_login_path
  end

  test "signed-in visitors are bounced away from the login pages" do
    sign_in_as users(:member)

    get new_login_path

    assert_redirected_to root_path
  end

  test "signing out ends the session" do
    sign_in_as users(:member)

    delete logout_path
    get root_path

    # The landing page renders either way -- what tells you the session is gone
    # is that it has stopped saying who you are.
    assert_response :success
    assert_no_match "Signed in", response.body
  end

  test "protected pages redirect to login" do
    get flipper_path

    # AdminConstraint makes the route invisible rather than redirecting.
    assert_response :not_found
  end

  # Throttling
  #
  # These pass only because the test environment uses a real cache store;
  # rate_limit counts through the cache, and against :null_store none of them
  # would ever trip.

  test "one mailbox gets five emails per quarter hour, aliases included" do
    5.times { |i| post login_path, params: { login: { email_address: "flood+#{i}@brown.edu" } } }
    assert_equal 5, ActionMailer::Base.deliveries.size

    # The sixth is the same mailbox under a sixth alias, and it is refused.
    post login_path, params: { login: { email_address: "flood+again@brown.edu" } }

    assert_redirected_to new_login_path
    assert_equal 5, ActionMailer::Base.deliveries.size
  end

  test "one network gets thirty emails an hour across every address" do
    30.times { |i| post login_path, params: { login: { email_address: "person#{i}@brown.edu" } } }
    assert_equal 30, ActionMailer::Base.deliveries.size

    # A thirty-first address from the same IP: under its own per-mailbox limit,
    # over the network's.
    post login_path, params: { login: { email_address: "person30@brown.edu" } }

    assert_redirected_to new_login_path
    assert_equal 30, ActionMailer::Base.deliveries.size
    assert_match "from this network", flash[:alert]
  end

  # Two IP-keyed limits in one controller share a bucket unless each is given a
  # name -- Rails keys a limit on [scope, name, by], and the scope is the
  # controller path for both. Unnamed, the 21 sends below would push the
  # code-attempt counter past its own limit of 20 and lock a visitor out of
  # typing their code, having never typed one.
  test "sending codes does not spend the code-attempt budget" do
    21.times { |i| post login_path, params: { login: { email_address: "sender#{i}@brown.edu" } } }

    post complete_login_path, params: { code: "000000" }

    # Refused for being the wrong code, which is the honest answer -- not for
    # having attempted too many, which is what a shared bucket would have said.
    assert_match "not valid", flash[:alert]
    assert_no_match(/Too many/, flash[:alert])
  end
end
