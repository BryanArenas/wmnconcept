require "rails_helper"

# Billing surface (spec §4, §8.5, M7). Read is tenancy-scoped; send is staff-only.
RSpec.describe "API V1 Invoices", type: :request do
  let(:org)      { create(:organization) }
  let(:agency)   { create(:agency, organization: org) }
  let(:org_admin) { create(:user, :org_admin, organization: org) }

  describe "GET /api/v1/invoices" do
    it "returns all invoices for office staff (happy path)" do
      create_list(:invoice, 2, organization: org, agency: agency)
      sign_in_via_omniauth(org_admin)

      get "/api/v1/invoices"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"].size).to eq(2)
      expect(response.parsed_body["meta"]).to have_key("next_cursor")
    end

    it "requires authentication" do
      get "/api/v1/invoices"
      expect(response).to have_http_status(:unauthorized)
    end

    it "scopes an agency user to their own agency's invoices (tenancy)" do
      other_agency = create(:agency, organization: org)
      agency_user = create(:agency_user, organization: org, agency: agency)
      create(:invoice, organization: org, agency: agency)
      create(:invoice, organization: org, agency: other_agency)
      sign_in_via_omniauth(agency_user)

      get "/api/v1/invoices"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"].size).to eq(1)
      expect(response.parsed_body["data"].first["agency_id"]).to eq(agency.id)
    end

    it "forbids an inspector — billing is not their surface (spec §2)" do
      inspector = create(:user, :inspector, organization: org)
      create(:invoice, organization: org, agency: agency)
      sign_in_via_omniauth(inspector)

      get "/api/v1/invoices"

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /api/v1/invoices/:id/send" do
    it "marks the invoice sent, sets a Stripe id, and enqueues the email (happy path)" do
      invoice = create(:invoice, organization: org, agency: agency, status: "draft")
      sign_in_via_omniauth(org_admin)

      expect {
        post "/api/v1/invoices/#{invoice.id}/send"
      }.to have_enqueued_job(SendInvoiceEmailJob)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.dig("data", "status")).to eq("sent")
      expect(body.dig("data", "stripe_invoice_id")).to be_present
    end

    it "forbids an agency user from sending (staff-only)" do
      agency_user = create(:agency_user, organization: org, agency: agency)
      invoice = create(:invoice, organization: org, agency: agency, status: "draft")
      sign_in_via_omniauth(agency_user)

      post "/api/v1/invoices/#{invoice.id}/send"

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 422 when the invoice is already paid (edge)" do
      invoice = create(:invoice, :paid, organization: org, agency: agency)
      sign_in_via_omniauth(org_admin)

      post "/api/v1/invoices/#{invoice.id}/send"

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("not_payable")
    end

    it "requires authentication" do
      invoice = create(:invoice, organization: org, agency: agency)
      post "/api/v1/invoices/#{invoice.id}/send"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
