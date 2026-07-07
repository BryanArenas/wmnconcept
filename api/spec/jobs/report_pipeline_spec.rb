require "rails_helper"

# The M6 report pipeline (spec §6/§9). approve → GenerateReportPdf → Deliver →
# deliver! → CreateInvoice. THE INVARIANT: never `delivered` without a PDF.
RSpec.describe "Report pipeline", type: :job do
  let(:org)     { create(:organization) }
  let(:agency)  { create(:agency, organization: org, primary_contact_email: "agency@example.com") }
  let(:manager) { create(:user, :manager, organization: org) }

  def build_reviewable
    insp = create(:inspection, :submitted_for_review, organization: org, agency: agency)
    insp.homeowner.update!(email: "owner@example.com")
    create(:inspection_photo, :uploaded, organization: org, inspection: insp)
    insp
  end

  describe "happy path — approve fires the full pipeline" do
    it "generates the PDF, delivers, advances to delivered, and creates the invoice" do
      inspection = build_reviewable

      perform_enqueued_jobs do
        inspection.approve_by!(actor: manager)
      end
      inspection.reload

      expect(inspection.status).to eq("delivered")
      expect(inspection.report).to be_present
      expect(inspection.report.s3_key).to be_present
      expect(inspection.report.delivered_at).to be_present
      expect(inspection.invoice).to be_present
      expect(inspection.invoice.status).to eq("draft")
      expect(inspection.invoice.amount_cents).to eq(inspection.price_cents)
    end

    it "records a per-recipient delivery ledger (homeowner + agency + submitter)" do
      inspection = build_reviewable

      perform_enqueued_jobs { inspection.approve_by!(actor: manager) }
      ledger = inspection.reload.report.delivered_to

      emails = ledger.map { |d| d["email"] }
      expect(emails).to include("owner@example.com", "agency@example.com")
      expect(ledger.map { |d| d["status"] }.uniq).to eq(["delivered"])
    end
  end

  describe "failure holds at approved (the invariant)" do
    it "keeps the inspection at approved with no report and no invoice when generation fails" do
      inspection = build_reviewable
      allow(ReportPdfRenderer).to receive(:new).and_raise(StandardError, "pdf boom")

      perform_enqueued_jobs do
        inspection.approve_by!(actor: manager)
      end
      inspection.reload

      expect(inspection.status).to eq("approved")
      expect(inspection.report).to be_nil
      expect(inspection.invoice).to be_nil
    end
  end

  describe "CreateInvoiceJob idempotency (never double-bill)" do
    it "creates exactly one invoice even when run twice" do
      inspection = create(:inspection, :delivered, organization: org, agency: agency)

      expect {
        CreateInvoiceJob.perform_now(inspection)
        CreateInvoiceJob.perform_now(inspection)
      }.to change(Invoice, :count).by(1)
    end

    it "does not create a second invoice if a redelivery re-fires the job" do
      inspection = create(:inspection, :delivered, organization: org, agency: agency)
      create(:invoice, organization: org, inspection: inspection, agency: agency)

      expect {
        CreateInvoiceJob.perform_now(inspection)
      }.not_to change(Invoice, :count)
    end
  end

  describe "InvoiceAmount by billing mode (ADR 0002)" do
    it "bills the full fee under fixed_rate" do
      insp = create(:inspection, organization: org, agency: agency, price_cents: 17_500)
      expect(InvoiceAmount.for(insp)).to eq(17_500)
    end

    it "bills the commission share under commission mode" do
      commission_agency = create(:agency, organization: org,
                                          billing_mode: "commission", commission_rate: 0.2)
      insp = create(:inspection, organization: org, agency: commission_agency, price_cents: 17_500)
      expect(InvoiceAmount.for(insp)).to eq(3_500) # 17_500 * 0.2
    end
  end
end
