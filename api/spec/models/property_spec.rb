require "rails_helper"

RSpec.describe Property, type: :model do
  let(:org) { create(:organization) }

  describe ".find_or_create_for!" do
    it "dedupes case/punctuation/whitespace variants of the same address" do
      a = Property.find_or_create_for!(organization: org, address: "123 Main St",
                                       city: "Fort Myers", zip: "33901")
      b = Property.find_or_create_for!(organization: org, address: "123  MAIN st.",
                                       city: "Fort Myers", zip: "33901")

      expect(b.id).to eq(a.id)
      expect(Property.count).to eq(1)
    end

    it "keeps the same street in different cities distinct" do
      a = Property.find_or_create_for!(organization: org, address: "1 Bay Rd", city: "Naples", zip: "34102")
      b = Property.find_or_create_for!(organization: org, address: "1 Bay Rd", city: "Fort Myers", zip: "33901")

      expect(b.id).not_to eq(a.id)
    end

    it "scopes the dedup per tenant" do
      other = create(:organization)
      a = Property.find_or_create_for!(organization: org, address: "5 Elm St", city: "Cape Coral", zip: "33990")
      b = Property.find_or_create_for!(organization: other, address: "5 Elm St", city: "Cape Coral", zip: "33990")

      expect(b.id).not_to eq(a.id)
    end
  end

  describe "validations" do
    it "requires an address and allows a nil structure_type" do
      expect(build(:property, organization: org, address: nil)).not_to be_valid
      expect(build(:property, organization: org, structure_type: nil)).to be_valid
    end

    it "rejects an unknown structure_type" do
      expect(build(:property, organization: org, structure_type: "castle")).not_to be_valid
    end
  end
end
