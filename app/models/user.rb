class User < ApplicationRecord
  # Sign-up is restricted to Brown addresses.
  #
  # An anchored allowlist, not a substring match: an unanchored /brown\.edu/
  # would accept `you@brown.edu.attacker.com` and `you@notbrown.edu`. This
  # matches `brown.edu` exactly, plus any subdomain of it (`alumni.brown.edu`,
  # `cs.brown.edu`), and nothing else.
  BROWN_EMAIL_HOST = /\A(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)*brown\.edu\z/

  has_many :sessions, dependent: :destroy
  has_many :login_codes, dependent: :destroy

  # Downcasing is security-relevant rather than cosmetic: without it
  # "Someone@Brown.edu" slips past the unique index as a second account.
  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true,
                            format: { with: URI::MailTo::EMAIL_REGEXP }
  validate :email_address_must_be_a_brown_address

  # Splits on the *last* @ and refuses anything with more than one, so
  # "you@brown.edu@evil.com" is not a Brown address.
  def self.brown_address?(address)
    local, _, host = address.to_s.strip.downcase.rpartition("@")
    return false if local.blank? || local.include?("@")

    host.match?(BROWN_EMAIL_HOST)
  end

  private
    def email_address_must_be_a_brown_address
      return if email_address.blank?
      return if self.class.brown_address?(email_address)

      errors.add(:email_address, "must be a Brown address, like you@brown.edu")
    end
end
