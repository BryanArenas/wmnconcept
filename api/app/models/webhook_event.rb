# Stripe idempotency ledger (spec §3, §9). One row per (provider, external_id);
# the unique index guarantees a redelivered webhook is recorded at most once, and
# `processed_at` guards against re-applying side effects if processing is retried.
#
# This is NOT tenant-scoped: webhooks arrive before we know the tenant, and the
# event id is globally unique at the provider. The side-effect handler resolves
# the org from the referenced invoice/payment.
class WebhookEvent < ApplicationRecord
  validates :provider, presence: true
  validates :external_id, presence: true,
                          uniqueness: { scope: :provider }

  scope :unprocessed, -> { where(processed_at: nil) }

  def processed? = processed_at.present?

  def mark_processed!
    update!(processed_at: Time.current)
  end

  # Records an inbound event idempotently. Returns [event, newly_created?]. A
  # duplicate — caught either by the uniqueness validation or by the DB unique
  # index (a concurrent race) — is fetched and returned as not-new, so callers
  # always get the canonical row. A genuine validation failure re-raises.
  def self.record(provider:, external_id:, payload:)
    event = create!(provider:, external_id:, payload:)
    [event, true]
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    existing = find_by(provider:, external_id:)
    raise unless existing

    [existing, false]
  end
end
