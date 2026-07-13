class UpdateInspectionTypeConstraints < ActiveRecord::Migration[8.1]
  NEW_TYPES = %w[
    wind_mitigation four_point roof_condition general_home
    wind_four_combo hoa_master_wind commercial_wind
  ].freeze

  OLD_TYPES = %w[
    wind_mitigation four_point roof_condition general_home
    hoa_master_wind wind_type_ii wind_type_iii
  ].freeze

  def change
    reversible do |dir|
      dir.up { swap_constraints(NEW_TYPES) }
      dir.down { swap_constraints(OLD_TYPES) }
    end
  end

  private

  def swap_constraints(types)
    type_list = types.map { |t| "'#{t}'" }.join(", ")
    array_list = types.map { |t| "'#{t}'" }.join(", ")

    remove_check_constraint :inspection_type_configs, name: "inspection_type_configs_type_check"
    add_check_constraint :inspection_type_configs,
                         "inspection_type IN (#{type_list})",
                         name: "inspection_type_configs_type_check"

    remove_check_constraint :inspections, name: "inspections_type_check"
    add_check_constraint :inspections,
                         "inspection_type IN (#{type_list})",
                         name: "inspections_type_check"

    remove_check_constraint :inspection_requests, name: "inspection_requests_types_valid_check"
    add_check_constraint :inspection_requests,
                         "requested_types <@ ARRAY[#{array_list}]::varchar[]",
                         name: "inspection_requests_types_valid_check"
  end
end
