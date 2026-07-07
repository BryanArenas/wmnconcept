# Physical office (FT Myers HQ + Cape Coral). Internal join-ish table — bigint PK.
class Office < ApplicationRecord
  belongs_to :organization
  has_many :users, dependent: :nullify

  validates :name, presence: true
end
