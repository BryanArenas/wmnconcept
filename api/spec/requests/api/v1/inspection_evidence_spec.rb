require "rails_helper"

RSpec.describe "API V1 Inspection evidence (review pane)", type: :request do
  let(:org) { create(:organization) }

  def submitted_inspection
    create(:inspection, :submitted_for_review, organization: org, inspection_type: "wind_mitigation")
  end

  describe "GET /api/v1/inspections/:id/evidence" do
    it "returns form fields, saved answers, and uploaded photos (happy path)" do
      manager = create(:user, :manager, organization: org)
      inspection = submitted_inspection
      create(:inspection_form_template, organization: org, inspection_type: "wind_mitigation")
      create(:inspection_form_response, organization: org, inspection: inspection,
                                        responses: { "roof_cover_type" => "tile" })
      create(:inspection_photo, :uploaded, organization: org, inspection: inspection, filename: "roof.jpg")
      create(:inspection_photo, organization: org, inspection: inspection) # pending — excluded
      sign_in_via_omniauth(manager)

      get "/api/v1/inspections/#{inspection.id}/evidence"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["form"]["fields"].map { |f| f["key"] }).to include("roof_cover_type")
      expect(body["form"]["responses"]["roof_cover_type"]).to eq("tile")
      expect(body["photos"].size).to eq(1) # only the uploaded one
      expect(body["photos"].first).to have_key("view_url")
    end

    it "returns empty fields when no template is configured (edge)" do
      manager = create(:user, :manager, organization: org)
      inspection = submitted_inspection
      sign_in_via_omniauth(manager)

      get "/api/v1/inspections/#{inspection.id}/evidence"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["form"]["fields"]).to eq([])
    end

    it "lets an org_admin review evidence" do
      admin = create(:user, :org_admin, organization: org)
      inspection = submitted_inspection
      sign_in_via_omniauth(admin)

      get "/api/v1/inspections/#{inspection.id}/evidence"

      expect(response).to have_http_status(:ok)
    end

    it "requires authentication" do
      inspection = submitted_inspection
      get "/api/v1/inspections/#{inspection.id}/evidence"
      expect(response).to have_http_status(:unauthorized)
    end

    it "forbids agency users (auth failure → 403)" do
      agency = create(:agency, organization: org)
      agency_user = create(:agency_user, organization: org, agency:)
      inspection = create(:inspection, :submitted_for_review, organization: org, agency: agency)
      sign_in_via_omniauth(agency_user)

      get "/api/v1/inspections/#{inspection.id}/evidence"

      expect(response).to have_http_status(:forbidden)
    end
  end
end
