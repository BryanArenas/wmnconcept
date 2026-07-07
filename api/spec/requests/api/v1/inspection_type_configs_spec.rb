require "rails_helper"

RSpec.describe "API V1 InspectionTypeConfigs", type: :request do
  let(:org) { create(:organization) }

  describe "GET /api/v1/inspection_type_configs" do
    it "returns active configs for the caller's org (happy path)" do
      agency_user = create(:agency_user, organization: org)
      create(:inspection_type_config, organization: org,
                                      inspection_type: "wind_mitigation",
                                      label: "Wind Mitigation", price_cents: 17_500)
      create(:inspection_type_config, :four_point, organization: org)
      sign_in_via_omniauth(agency_user)

      get "/api/v1/inspection_type_configs"

      expect(response).to have_http_status(:ok)
      types = response.parsed_body["data"].map { |c| c["inspection_type"] }
      expect(types).to match_array(%w[wind_mitigation four_point])
      expect(response.parsed_body["data"].first).to include("price_cents", "label")
    end

    it "requires authentication" do
      get "/api/v1/inspection_type_configs"
      expect(response).to have_http_status(:unauthorized)
    end

    it "does not return inactive configs" do
      coordinator = create(:user, :coordinator, organization: org)
      create(:inspection_type_config, organization: org,
                                      inspection_type: "wind_mitigation",
                                      label: "Wind Mitigation", price_cents: 17_500,
                                      active: false)
      sign_in_via_omniauth(coordinator)

      get "/api/v1/inspection_type_configs"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"]).to be_empty
    end
  end
end
