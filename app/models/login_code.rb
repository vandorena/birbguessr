# A single sign-in attempt, redeemable two ways:
#
#   * the magic link  -- one click, carries a high-entropy token in the URL
#   * the six-digit code -- typed into the verify form, in the same browser
#
# Both live on one row so that redeeming either burns the other. The row only
# ever holds digests; the plaintext exists for the length of one request, inside
# the email that gets sent.
class LoginCode < ApplicationRecord
  EXPIRATION = 15.minutes

  # How many times the six-digit code may be guessed before the row is burned.
  # Six digits is only ~20 bits, so the code's safety comes from this counter
  # plus the controller rate limit -- not from the code itself.
  #
  # Keep this comfortably below LoginsController's per-IP limit on :complete,
  # or the IP limit would always fire first and this counter would never do
  # anything.
  MAX_ATTEMPTS = 5

  belongs_to :user

  # bcrypt, giving us `code=`, `code_digest` and `authenticate_code`. The code
  # and the browser token are low-entropy enough to deserve a slow hash.
  has_secure_password :code, validations: false
  has_secure_password :browser_token, validations: false

  scope :active, -> { where(used_at: nil, created_at: EXPIRATION.ago..) }

  def self.digest_link_token(token)
    Digest::SHA256.hexdigest(token.to_s)
  end

  def self.generate_for(user, ip_address: nil, user_agent: nil)
    code = format("%06d", SecureRandom.random_number(1_000_000))
    browser_token = SecureRandom.base58(24)
    link_token = SecureRandom.base58(32)

    record = create!(
      user:,
      code:,
      browser_token:,
      link_token_digest: digest_link_token(link_token),
      ip_address:,
      user_agent:
    )

    # The plaintext exists only in this return value -- the row holds digests.
    [ record, code, link_token, browser_token ]
  end

  # Looks up an unredeemed row by its magic-link token.
  #
  # No browser binding here, and that is the whole point of a magic link: mail
  # is routinely opened on a different device from the one that asked. The
  # token's ~190 bits of entropy is what makes that safe.
  def self.find_by_link_token(token)
    return nil if token.blank?

    active.find_by(link_token_digest: digest_link_token(token))
  end

  # "123456" -> "123-456", purely so it is readable in the email.
  def self.format_for_display(code)
    code.to_s.scan(/.../).join("-")
  end

  def active?
    used_at.nil? && created_at > EXPIRATION.ago
  end

  def use!
    update!(used_at: Time.current)
  end

  # Verifies the typed code *and* that it is being typed in the browser that
  # asked for it, so a code read out of someone's inbox elsewhere is useless on
  # its own. (The magic link is the sanctioned way to sign in from elsewhere.)
  def verify(code:, browser_token:)
    return false unless active?
    return false if attempts >= MAX_ATTEMPTS

    increment!(:attempts)

    return false unless browser_token.present? && authenticate_browser_token(browser_token)
    return false unless authenticate_code(code.to_s.delete("-"))

    use!
    true
  end
end
