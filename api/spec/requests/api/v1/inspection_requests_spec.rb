require "rails_helper"

RSpec.describe "API V1 InspectionRequests", type: :request do
  let(:org) { create(:organization) }

  before do
    create(:inspection_type_config, organization: org,
                                    inspection_type: "wind_mitigation",
                                    label: "Wind Mitigation",
                                    price_cents: 17_500)
    create(:inspection_type_config, :four_point, organization: org)
  end

  describe "POST /api/v1/inspection_requests" do
    it "creates a request, deduping property and homeowner" do
      agency_user = create(:agency_user, organization: org)
      sign_in_via_omniauth(agency_user)

      expect {
        post "/api/v1/inspection_requests", params: {
          property: { address: "10 Gulf Dr", city: "Fort Myers", state: "FL", zip: "33901" },
          homeowner: { name: "Kim Owner", email: "kim@owner.example" },
          inspection_request: { requested_types: ["wind_mitigation"], preferred_dates: "Anytime" }
        }
      }.to change(InspectionRequest, :count).by(1)
        .and change(Property, :count).by(1)
        .and change(Homeowner, :count).by(1)

      expect(response).to have_http_status(:created)
      data = response.parsed_body["data"]
      expect(data["status"]).to eq("submitted")
      expect(data["requested_types"]).to eq(["wind_mitigation"])
      expect(data.dig("property", "address")).to eq("10 Gulf Dr")

      # A second identical submission reuses the same property and homeowner.
      expect {
        post "/api/v1/inspection_requests", params: {
          property: { address: "10 Gulf Dr", city: "Fort Myers", state: "FL", zip: "33901" },
          homeowner: { name: "Kim Owner", email: "kim@owner.example" },
          inspection_request: { requested_types: ["four_point"] }
        }
      }.to change(InspectionRequest, :count).by(1)
        .and change(Property, :count).by(0)
        .and change(Homeowner, :count).by(0)
    end

    it "forbids a staff user from submitting a request (auth failure → 403)" do
      coordinator = create(:user, :coordinator, organization: org)
      sign_in_via_omniauth(coordinator)

      post "/api/v1/inspection_requests", params: {
        property: { address: "1 Elm St", city: "Naples", state: "FL", zip: "34102" },
        homeowner: { name: "Sam Owner", email: "sam@owner.example" },
        inspection_request: { requested_types: ["wind_mitigation"] }
      }

      expect(response).to have_http_status(:forbidden)
      expect(InspectionRequest.count).to eq(0)
    end

    it "rejects unknown inspection types (edge → 422 envelope)" do
      agency_user = create(:agency_user, organization: org)
      sign_in_via_omniauth(agency_user)

      post "/api/v1/inspection_requests", params: {
        property: { address: "2 Bay Rd", city: "Bonita Springs", state: "FL", zip: "34135" },
        homeowner: { name: "Unknown Type Owner", email: "u@example.com" },
        inspection_request: { requested_types: ["moon_survey"] }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("unprocessable_entity")
      expect(InspectionRequest.count).to eq(0)
    end
  end

  describe "GET /api/v1/inspection_requests" do
    it "returns all in-org requests for a coordinator (happy path)" do
      coordinator = create(:user, :coordinator, organization: org)
      agency = create(:agency, organization: org)
      create(:inspection_request, organization: org, agency: agency)
      create(:inspection_request, organization: org, agency: agency)
      sign_in_via_omniauth(coordinator)

      get "/api/v1/inspection_requests"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"].size).to eq(2)
      expect(response.parsed_body["meta"]).to have_key("next_cursor")
    end

    it "agency user sees only their own agency's requests (tenancy scope)" do
      agency_a = create(:agency, organization: org)
      agency_b = create(:agency, organization: org)
      user_a = create(:agency_user, organization: org, agency: agency_a)
      create(:inspection_request, organization: org, agency: agency_a)
      create(:inspection_request, organization: org, agency: agency_b)
      sign_in_via_omniauth(user_a)

      get "/api/v1/inspection_requests"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"].size).to eq(1)
      expect(response.parsed_body["data"].first["agency_id"]).to eq(agency_a.id)
    end

    it "supports filtering by status (edge)" do
      coordinator = create(:user, :coordinator, organization: org)
      agency = create(:agency, organization: org)
      create(:inspection_request, organization: org, agency: agency, status: "submitted")
      create(:inspection_request, :accepted, organization: org, agency: agency)
      sign_in_via_omniauth(coordinator)

      get "/api/v1/inspection_requests", params: { status: "submitted" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"].size).to eq(1)
      expect(response.parsed_body["data"].first["status"]).to eq("submitted")
    end
  end

  describe "POST /api/v1/inspection_requests/:id/accept" do
    it "spawns one inspection per type and marks the request accepted (happy path)" do
      coordinator = create(:user, :coordinator, organization: org)
      req = create(:inspection_request, :multi_type, organization: org)
      sign_in_via_omniauth(coordinator)

      expect {
        post "/api/v1/inspection_requests/#{req.id}/accept"
      }.to change(Inspection, :count).by(2)

      expect(response).to have_http_status(:ok)
      data = response.parsed_body
      expect(data.dig("data", "status")).to eq("accepted")
      expect(data["inspections"].size).to eq(2)
      expect(data["inspections"].map { |i| i["inspection_type"] })
        .to match_array(%w[wind_mitigation four_point])
    end

    it "forbids an agency user from accepting (auth failure → 403)" do
      agency_user = create(:agency_user, organization: org)
      req = create(:inspection_request, organization: org,
                                        agency: agency_user.agency)
      sign_in_via_omniauth(agency_user)

      post "/api/v1/inspection_requests/#{req.id}/accept"

      expect(response).to have_http_status(:forbidden)
      expect(req.reload).to be_submitted
    end

    it "returns 422 when a requested type has no active price config (edge)" do
      coordinator = create(:user, :coordinator, organization: org)
      # roof_condition has no price config in this org
      req = create(:inspection_request, organization: org,
                                        requested_types: %w[wind_mitigation roof_condition])
      sign_in_via_omniauth(coordinator)

      post "/api/v1/inspection_requests/#{req.id}/accept"

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("missing_price_config")
      expect(req.reload).to be_submitted
      expect(Inspection.count).to eq(0) # atomic rollback
    end
  end

  describe "POST /api/v1/inspection_requests/:id/decline" do
    it "declines the request with a stored reason (happy path)" do
      coordinator = create(:user, :coordinator, organization: org)
      req = create(:inspection_request, organization: org)
      sign_in_via_omniauth(coordinator)

      post "/api/v1/inspection_requests/#{req.id}/decline", params: {
        inspection_request: { decline_reason: "Outside service area" }
      }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "status")).to eq("declined")
      expect(req.reload.decline_reason).to eq("Outside service area")
    end

    it "forbids an agency user from declining (auth failure → 403)" do
      agency_user = create(:agency_user, organization: org)
      req = create(:inspection_request, organization: org,
                                        agency: agency_user.agency)
      sign_in_via_omniauth(agency_user)

      post "/api/v1/inspection_requests/#{req.id}/decline", params: {
        inspection_request: { decline_reason: "Trying anyway" }
      }

      expect(response).to have_http_status(:forbidden)
      expect(req.reload).to be_submitted
    end

    it "returns 422 when decline_reason is blank (edge)" do
      coordinator = create(:user, :coordinator, organization: org)
      req = create(:inspection_request, organization: org)
      sign_in_via_omniauth(coordinator)

      post "/api/v1/inspection_requests/#{req.id}/decline", params: {
        inspection_request: { decline_reason: "" }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(req.reload).to be_submitted
    end
  end
end
