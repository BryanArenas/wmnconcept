class EnableExtensions < ActiveRecord::Migration[8.1]
  def change
    # gen_random_uuid() for UUID primary keys on externally-exposed resources.
    enable_extension "pgcrypto"
    # citext for case-insensitive, unique-per-org emails (spec §3).
    enable_extension "citext"
  end
end
