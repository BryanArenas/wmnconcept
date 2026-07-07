require "rails_helper"

# M6 review → delivery endpoints (spec §4, §8.13). approve/reject are
# manager-gated; approve enqueues the report pipeline (§9) but does NOT itself
# deliver (spec §6 invariant).
RSpec.describe "API V1 Inspection review", type: :request do
  let(:org)     { create(:organization) }
  let(:agency)  { create(:agency, organization: org) }
  let(:manager) { create(:user, :manager, organization: org) }

  describe "POST /api/v1/inspections/:id/approve" do
    it "approves and enqueues report generation (happy path)" do
      inspection = create(:inspection, :submitted_for_review, organization: org, agency: agency)
      sign_in_via_omniauth(manager)

      expect {
        post "/api/v1/inspections/#{inspection.id}/approve"
      }.to have_enqueued_job(GenerateReportPdfJob)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "status")).to eq("approved")
      # The invariant: approve does not deliver. No PDF yet ⇒ not delivered.
      expect(response.parsed_body.dig("data", "delivered_at")).to be_nil
    end

    it "returns 401 for unauthenticated request" do
      inspection = create(:inspection, :submitted_for_review, organization: org, agency: agency)
      post "/api/v1/inspections/#{inspection.id}/approve"
      expect(response).to have_http_status(:unauthorized)
    end

    it "forbids a coordinator from approving (manager-gated)" do
      coordinator = create(:user, :coordinator, organization: org)
      inspection = create(:inspection, :submitted_for_review, organization: org, agency: agency)
      sign_in_via_omniauth(coordinator)

      post "/api/v1/inspections/#{inspection.id}/approve"

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body.dig("error", "code")).to eq("forbidden")
    end

    it "returns 422 when the inspection is not awaiting review (edge)" do
      inspection = create(:inspection, :scheduled, organization: org, agency: agency)
      sign_in_via_omniauth(manager)

      post "/api/v1/inspections/#{inspection.id}/approve"

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_transition")
    end
  end

  describe "POST /api/v1/inspections/:id/reject" do
    it "sends the inspection back to in_progress with a note (happy path)" do
      inspection = create(:inspection, :submitted_for_review, organization: org, agency: agency)
      sign_in_via_omniauth(manager)

      post "/api/v1/inspections/#{inspection.id}/reject",
           params: { inspection: { rejection_note: "Roof-to-wall photos are blurry." } }

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.dig("data", "status")).to eq("in_progress")
      expect(body.dig("data", "rejection_note")).to eq("Roof-to-wall photos are blurry.")
    end

    it "returns 422 when the note is missing (guard)" do
      inspection = create(:inspection, :submitted_for_review, organization: org, agency: agency)
      sign_in_via_omniauth(manager)

      post "/api/v1/inspections/#{inspection.id}/reject",
           params: { inspection: { rejection_note: "" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_transition")
    end

    it "returns 401 for unauthenticated request" do
      inspection = create(:inspection, :submitted_for_review, organization: org, agency: agency)
      post "/api/v1/inspections/#{inspection.id}/reject",
           params: { inspection: { rejection_note: "x" } }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/inspections/:id/report" do
    it "returns report metadata + a signed download URL (happy path)" do
      inspection = create(:inspection, :delivered, organization: org, agency: agency)
      create(:report, :delivered, organization: org, inspection: inspection)
      sign_in_via_omniauth(manager)

      get "/api/v1/inspections/#{inspection.id}/report"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.dig("data", "filename")).to eq("wmn-report.pdf")
      expect(body.dig("data", "download_url")).to be_present
    end

    it "returns 404 when no report exists yet (edge)" do
      inspection = create(:inspection, :approved, organization: org, agency: agency)
      sign_in_via_omniauth(manager)

      get "/api/v1/inspections/#{inspection.id}/report"

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body.dig("error", "code")).to eq("report_not_ready")
    end

    it "returns 401 for unauthenticated request" do
      inspection = create(:inspection, :delivered, organization: org, agency: agency)
      create(:report, organization: org, inspection: inspection)
      get "/api/v1/inspections/#{inspection.id}/report"
      expect(response).to have_http_status(:unauthorized)
    end

    it "scopes access — an agency user cannot see another agency's report" do
      other_agency = create(:agency, organization: org)
      agency_user = create(:agency_user, organization: org, agency: other_agency)
      inspection = create(:inspection, :delivered, organization: org, agency: agency)
      create(:report, organization: org, inspection: inspection)
      sign_in_via_omniauth(agency_user)

      get "/api/v1/inspections/#{inspection.id}/report"

      # Out of scope ⇒ the inspection lookup 404s before the report is reached.
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/inspections/:id/report/download" do
    it "streams the stored PDF (happy path)" do
      inspection = create(:inspection, :delivered, organization: org, agency: agency)
      report = create(:report, organization: org, inspection: inspection)
      ReportStorageService.store(key: report.s3_key, content: "%PDF-1.4 fake")
      sign_in_via_omniauth(manager)

      get "/api/v1/inspections/#{inspection.id}/report/download"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/pdf")
      expect(response.body).to include("%PDF")
    end

    it "returns 401 for unauthenticated request" do
      inspection = create(:inspection, :delivered, organization: org, agency: agency)
      create(:report, organization: org, inspection: inspection)
      get "/api/v1/inspections/#{inspection.id}/report/download"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
