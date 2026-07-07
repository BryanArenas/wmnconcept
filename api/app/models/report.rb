# The generated PDF + its delivery ledger (spec §3, §9). One row per inspection.
# Created by GenerateReportPdfJob once the PDF is persisted; DeliverReportJob
# then fills delivered_at/delivered_to and advances the inspection to `delivered`.
#
# The presence of this row (with an s3_key) is THE artifact that authorizes the
# `delivered` transition (spec §6 invariant: never delivered without a PDF).
class Report < ApplicationRecord
  belongs_to :organization
  belongs_to :inspection

  validates :s3_key, presence: true, uniqueness: true
  validates :generated_at, presence: true
  validates :inspection_id, uniqueness: true

  def delivered? = delivered_at.present?

  # Records one recipient's outcome in the ledger, replacing any prior entry for
  # the same email so re-delivery of a failed recipient updates in place.
  def record_delivery(email:, role:, status:, at: Time.current)
    entry = { "email" => email, "role" => role.to_s, "status" => status.to_s,
              "delivered_at" => at.iso8601 }
    others = (delivered_to || []).reject { |d| d["email"] == email }
    self.delivered_to = others + [entry]
  end

  def failed_recipients
    (delivered_to || []).select { |d| d["status"] != "delivered" }
  end
end
