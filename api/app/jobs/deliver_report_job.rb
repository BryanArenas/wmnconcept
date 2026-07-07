# Fires after a report PDF is generated (spec §9). Emails the report link to
# every associated party and records a per-recipient delivery ledger in
# `reports.delivered_to`; a partial failure re-enqueues only the failed
# recipients. Once the report exists and delivery has been attempted, it advances
# the inspection `approved → delivered` (spec §6 "(auto)" edge), which fires
# CreateInvoiceJob.
#
# The state advance is guarded by `approved?` so re-runs/retries transition at
# most once. The §6 invariant holds structurally: this job only runs on a Report
# that already has a persisted PDF.
class DeliverReportJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  # only_emails: when re-enqueued for a partial failure, restricts delivery to
  # the recipients that previously failed.
  def perform(report, only_emails: nil)
    inspection = report.inspection
    download_url = ReportStorageService.signed_url(report.s3_key, inspection_id: inspection.id)

    recipients = recipients_for(inspection)
    recipients = recipients.select { |r| only_emails.include?(r[:email]) } if only_emails

    recipients.each { |r| deliver_one(report, inspection, r, download_url) }

    report.delivered_at ||= Time.current
    report.save!

    # Advance the inspection now that a PDF exists and delivery was attempted.
    # Guarded so retries don't re-transition (and re-fire CreateInvoiceJob).
    inspection.deliver! if inspection.approved?

    reenqueue_failures(report, only_emails)
  end

  private

  # Homeowner + agency primary contact + the agency user who submitted the
  # request (spec §1: "delivered to every associated party"). Only recipients
  # with a present email are addressable.
  def recipients_for(inspection)
    submitter = inspection.inspection_request&.submitted_by_agency_user_id &&
                AgencyUser.find_by(id: inspection.inspection_request.submitted_by_agency_user_id)

    [
      { email: inspection.homeowner.email, name: inspection.homeowner.name, role: :homeowner },
      { email: inspection.agency.primary_contact_email, name: inspection.agency.name, role: :agency },
      submitter && { email: submitter.email, name: submitter.name, role: :agency_user }
    ].compact.select { |r| r[:email].present? }
  end

  def deliver_one(report, inspection, recipient, download_url)
    ReportMailer.with(
      recipient_email: recipient[:email],
      recipient_name: recipient[:name],
      inspection:,
      download_url:
    ).report_ready.deliver_now

    report.record_delivery(email: recipient[:email], role: recipient[:role], status: :delivered)
  rescue StandardError => e
    Rails.logger.warn(
      "[DeliverReportJob] recipient failed: #{recipient[:email]} (#{e.class}: #{e.message})"
    )
    report.record_delivery(email: recipient[:email], role: recipient[:role], status: :failed)
  end

  # Re-enqueue only the still-failed recipients, and only on the first pass, so a
  # permanently-failing address can't loop forever (spec §9: partial success
  # re-enqueues only failed recipients).
  def reenqueue_failures(report, only_emails)
    return if only_emails # already a targeted retry pass — don't chain further

    failed = report.failed_recipients.map { |d| d["email"] }
    return if failed.empty?

    DeliverReportJob.set(wait: 1.minute).perform_later(report, only_emails: failed)
  end
end
