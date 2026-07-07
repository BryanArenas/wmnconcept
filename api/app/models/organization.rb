# Tenant root (spec §3). One row at launch; the schema is multi-tenant-ready
# so the white-label future (§13) stays cheap without building its machinery now.
class Organization < ApplicationRecord
  has_many :offices, dependent: :restrict_with_exception
  has_many :users, dependent: :restrict_with_exception
  has_many :agencies, dependent: :restrict_with_exception
  has_many :agency_users, dependent: :restrict_with_exception
  has_many :properties, dependent: :restrict_with_exception
  has_many :homeowners, dependent: :restrict_with_exception
  has_many :inspection_type_configs, dependent: :restrict_with_exception
  has_many :inspection_requests, dependent: :restrict_with_exception
  has_many :inspections, dependent: :restrict_with_exception

  validates :name, presence: true
  validates :subdomain, presence: true, uniqueness: true
  validates :brand_primary_hex, format: { with: /\A#\h{6}\z/, message: "must be a hex color" }
end
