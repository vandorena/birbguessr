require "test_helper"

class BirbTest < ActiveSupport::TestCase
  test "recent puts the newest birb first" do
    assert_equal [ birbs(:cardinal), birbs(:goose) ], Birb.recent.to_a
  end

  test "guessed_by? reports whether a given player has committed" do
    assert birbs(:cardinal).guessed_by?(users(:member))
    assert_not birbs(:goose).guessed_by?(users(:member))
  end

  test "a caption is required, because it is also the alt text" do
    birb = build_birb(caption: "")

    assert_not birb.valid?
    assert_includes birb.errors[:caption], "can't be blank"
  end

  test "a photo is required" do
    birb = Birb.new(caption: "No photo", user: users(:admin))

    assert_not birb.valid?
    assert_includes birb.errors[:photo], "is required"
  end

  test "a non-image attachment is refused" do
    birb = Birb.new(caption: "Not a bird", user: users(:admin))
    birb.photo.attach(io: StringIO.new("#!/bin/sh\n"), filename: "birb.sh",
                      content_type: "application/x-sh")

    assert_not birb.valid?
    assert_includes birb.errors[:photo], "must be a JPEG, PNG or WebP"
  end

  test "an oversized photo is refused" do
    birb = build_birb

    # Setting the recorded size rather than generating 16MB of test data. The
    # rule under test is the comparison, not Active Storage's byte counting.
    birb.photo.blob.byte_size = Birb::MAX_SIZE + 1

    assert_not birb.valid?
    assert_includes birb.errors[:photo], "must be smaller than 15MB"
  end

  test "destroying a birb takes its guesses with it" do
    assert_difference "Guess.count", -2 do
      birbs(:cardinal).destroy
    end
  end

  private
    def build_birb(caption: "A birb", user: users(:admin))
      Birb.new(caption: caption, user: user).tap do |birb|
        birb.photo.attach(io: file_fixture("birb.png").open,
                          filename: "birb.png", content_type: "image/png")
      end
    end
end
