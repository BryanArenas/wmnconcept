# Fires when an inspection enters `approved` (spec §6, §9). Renders the PDF,
# persists it to storage + a Report row, then hands off to DeliverReportJob which
# advances the inspection to `delivered`.
#
# THE INVARIANT (spec §6, §9): an inspection never auto-advances to `delivered`
# without a persisted PDF. This job NEVER calls `deliver!`. On final failure it
# HOLDS at `approved` and alerts the manager (the retry_on block below). Delivery
# — and therefore the state advance — happens only in DeliverReportJob, only
# after a Report row with an s3_key exists.
class GenerateReportPdfJob < ApplicationJob
  queue_as :default

  # Spec §9: retry 3× with backoff; on final failure alert the manager and hold
  # at `approved` (never `delivered` without a PDF).
  retry_on StandardError, wait: :polynomially_longer, attempts: 3 do |job, error|
    inspection = job.arguments.first
    Rails.logger.error(
      "[GenerateReportPdfJob] gave up after retries: inspection=#{inspection&.id} " \
      "error=#{error.class}: #{error.message}. Holding at `approved` — no PDF, no delivery."
    )
    # M6+: ManagerAlertJob / Sentry notify. The critical guarantee is that we do
    # NOT call deliver! here: the inspection stays `approved` until a PDF exists.
  end

  def perform(inspection)
    # Only generate for a freshly-approved inspection. A retry after a successful
    # run (already delivered) or a reject-back is a no-op — never regenerate over
    # a delivered report.
    return unless inspection.approved?

    pdf_bytes = ReportPdfRenderer.new(inspection).render
    s3_key = report_key(inspection)
    ReportStorageService.store(key: s3_key, content: pdf_bytes, content_type: "application/pdf")

    report = inspection.report || inspection.build_report(organization: inspection.organization)
    report.update!(s3_key:, generated_at: Time.current)

    DeliverReportJob.perform_later(report)
  end

  private

  def report_key(inspection)
    "reports/#{inspection.id}/wmn-report.pdf"
  end
end
