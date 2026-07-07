# Evidence photo for a field inspection. Created with `upload_state: "pending"`
# and a presigned S3 PUT URL; confirmed by the client after the upload completes
# (PATCH .../confirm sets upload_state to "uploaded").
#
# ready_for_review? in Inspection checks uploaded? photos only — pending photos
# don't count toward the evidence gate.
class InspectionPhoto < ApplicationRecord
  belongs_to :organization
  belongs_to :inspection

  validates :s3_key, presence: true, uniqueness: true
  validates :upload_state, inclusion: { in: %w[pending uploaded] }

  scope :uploaded, -> { where(upload_state: "uploaded") }

  def uploaded? = upload_state == "uploaded"
  def pending?  = upload_state == "pending"

  def confirm!
    update!(upload_state: "uploaded")
  end
end
