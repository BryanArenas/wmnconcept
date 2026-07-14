require "rails_helper"

RSpec.describe RequestPaymentJob, type: :job do
  let(:org) { create(:organization) }

  it "creates a sent invoice at the snapshotted amount and emails the pay link" do
    inspection = create(:inspection, :assigned, organization: org)

    expect { described_class.perform_now(inspection) }
      .to change(Invoice, :count).by(1)
      .and have_enqueued_mail(InvoiceMailer, :invoice_sent)

    invoice = inspection.reload.invoice
    expect(invoice.status).to eq("sent")
    expect(invoice.amount_cents).to eq(inspection.price_cents) # fixed_rate agency
  end

  it "is idempotent — a reschedule/retry never creates a second invoice" do
    inspection = create(:inspection, :assigned, organization: org)
    described_class.perform_now(inspection)

    expect { described_class.perform_now(inspection) }.not_to change(Invoice, :count)
  end

  it "does not re-bill an invoice that is already paid" do
    inspection = create(:inspection, :assigned, organization: org)
    described_class.perform_now(inspection)
    inspection.reload.invoice.mark_paid!

    described_class.perform_now(inspection)

    expect(inspection.reload.invoice.status).to eq("paid")
  end
end
