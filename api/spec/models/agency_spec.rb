require "rails_helper"

RSpec.describe Agency, type: :model do
  describe "validations" do
    it "requires a name and a valid type/billing_mode" do
      expect(build(:agency)).to be_valid
      expect(build(:agency, name: nil)).not_to be_valid
      expect(build(:agency, type: "bank")).not_to be_valid
      expect(build(:agency, billing_mode: "wire")).not_to be_valid
    end

    it "requires a commission rate for commission billing" do
      agency = build(:agency, billing_mode: "commission", commission_rate: nil)

      expect(agency).not_to be_valid
      expect(agency.errors[:commission_rate]).to be_present
    end

    it "rejects a commission rate on fixed-rate billing" do
      agency = build(:agency, billing_mode: "fixed_rate", commission_rate: 0.1)

      expect(agency).not_to be_valid
      expect(agency.errors[:commission_rate]).to be_present
    end

    it "bounds the commission rate to (0, 1]" do
      expect(build(:agency, :commission, commission_rate: 0)).not_to be_valid
      expect(build(:agency, :commission, commission_rate: 1.5)).not_to be_valid
      expect(build(:agency, :commission, commission_rate: 0.2)).to be_valid
    end

    it "does not use `type` for STI" do
      expect(Agency.inheritance_column).to be_blank
      # A `type` value that isn't a class name must not trip STI instantiation.
      expect(create(:agency, :real_estate)).to be_an_instance_of(Agency)
    end
  end

  describe "DB constraints" do
    it "backstops the commission-rate rule at the database" do
      agency = build(:agency, billing_mode: "commission", commission_rate: nil)
      # Skip model validation to prove the DB itself refuses the row.
      expect { agency.save!(validate: false) }
        .to raise_error(ActiveRecord::StatementInvalid, /commission_rate_presence/)
    end
  end
end
