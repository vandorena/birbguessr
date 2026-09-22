class LoginMailer < ApplicationMailer
  def sign_in(user, plaintext_code, link_token)
    @user = user
    @code = LoginCode.format_for_display(plaintext_code)
    @url = login_link_url(token: link_token)
    @expires_in = LoginCode::EXPIRATION.inspect

    mail to: user.email_address, subject: "#{@code} is your birbguessr sign-in code"
  end
end
