require "rails_helper"

RSpec.describe "API V1 Users", type: :request do
  let(:org) { create(:organization) }

  describe "GET /api/v1/users" do
    it "returns active org users for a coordinator (happy path)" do
      coordinator = create(:user, :coordinator, organization: org)
      create(:user, :inspector, organization: org, name: "Pat Inspector")
      _other_org = create(:user, :inspector, organization: create(:organization))
      sign_in_via_omniauth(coordinator)

      get "/api/v1/users"

      expect(response).to have_http_status(:ok)
      names = response.parsed_body["data"].map { |u| u["name"] }
      expect(names).to include("Pat Inspector", coordinator.name)
      expect(names).not_to include(_other_org.name)
      expect(response.parsed_body["meta"]).to have_key("next_cursor")
    end

    it "requires authentication" do
      get "/api/v1/users"
      expect(response).to have_http_status(:unauthorized)
    end

    it "filters by role (inspector only for dispatch dropdown)" do
      coordinator = create(:user, :coordinator, organization: org)
      create(:user, :inspector, organization: org, name: "Iris Inspector")
      sign_in_via_omniauth(coordinator)

      get "/api/v1/users", params: { role: "inspector" }

      expect(response).to have_http_status(:ok)
      roles = response.parsed_body["data"].map { |u| u["role"] }
      expect(roles).to all(eq("inspector"))
      expect(roles).not_to include("coordinator")
    end

    it "forbids agency users (auth failure → 403)" do
      agency = create(:agency, organization: org)
      agency_user = create(:agency_user, organization: org, agency: agency)
      sign_in_via_omniauth(agency_user)

      get "/api/v1/users"

      expect(response).to have_http_status(:forbidden)
    end
  end
end
