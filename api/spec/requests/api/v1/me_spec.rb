require "rails_helper"

RSpec.describe "API V1 Me", type: :request do
  describe "GET /api/v1/me" do
    context "authenticated" do
      it "returns the signed-in user with org and office" do
        organization = create(:organization, name: "Wind Mitigation Network")
        office = create(:office, organization: organization, name: "Cape Coral", city: "Cape Coral")
        user = create(:user, :inspector, organization: organization, office: office,
                                          email: "ivan@windmitigation.network")
        sign_in_via_omniauth(user)

        get "/api/v1/me"

        expect(response).to have_http_status(:ok)
        data = response.parsed_body["data"]
        expect(data["email"]).to eq("ivan@windmitigation.network")
        expect(data["role"]).to eq("inspector")
        expect(data.dig("organization", "name")).to eq("Wind Mitigation Network")
        expect(data.dig("office", "name")).to eq("Cape Coral")
      end
    end

    context "unauthenticated (auth failure)" do
      it "returns the 401 error envelope" do
        get "/api/v1/me"

        expect(response).to have_http_status(:unauthorized)
        error = response.parsed_body["error"]
        expect(error["code"]).to eq("unauthorized")
        expect(error).to have_key("message")
        expect(error).to have_key("details")
      end
    end
  end
end
