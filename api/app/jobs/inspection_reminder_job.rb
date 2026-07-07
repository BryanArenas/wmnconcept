# Fires 24h before `scheduled_at` (spec §9), enqueued by the `schedule`
# transition (spec §6). Sends the homeowner + inspector an SMS + email reminder.
# Skips silently if the inspection was cancelled or rescheduled away from the
# time this reminder was set for.
#
# Delivery body lands in M4 (Dispatch). Stubbed as a guarded no-op until then;
# the guard (skip-if-cancelled) is real now so scheduling logic can rely on it.
class InspectionReminderJob < ApplicationJob
  queue_as :default

  def perform(inspection, scheduled_for: nil)
    return if inspection.cancelled?
    # Stale reminder from a previous schedule — the inspection was moved.
    return if scheduled_for.present? && inspection.scheduled_at != scheduled_for

    Rails.logger.info(
      "[InspectionReminderJob] inspection=#{inspection.id} — SMS/email reminder lands in M4."
    )
    # M4: send SMS + email to homeowner and assigned inspector.
  end
end
