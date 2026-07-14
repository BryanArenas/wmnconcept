require "rails_helper"

RSpec.describe "API V1 Organization (company settings)", type: :request do
  let(:org) { create(:organization, name: "WMN", phone: "239-000-0000") }

  describe "GET /api/v1/organization" do
    it "returns editable company settings for an admin (happy path)" do
      admin = create(:user, :org_admin, organization: org)
      sign_in_via_omniauth(admin)

      get "/api/v1/organization"

      expect(response).to have_http_status(:ok)
      data = response.parsed_body["data"]
      expect(data["name"]).to eq("WMN")
      expect(data).to have_key("phone")
      expect(data).to have_key("primary_email")
    end

    it "forbids non-admin staff (auth failure → 403)" do
      coordinator = create(:user, :coordinator, organization: org)
      sign_in_via_omniauth(coordinator)

      get "/api/v1/organization"

      expect(response).to have_http_status(:forbidden)
    end

    it "requires authentication" do
      get "/api/v1/organization"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PATCH /api/v1/organization" do
    it "updates company fields (admin)" do
      admin = create(:user, :org_admin, organization: org)
      sign_in_via_omniauth(admin)

      patch "/api/v1/organization", params: {
        organization: { name: "Wind Mitigation Network", phone: "239-887-3948",
                        primary_email: "office@wmn.example", timezone: "America/New_York" }
      }

      expect(response).to have_http_status(:ok)
      expect(org.reload.name).to eq("Wind Mitigation Network")
      expect(org.phone).to eq("239-887-3948")
    end

    it "rejects an invalid brand hex (edge → 422)" do
      admin = create(:user, :org_admin, organization: org)
      sign_in_via_omniauth(admin)

      patch "/api/v1/organization", params: { organization: { brand_primary_hex: "red" } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "forbids a coordinator from updating the company" do
      coordinator = create(:user, :coordinator, organization: org)
      sign_in_via_omniauth(coordinator)

      patch "/api/v1/organization", params: { organization: { name: "Hacked" } }

      expect(response).to have_http_status(:forbidden)
      expect(org.reload.name).to eq("WMN")
    end
  end
end
