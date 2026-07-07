require "rails_helper"

RSpec.describe Homeowner, type: :model do
  let(:org) { create(:organization) }

  describe ".find_or_create_for!" do
    it "dedupes by case-insensitive email within an org" do
      a = Homeowner.find_or_create_for!(organization: org, name: "Dana A", email: "Dana@Example.com")
      b = Homeowner.find_or_create_for!(organization: org, name: "Dana B", email: "dana@example.com")

      expect(b.id).to eq(a.id)
    end

    it "treats homeowners with no email as distinct" do
      a = Homeowner.find_or_create_for!(organization: org, name: "No Email 1")
      b = Homeowner.find_or_create_for!(organization: org, name: "No Email 2")

      expect(b.id).not_to eq(a.id)
    end

    it "scopes the dedup per tenant" do
      other = create(:organization)
      a = Homeowner.find_or_create_for!(organization: org, name: "Dana", email: "dana@example.com")
      b = Homeowner.find_or_create_for!(organization: other, name: "Dana", email: "dana@example.com")

      expect(b.id).not_to eq(a.id)
    end
  end

  describe "validations" do
    it "requires a name" do
      expect(build(:homeowner, organization: org, name: nil)).not_to be_valid
    end

    it "rejects a malformed email but allows a blank one" do
      expect(build(:homeowner, organization: org, email: "not-an-email")).not_to be_valid
      expect(build(:homeowner, :no_email, organization: org)).to be_valid
    end
  end
end
