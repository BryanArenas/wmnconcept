require "rails_helper"

RSpec.describe "API V1 Inspections", type: :request do
  let(:org) { create(:organization) }

  describe "GET /api/v1/inspections" do
    it "returns all org inspections for a coordinator (happy path)" do
      coordinator = create(:user, :coordinator, organization: org)
      agency = create(:agency, organization: org)
      create_list(:inspection, 3, organization: org, agency: agency)
      sign_in_via_omniauth(coordinator)

      get "/api/v1/inspections"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"].size).to eq(3)
      expect(response.parsed_body["meta"]).to have_key("next_cursor")
    end

    it "requires authentication" do
      get "/api/v1/inspections"
      expect(response).to have_http_status(:unauthorized)
    end

    it "agency user sees only their own agency's inspections (tenancy scope)" do
      agency_a = create(:agency, organization: org)
      agency_b = create(:agency, organization: org)
      user_a = create(:agency_user, organization: org, agency: agency_a)
      create(:inspection, organization: org, agency: agency_a)
      create(:inspection, organization: org, agency: agency_b)
      sign_in_via_omniauth(user_a)

      get "/api/v1/inspections"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"].size).to eq(1)
      expect(response.parsed_body["data"].first["agency_id"]).to eq(agency_a.id)
    end

    it "inspector sees only their own assigned inspections (tenancy scope)" do
      inspector = create(:user, :inspector, organization: org)
      agency = create(:agency, organization: org)
      create(:inspection, :assigned, organization: org, agency: agency,
                                     assigned_inspector: inspector)
      create(:inspection, organization: org, agency: agency) # unassigned, different inspector
      sign_in_via_omniauth(inspector)

      get "/api/v1/inspections"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"].size).to eq(1)
      expect(response.parsed_body["data"].first["assigned_inspector_id"]).to eq(inspector.id)
    end
  end

  describe "GET /api/v1/inspections/:id" do
    it "returns the inspection detail (happy path)" do
      coordinator = create(:user, :coordinator, organization: org)
      agency = create(:agency, organization: org)
      inspection = create(:inspection, organization: org, agency: agency,
                                       inspection_type: "wind_mitigation", price_cents: 17_500)
      sign_in_via_omniauth(coordinator)

      get "/api/v1/inspections/#{inspection.id}"

      expect(response).to have_http_status(:ok)
      data = response.parsed_body["data"]
      expect(data["id"]).to eq(inspection.id)
      expect(data["inspection_type"]).to eq("wind_mitigation")
      expect(data["price_cents"]).to eq(17_500)
    end

    it "requires authentication" do
      agency = create(:agency, organization: org)
      inspection = create(:inspection, organization: org, agency: agency)
      get "/api/v1/inspections/#{inspection.id}"
      expect(response).to have_http_status(:unauthorized)
    end

    it "cannot see an inspection from another org (cross-tenant → 404)" do
      coordinator = create(:user, :coordinator, organization: org)
      other_org = create(:organization)
      other_agency = create(:agency, organization: other_org)
      foreign = create(:inspection, organization: other_org, agency: other_agency)
      sign_in_via_omniauth(coordinator)

      get "/api/v1/inspections/#{foreign.id}"

      expect(response).to have_http_status(:not_found)
    end
  end
end
