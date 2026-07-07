# Agency intake (spec §3, §8.2). A partner names a property, homeowner, and one
# or more inspection types; a coordinator accepts (spawning one inspection per
# type) or declines with a reason (spec §8.7). Its own status is a small stored
# enum — the load-bearing state machine is on Inspection (spec §6).
class InspectionRequest < ApplicationRecord
  INSPECTION_TYPES = InspectionTypeConfig::INSPECTION_TYPES
  STATUSES = %w[submitted accepted declined].freeze

  belongs_to :organization
  belongs_to :agency
  belongs_to :submitted_by_agency_user, class_name: "AgencyUser", optional: true
  belongs_to :property
  belongs_to :homeowner
  has_many :inspections, dependent: :restrict_with_exception

  enum :status, STATUSES.index_with(&:itself), validate: true

  validates :requested_types, presence: true
  validate :requested_types_are_known
  validates :decline_reason, presence: true, if: :declined?

  scope :pending, -> { where(status: "submitted") }

  # Raised when accept/decline is attempted on an already-actioned request. The
  # request status is a small stored enum, not AASM, so it carries its own error.
  class InvalidTransition < StandardError; end

  # Coordinator accepts: spawn one `unassigned` inspection per requested type,
  # snapshotting each type's current price from config (spec §8.7, §11). Refuses
  # to guess a price for a type with no active config — a missing price sheet is
  # a hard stop, never a baked default (CLAUDE.md). Atomic: all-or-nothing.
  def accept!(actor: nil)
    raise InvalidTransition, "cannot accept a #{status} request" unless submitted?

    spawned = nil
    transaction do
      spawned = requested_types.map { |type| spawn_inspection!(type, actor:) }
      update!(status: "accepted")
    end
    spawned
  end

  # Coordinator declines with a required reason (spec §8.7).
  def decline!(reason:, actor: nil)
    raise InvalidTransition, "cannot decline a #{status} request" unless submitted?

    update!(status: "declined", decline_reason: reason)
    self
  end

  private

  def spawn_inspection!(type, actor:)
    config = organization.inspection_type_configs.active.find_by(inspection_type: type)
    # No price sheet for this type ⇒ stop. We never invent a fee (spec §11).
    raise MissingPriceError, type if config.nil?

    inspection = inspections.create!(
      organization:,
      agency:,
      property:,
      homeowner:,
      inspection_type: type,
      price_cents: config.price_cents
    )
    inspection.record_event(
      kind: :created,
      message: "Created from agency request",
      actor:,
      to_status: inspection.status
    )
    inspection
  end

  def requested_types_are_known
    return if requested_types.blank?

    unknown = requested_types - INSPECTION_TYPES
    return if unknown.empty?

    errors.add(:requested_types, "contains unknown types: #{unknown.join(', ')}")
  end

  # Raised when a requested type has no active price config — surfaced as a 422
  # by the accept action so the operator knows the price sheet is incomplete.
  class MissingPriceError < StandardError
    def initialize(type)
      super("No active price config for inspection type '#{type}'")
    end
  end
end
