require "rails_helper"

RSpec.describe "API V1 Health", type: :request do
  describe "GET /api/v1/health" do
    it "returns ok without authentication" do
      get "/api/v1/health"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["status"]).to eq("ok")
      expect(response.parsed_body["service"]).to eq("wmn-api")
    end
  end
end
