require "rails_helper"

RSpec.describe "API V1 Availability Blocks", type: :request do
  let(:org) { create(:organization) }

  describe "GET /api/v1/availability_blocks" do
    it "returns only the inspector's own upcoming blocks (happy path)" do
      inspector = create(:user, :inspector, organization: org)
      mine = create(:availability_block, organization: org, user: inspector, reason: "Vacation")
      other = create(:user, :inspector, organization: org)
      _theirs = create(:availability_block, organization: org, user: other, reason: "Not mine")
      sign_in_via_omniauth(inspector)

      get "/api/v1/availability_blocks"

      expect(response).to have_http_status(:ok)
      reasons = response.parsed_body["data"].map { |b| b["reason"] }
      expect(reasons).to contain_exactly("Vacation")
      expect(response.parsed_body["data"].first["id"]).to eq(mine.id)
    end

    it "requires authentication" do
      get "/api/v1/availability_blocks"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/availability_blocks" do
    it "creates a block for the signed-in inspector (happy path)" do
      inspector = create(:user, :inspector, organization: org)
      sign_in_via_omniauth(inspector)

      expect do
        post "/api/v1/availability_blocks", params: {
          availability_block: {
            starts_at: 3.days.from_now.change(hour: 9).iso8601,
            ends_at: 3.days.from_now.change(hour: 12).iso8601,
            reason: "Doctor"
          }
        }
      end.to change { inspector.availability_blocks.count }.by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig("data", "reason")).to eq("Doctor")
    end

    it "rejects an end before the start (edge → 422)" do
      inspector = create(:user, :inspector, organization: org)
      sign_in_via_omniauth(inspector)

      post "/api/v1/availability_blocks", params: {
        availability_block: {
          starts_at: 3.days.from_now.change(hour: 12).iso8601,
          ends_at: 3.days.from_now.change(hour: 9).iso8601
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "details").map { |d| d["field"] }).to include("ends_at")
    end

    it "forbids a coordinator from creating availability blocks (auth failure → 403)" do
      coordinator = create(:user, :coordinator, organization: org)
      sign_in_via_omniauth(coordinator)

      post "/api/v1/availability_blocks", params: {
        availability_block: { starts_at: 1.day.from_now.iso8601, ends_at: 2.days.from_now.iso8601 }
      }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /api/v1/availability_blocks/:id" do
    it "removes the inspector's own block" do
      inspector = create(:user, :inspector, organization: org)
      block = create(:availability_block, organization: org, user: inspector)
      sign_in_via_omniauth(inspector)

      expect { delete "/api/v1/availability_blocks/#{block.id}" }
        .to change { inspector.availability_blocks.count }.by(-1)
      expect(response).to have_http_status(:no_content)
    end

    it "cannot delete another inspector's block (ownership → 404)" do
      inspector = create(:user, :inspector, organization: org)
      other = create(:user, :inspector, organization: org)
      block = create(:availability_block, organization: org, user: other)
      sign_in_via_omniauth(inspector)

      delete "/api/v1/availability_blocks/#{block.id}"

      expect(response).to have_http_status(:not_found)
      expect(AvailabilityBlock.exists?(block.id)).to be(true)
    end
  end
end
