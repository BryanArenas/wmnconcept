# Emails the agency their invoice with a pay link (spec §9 SendInvoiceEmailJob).
# Postmark in production; the :test adapter collects it in dev/test.
class InvoiceMailer < ApplicationMailer
  # params: invoice, pay_url
  def invoice_sent
    @invoice = params[:invoice]
    @agency  = @invoice.agency
    @pay_url = params[:pay_url]
    @amount  = format("$%.2f", @invoice.amount_cents / 100.0)

    mail(
      to: @agency.primary_contact_email,
      subject: "Invoice for your inspection — #{@amount}"
    )
  end
end
