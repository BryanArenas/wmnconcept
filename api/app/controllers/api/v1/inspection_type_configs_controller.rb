module Api
  module V1
    # Read-only price list (spec §8.2, §11). Agency partners call this to
    # populate the request form type chips with label + price_cents.
    class InspectionTypeConfigsController < BaseController
      after_action :verify_authorized
      after_action :verify_policy_scoped, only: :index

      def index
        authorize InspectionTypeConfig
        configs = policy_scope(InspectionTypeConfig)
        render json: { data: configs.map { |c| InspectionTypeConfigSerializer.call(c) } }
      end
    end
  end
end
