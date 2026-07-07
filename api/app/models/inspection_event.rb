# One row of an inspection's timeline (spec §6 side effects, §8.14 Timeline).
# Append-only: every §6 transition (and the initial spawn) writes one. Actors
# span two tables (users, agency_users) or are absent (system), so we store a
# denormalized class/id/label rather than a polymorphic association.
class InspectionEvent < ApplicationRecord
  belongs_to :organization
  belongs_to :inspection

  validates :kind, presence: true
  validates :message, presence: true
  validates :occurred_at, presence: true

  scope :chronological, -> { order(:occurred_at, :id) }
end
