class User < ApplicationRecord
  # Sign-up is restricted to Brown addresses.
  #
  # An anchored allowlist, not a substring match: an unanchored /brown\.edu/
  # would accept `you@brown.edu.attacker.com` and `you@notbrown.edu`. This
  # matches `brown.edu` exactly, plus any subdomain of it (`alumni.brown.edu`,
  # `cs.brown.edu`), and nothing else.
  BROWN_EMAIL_HOST = /\A(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)*brown\.edu\z/

  # Addresses allowed to hold more than one account.
  #
  # Everyone else's plus-aliases collapse onto the address they deliver to, so
  # one mailbox is one player -- see .normalize_address. That matters here more
  # than it would elsewhere: a guess is unique per user per birb, so a second
  # account is a second guess on every birb in the game.
  #
  # In the clear on purpose. It is not a secret, and a constant someone has to
  # read is better than an env var that silently does nothing when it is unset.
  ALIASES_ALLOWED_FOR = [ "alexvd@brown.edu" ].freeze

  has_many :sessions, dependent: :destroy
  has_many :login_codes, dependent: :destroy
  has_many :birbs, dependent: :destroy
  has_many :guesses, dependent: :destroy

  # Downcasing is security-relevant rather than cosmetic: without it
  # "Someone@Brown.edu" slips past the unique index as a second account. So is
  # dropping the +tag, for the same reason one step along: without it
  # "someone+1@brown.edu" is a second account belonging to the same mailbox.
  #
  # Rails applies this to finder arguments as well as to writes, so
  # find_by(email_address: "someone+1@brown.edu") returns the someone@ row.
  normalizes :email_address, with: ->(e) { normalize_address(e) }

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

  # The address as it will be stored: canonical, unless this mailbox is one of
  # the few allowed to keep its aliases apart.
  def self.normalize_address(address)
    address = address.to_s.strip.downcase
    canonical = canonical_address(address)

    ALIASES_ALLOWED_FOR.include?(canonical) ? address : canonical
  end

  # The mailbox an address delivers to: "you+anything@brown.edu" -> "you@brown.edu".
  #
  # Only the +tag is dropped. Dots are *not* folded -- that is a Gmail
  # convention, and at Brown "j.smith@" and "jsmith@" are two different people.
  # Neither is the host touched: brown.edu and alumni.brown.edu are separate
  # mail domains, so collapsing them would merge two real mailboxes into one
  # account. This closes the alias hole it can prove, and no more.
  def self.canonical_address(address)
    address = address.to_s.strip.downcase
    local, at, host = address.rpartition("@")
    return address if at.empty?

    base = local.split("+", 2).first
    # A local part that is nothing but a tag ("+foo@brown.edu"): leave it be and
    # let the format validation give the ordinary answer.
    return address if base.blank?

    "#{base}@#{host}"
  end

  private
    def email_address_must_be_a_brown_address
      return if email_address.blank?
      return if self.class.brown_address?(email_address)

      errors.add(:email_address, "must be a Brown address, like you@brown.edu")
    end
end
