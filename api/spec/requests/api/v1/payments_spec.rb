require "rails_helper"

RSpec.describe "API V1 Payments (placeholder pay page)", type: :request do
  let(:org) { create(:organization) }

  describe "GET /api/v1/pay/:id" do
    it "returns the invoice summary for the pay page (happy path, public)" do
      invoice = create(:invoice, :sent, organization: org)

      get "/api/v1/pay/#{invoice.id}"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["amount_cents"]).to eq(invoice.amount_cents)
      expect(body["status"]).to eq("sent")
      expect(body["placeholder"]).to be(true) # no Stripe configured in test
      expect(body["property_address"]).to be_present
    end

    it "404s for an unknown invoice" do
      get "/api/v1/pay/#{SecureRandom.uuid}"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/pay/:id/confirm" do
    it "marks the invoice paid and records a timeline event (placeholder)" do
      invoice = create(:invoice, :sent, organization: org)

      post "/api/v1/pay/#{invoice.id}/confirm"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["status"]).to eq("paid")
      expect(invoice.reload.status).to eq("paid")
      expect(invoice.inspection.inspection_events.where(kind: "payment_received")).to exist
    end

    it "is idempotent — confirming an already-paid invoice stays paid" do
      invoice = create(:invoice, :paid, organization: org)

      post "/api/v1/pay/#{invoice.id}/confirm"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["status"]).to eq("paid")
    end

    it "refuses a voided invoice (edge → 422)" do
      invoice = create(:invoice, :sent, organization: org)
      invoice.update!(status: "void")

      post "/api/v1/pay/#{invoice.id}/confirm"

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("not_payable")
    end
  end
end
