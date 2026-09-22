class LoginsController < ApplicationController
  BROWSER_TOKEN_COOKIE = :login_browser_token

  allow_unauthenticated_access

  # Every limit below is named. Rails keys a limit on [scope, name, by], and the
  # scope defaults to the controller path -- so two IP-keyed limits in this one
  # controller would otherwise share a bucket and spend each other's budget.

  # Six digits is ~20 bits, so throttling is load-bearing, not decoration.
  #
  # Keyed by the *mailbox*, not the address as typed: without canonicalising,
  # you+1@ and you+2@ are separate buckets that land in the same inbox, and the
  # limit is five emails per alias rather than five per person.
  rate_limit to: 5, within: 15.minutes, only: :create, name: "login-email",
             by: -> { User.canonical_address(params.dig(:login, :email_address)).presence || request.remote_ip },
             with: -> { redirect_to new_login_path, alert: "Too many sign-in attempts. Try again in a few minutes." }

  # The per-address limit above caps what one mailbox receives; it does nothing
  # about one machine requesting codes for a thousand different addresses, which
  # is the mail-bomb and the enumeration sweep. This is that cap.
  #
  # An hour rather than fifteen minutes, because the cost being limited is
  # outbound mail and a sender reputation, both of which are hourly problems.
  # Thirty is chosen against a shared campus NAT, where a whole dorm signing in
  # after a launch arrives from one address -- turn it up if real traffic trips
  # it, since the failure here is a locked-out building, not a leak.
  rate_limit to: 30, within: 1.hour, only: :create, name: "login-ip",
             by: -> { request.remote_ip },
             with: -> { redirect_to new_login_path, alert: "Too many sign-in attempts from this network. Try again later." }

  # Deliberately above LoginCode::MAX_ATTEMPTS so the per-row counter is what
  # burns a single guessed code; this is the backstop for one IP working through
  # many codes, and is loose enough to survive a shared NAT.
  rate_limit to: 20, within: 15.minutes, only: %i[ complete show ], name: "code-attempts",
             by: -> { request.remote_ip },
             with: -> { redirect_to new_login_path, alert: "Too many sign-in attempts. Try again in a few minutes." }

  before_action :redirect_if_signed_in
  before_action :set_pending_login_code, only: %i[ verify complete ]

  # Step 1 -- ask for an email address.
  def new
  end

  # Step 2 -- send the email. The response is identical whether or not the
  # address already has an account, so this cannot be used to enumerate users.
  def create
    email = params.dig(:login, :email_address).to_s.strip.downcase

    # Saying so plainly reveals nothing about who has an account: both of these
    # are decidable from the address alone.
    if email.blank? || !email.match?(URI::MailTo::EMAIL_REGEXP)
      return redirect_to new_login_path, alert: "Please enter a valid email address."
    end

    unless User.brown_address?(email)
      return redirect_to new_login_path, alert: "Please use your Brown email address, like you@brown.edu."
    end

    deliver_login_email(email)

    session[:login_requested] = true
    redirect_to verify_login_path
  end

  # Step 3 -- the form for typing the code in.
  def verify
    redirect_to new_login_path unless session[:login_requested]
  end

  # Step 4a -- check the typed code and sign in.
  def complete
    # No pending row at all: expired, already spent, or a different browser.
    # Send them back to the start, since the verify form cannot help them.
    if @login_code.nil?
      clear_pending_login
      return redirect_to new_login_path, alert: "That code has expired. Request a new one."
    end

    unless @login_code.verify(code: params[:code], browser_token: cookies.signed[BROWSER_TOKEN_COOKIE])
      return redirect_to verify_login_path, alert: "That code is not valid. Check it and try again."
    end

    sign_in_with(@login_code)
  end

  # Step 4b -- the magic link. Same outcome as :complete, reached in one click
  # and without the browser-token check, since mail is often opened elsewhere.
  def show
    login_code = LoginCode.find_by_link_token(params[:token])

    if login_code.nil?
      clear_pending_login
      return redirect_to new_login_path, alert: "That sign-in link has expired or has already been used."
    end

    login_code.use!
    sign_in_with(login_code)
  end

  private
    def sign_in_with(login_code)
      clear_pending_login
      start_new_session_for(login_code.user)

      redirect_to after_authentication_url, notice: "Signed in as #{login_code.user.email_address}."
    end

    def deliver_login_email(email)
      user = User.find_or_initialize_by(email_address: email)

      # A brand new address signs up here -- that *is* the sign-up flow. If the
      # record will not save (a validation we did not pre-check), stay silent:
      # the response must not differ from the success case.
      return unless user.persisted? || user.save

      login_code, code, link_token, browser_token = LoginCode.generate_for(
        user,
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )

      session[:pending_login_code_id] = login_code.id
      cookies.signed[BROWSER_TOKEN_COOKIE] = {
        value: browser_token,
        expires: LoginCode::EXPIRATION.from_now,
        httponly: true,
        same_site: :lax,
        secure: Rails.env.production?
      }

      # deliver_now, NOT deliver_later. `deliver_later` passes the plaintext code
      # and link token as ActiveJob arguments, which ActiveJob logs and Solid
      # Queue persists to solid_queue_jobs.arguments -- putting the credential in
      # cleartext in both the log and the database, which is exactly what
      # digesting these columns exists to prevent.
      #
      # The cost is that this request blocks on SMTP. That is the right trade,
      # and it surfaces delivery failures immediately rather than burying them
      # in a retrying job.
      LoginMailer.sign_in(user, code, link_token).deliver_now
    end

    def set_pending_login_code
      id = session[:pending_login_code_id]
      @login_code = LoginCode.active.find_by(id: id) if id
    end

    def clear_pending_login
      session.delete(:pending_login_code_id)
      session.delete(:login_requested)
      cookies.delete(BROWSER_TOKEN_COOKIE)
    end

    def redirect_if_signed_in
      redirect_to root_path, notice: "You are already signed in." if authenticated?
    end
end
