class Birb < ApplicationRecord
  CONTENT_TYPES = %w[image/jpeg image/png image/webp].freeze
  MAX_SIZE = 15.megabytes

  belongs_to :user # the admin who posted it
  has_many :guesses, dependent: :destroy
  has_one_attached :photo

  validates :caption, presence: true
  validate :photo_must_be_an_image

  scope :recent, -> { order(created_at: :desc, id: :desc) }

  def guessed_by?(user)
    guesses.exists?(user: user)
  end

  private
    # Active Storage ships no validators, so this is written by hand. It checks
    # the blob's declared content type, which the client supplied -- enough to
    # keep honest mistakes out, not a security boundary. The size cap is the
    # part that matters: without it this is an upload-anything endpoint, admin
    # or not.
    def photo_must_be_an_image
      return errors.add(:photo, "is required") unless photo.attached?

      errors.add(:photo, "must be a JPEG, PNG or WebP") unless photo.blob.content_type.in?(CONTENT_TYPES)
      errors.add(:photo, "must be smaller than #{MAX_SIZE / 1.megabyte}MB") if photo.blob.byte_size > MAX_SIZE
    end
end
