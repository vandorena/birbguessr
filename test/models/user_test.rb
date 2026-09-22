require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "accepts brown.edu and its subdomains" do
    assert User.brown_address?("someone@brown.edu")
    assert User.brown_address?("someone@alumni.brown.edu")
    assert User.brown_address?("someone@cs.brown.edu")
    assert User.brown_address?("  Someone@Brown.EDU  ")
  end

  test "rejects lookalike and non-Brown hosts" do
    refute User.brown_address?("someone@notbrown.edu")
    refute User.brown_address?("someone@brown.edu.attacker.com")
    refute User.brown_address?("someone@brown.com")
    refute User.brown_address?("someone@harvard.edu")
    refute User.brown_address?("someone@gmail.com")
  end

  test "rejects addresses with more than one @" do
    refute User.brown_address?("someone@brown.edu@evil.com")
  end

  test "rejects a blank local part" do
    refute User.brown_address?("@brown.edu")
    refute User.brown_address?("brown.edu")
  end

  test "validation refuses a non-Brown address" do
    user = User.new(email_address: "someone@gmail.com")

    refute user.valid?
    assert_includes user.errors[:email_address], "must be a Brown address, like you@brown.edu"
  end

  test "normalizes the address before saving" do
    user = User.create!(email_address: "  MixedCase@Brown.edu ")

    assert_equal "mixedcase@brown.edu", user.email_address
  end

  test "addresses are unique regardless of casing" do
    User.create!(email_address: "dupe@brown.edu")

    assert_raises(ActiveRecord::RecordInvalid) { User.create!(email_address: "DUPE@brown.edu") }
  end

  # Aliases

  test "a plus-alias is the same account as the address it delivers to" do
    user = User.create!(email_address: "someone@brown.edu")

    assert_equal user, User.find_by(email_address: "someone+birbs@brown.edu")

    # And a second sign-up through the alias is the same row, not a new one.
    assert_no_difference "User.count" do
      User.find_or_create_by(email_address: "someone+other@brown.edu")
    end
  end

  test "the tag is dropped on the way in" do
    user = User.create!(email_address: "Someone+Tag@Brown.edu ")

    assert_equal "someone@brown.edu", user.email_address
  end

  test "one address is allowed to keep its aliases apart" do
    exempt = User::ALIASES_ALLOWED_FOR.sole
    local = exempt.split("@").first

    kept = User.create!(email_address: "#{local}+alt@brown.edu")

    assert_equal "#{local}+alt@brown.edu", kept.email_address
    assert_not_equal kept, User.create!(email_address: exempt)
  end

  # Folding either of these would merge two real mailboxes into one account.
  test "dots and subdomains are left alone" do
    assert_equal "j.smith@brown.edu", User.canonical_address("j.smith@brown.edu")
    assert_equal "you@alumni.brown.edu", User.canonical_address("you@alumni.brown.edu")
  end
end
