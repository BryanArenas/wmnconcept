# Transactional delivery of the finished report (spec §9, §12.6). The delivery
# provider is Postmark in production (a launch blocker per §13 — sender-domain
# auth underpins the 24-hour promise); in dev/test ActionMailer's :test adapter
# collects the messages so DeliverReportJob's per-recipient ledger is verifiable
# without a live provider.
class ReportMailer < ApplicationMailer
  # params: recipient_email, recipient_name, inspection, download_url
  def report_ready
    @inspection    = params[:inspection]
    @recipient     = params[:recipient_name]
    @download_url  = params[:download_url]
    @property      = @inspection.property

    mail(
      to: params[:recipient_email],
      subject: "Your wind mitigation report is ready"
    )
  end
end
