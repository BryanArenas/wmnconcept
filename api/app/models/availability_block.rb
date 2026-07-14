# A window an inspector marks themselves unavailable (PTO, personal, already
# booked elsewhere). Dispatch/scheduling can consult these so an inspector isn't
# assigned into time they've blocked. Owned by the inspector; tenant-scoped.
class AvailabilityBlock < ApplicationRecord
  belongs_to :user
  belongs_to :organization

  validates :starts_at, presence: true
  validates :ends_at, presence: true
  validate :ends_after_starts

  scope :upcoming, -> { where("ends_at >= ?", Time.current) }
  scope :chronological, -> { order(:starts_at, :id) }

  private

  def ends_after_starts
    return if starts_at.blank? || ends_at.blank?

    errors.add(:ends_at, "must be after the start time") if ends_at <= starts_at
  end
end
