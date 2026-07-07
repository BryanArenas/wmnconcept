require "rails_helper"

RSpec.describe InspectionTypeConfig, type: :model do
  let(:org) { create(:organization) }

  describe "validations" do
    it "accepts a valid type, label, and non-negative price" do
      expect(build(:inspection_type_config, organization: org)).to be_valid
    end

    it "rejects an unknown type, a missing label, or a negative price" do
      expect(build(:inspection_type_config, organization: org, inspection_type: "moon_survey")).not_to be_valid
      expect(build(:inspection_type_config, organization: org, label: nil)).not_to be_valid
      expect(build(:inspection_type_config, organization: org, price_cents: -1)).not_to be_valid
    end

    it "is unique per type per tenant" do
      create(:inspection_type_config, organization: org, inspection_type: "wind_mitigation")
      dup = build(:inspection_type_config, organization: org, inspection_type: "wind_mitigation")

      expect(dup).not_to be_valid
    end
  end

  it "exposes the price in dollars for the request form" do
    config = build(:inspection_type_config, price_cents: 17_500)
    expect(config.price_dollars).to eq(175.0)
  end
end
