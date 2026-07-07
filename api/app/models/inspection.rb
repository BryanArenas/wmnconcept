# The unit of work AND billing (spec §3). Its `status` is the §6 state machine —
# STORED, never derived — implemented with AASM. Each transition is guarded and
# writes a timeline event; the report/invoice transitions fire the §9 jobs.
#
# THE INVARIANT (spec §6/§9): `approve` moves to `approved` and enqueues report
# generation; it does NOT move to `delivered`. Only the report pipeline, once a
# PDF exists, calls `deliver!`. A failed generation therefore holds at `approved`
# forever — an inspection is never `delivered` without a PDF.
#
# `status` is changed ONLY through the transition methods below in application
# code. Direct assignment is left enabled for test setup (factories); production
# paths must go through the events so guards and side effects always run.
class Inspection < ApplicationRecord
  include AASM

  INSPECTION_TYPES = InspectionTypeConfig::INSPECTION_TYPES
  # Everything before delivery — the set `cancel` can reach from (spec §6).
  PRE_DELIVERED = %i[
    unassigned assigned scheduled in_progress submitted_for_review approved
  ].freeze

  belongs_to :organization
  belongs_to :inspection_request
  belongs_to :agency
  belongs_to :property
  belongs_to :homeowner
  belongs_to :assigned_inspector, class_name: "User", optional: true
  belongs_to :office, optional: true

  has_many :inspection_events, dependent: :destroy
  has_many :inspection_photos, dependent: :destroy
  has_one  :inspection_form_response, dependent: :destroy
  has_one  :report, dependent: :destroy
  has_one  :invoice, dependent: :destroy

  enum :inspection_type, INSPECTION_TYPES.index_with(&:itself), validate: true

  validates :price_cents, presence: true,
                          numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Dispatch works these four states (spec §8.8).
  scope :dispatchable, -> { where(status: %w[unassigned assigned scheduled in_progress]) }
  scope :awaiting_review, -> { where(status: "submitted_for_review") }

  aasm column: :status, whiny_transitions: true do
    state :unassigned, initial: true
    state :assigned
    state :scheduled
    state :in_progress
    state :submitted_for_review
    state :approved
    state :delivered
    # Reserved: the §6 contract routes `reject` back to `in_progress` (rework
    # loop), so nothing currently rests here. Declared to keep DB enum ↔ state ↔
    # client mirror at parity and ready if a hard-reject edge is ever added.
    state :rejected
    state :cancelled

    # unassigned → assigned. Caller sets assigned_inspector first.
    event :assign do
      transitions from: :unassigned, to: :assigned, guard: :assigned_inspector_present?
      after { record_transition(:assigned, "Assigned to #{assigned_inspector&.name}") }
    end

    # assigned → scheduled. Caller sets scheduled_at first; enqueues the T-24h
    # reminder (spec §6/§9). Enqueue rides the transition's transaction — Solid
    # Queue is DB-backed, so a rolled-back schedule also un-enqueues the reminder.
    event :schedule do
      transitions from: :assigned, to: :scheduled, guard: :scheduled_at_present?
      after do
        record_transition(:scheduled, "Scheduled for #{scheduled_at&.iso8601}")
        enqueue_reminder
      end
    end

    # scheduled → in_progress (inspector on site).
    event :start do
      before { self.started_at = Time.current }
      transitions from: :scheduled, to: :in_progress
      after { record_transition(:started, "Inspection started") }
    end

    # in_progress → submitted_for_review. Guarded by evidence completeness
    # (≥1 photo + required form fields) — see ready_for_review? (fleshed out in
    # M5). Until then the guard is safely false: nothing reaches review without
    # captured evidence.
    event :submit do
      before { self.submitted_at = Time.current }
      transitions from: :in_progress, to: :submitted_for_review, guard: :ready_for_review?
      after { record_transition(:submitted, "Submitted for review") }
    end

    # submitted_for_review → approved. Enqueues PDF generation; does NOT deliver.
    event :approve do
      before { self.approved_at = Time.current }
      transitions from: :submitted_for_review, to: :approved
      after do
        record_transition(:approved, "Approved — generating report")
        GenerateReportPdfJob.perform_later(self)
      end
    end

    # approved → delivered. Internal — only the report pipeline calls this, and
    # only once a PDF exists. Fires invoicing (spec §9, idempotent on inspection).
    event :deliver do
      before { self.delivered_at = Time.current }
      transitions from: :approved, to: :delivered
      after do
        record_transition(:delivered, "Report delivered")
        CreateInvoiceJob.perform_later(self)
      end
    end

    # submitted_for_review → in_progress (rework loop). Caller sets rejection_note
    # first (spec §6 guard: note present).
    event :reject do
      transitions from: :submitted_for_review, to: :in_progress, guard: :rejection_note_present?
      after { record_transition(:rejected, "Rejected — #{rejection_note}") }
    end

    # any pre-delivered state → cancelled. The pending reminder self-skips once
    # the inspection is cancelled (InspectionReminderJob guard), so there is no
    # job to actively cancel.
    event :cancel do
      before { self.cancelled_at = Time.current }
      transitions from: PRE_DELIVERED, to: :cancelled
      after { record_transition(:cancelled, "Cancelled") }
    end
  end

  # --- Transition sugar (threads the acting principal onto the timeline) -------

  def assign_to!(inspector, actor: nil)
    with_actor(actor) { self.assigned_inspector = inspector; assign! }
  end

  def schedule_for!(time, actor: nil)
    with_actor(actor) { self.scheduled_at = time; schedule! }
  end

  def start_by!(actor: nil)   = with_actor(actor) { start! }
  def submit_by!(actor: nil)  = with_actor(actor) { submit! }
  def approve_by!(actor: nil) = with_actor(actor) { approve! }
  def cancel_by!(actor: nil)  = with_actor(actor) { cancel! }

  def reject_with_note!(note, actor: nil)
    with_actor(actor) { self.rejection_note = note; reject! }
  end

  # Append a timeline row. Public so request intake can log the initial "created"
  # event; AASM callbacks use it via record_transition.
  def record_event(kind:, message:, actor: nil, from_status: nil, to_status: nil)
    inspection_events.create!(
      organization:,
      actor_type: actor&.class&.name,
      actor_id: actor&.id,
      actor_label: actor.try(:name),
      kind: kind.to_s,
      from_status:,
      to_status:,
      message:,
      occurred_at: Time.current
    )
  end

  # --- Guards -----------------------------------------------------------------

  def assigned_inspector_present? = assigned_inspector_id.present?
  def scheduled_at_present?       = scheduled_at.present?
  def rejection_note_present?     = rejection_note.present?

  # Evidence gate for `submit` (spec §6): ≥1 confirmed photo AND all required
  # template fields answered. If no template exists for this type, only photos
  # are required (template is optional at the org level until configured).
  def ready_for_review?
    return false unless inspection_photos.uploaded.exists?

    template = organization.inspection_form_templates
                           .active
                           .find_by(inspection_type:)
    return true if template.nil?

    form_resp = inspection_form_response
    return false if form_resp.nil?

    form_resp.complete?(template)
  end

  private

  # Records a timeline row for the in-flight AASM transition, using the actor set
  # by with_actor and the from/to states AASM exposes on the instance.
  def record_transition(kind, message)
    record_event(
      kind:,
      message:,
      actor: @event_actor,
      from_status: aasm.from_state&.to_s,
      to_status: aasm.to_state&.to_s
    )
  end

  def with_actor(actor)
    @event_actor = actor
    yield
    self
  ensure
    @event_actor = nil
  end

  def enqueue_reminder
    return if scheduled_at.blank?

    InspectionReminderJob
      .set(wait_until: scheduled_at - 24.hours)
      .perform_later(self, scheduled_for: scheduled_at)
  end
end
