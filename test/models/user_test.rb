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
end
