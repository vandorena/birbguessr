# Preview at http://localhost:3000/rails/mailers/login_mailer/sign_in
class LoginMailerPreview < ActionMailer::Preview
  def sign_in
    user = User.first || User.new(email_address: "you@brown.edu")
    LoginMailer.sign_in(user, "123456", SecureRandom.base58(32))
  end
end
