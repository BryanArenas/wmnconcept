# Fires 24h before `scheduled_at` (spec §9), enqueued by the `schedule`
# transition. Guards skip silently if the inspection was cancelled or rescheduled
# away from the time this job was enqueued for. Notification delivery
# (ActionMailer + Twilio SMS) is wired when the notification layer arrives;
# the structure and guards are real now.
class InspectionReminderJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(inspection, scheduled_for: nil)
    # Skip if the inspection was cancelled after the reminder was enqueued.
    return if inspection.cancelled?

    # Skip if the inspection was rescheduled — the new schedule event enqueues
    # a fresh reminder for the correct time, making this one stale.
    return if scheduled_for.present? && inspection.scheduled_at != scheduled_for

    homeowner  = inspection.homeowner
    inspector  = inspection.assigned_inspector

    Rails.logger.info(
      "[InspectionReminderJob] Reminder due: inspection=#{inspection.id} " \
      "scheduled_at=#{inspection.scheduled_at&.iso8601} " \
      "homeowner=#{homeowner&.email} inspector=#{inspector&.email}"
    )

    # TODO (M5 notification layer):
    #   InspectionMailer.homeowner_reminder(inspection).deliver_later
    #   InspectionMailer.inspector_reminder(inspection).deliver_later
    #   SmsService.send_reminder(inspection) if homeowner.phone.present?
  end
end
