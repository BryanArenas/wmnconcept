module Api
  module V1
    # Read-only inspection list + detail (spec §8.8). Mutations happen via
    # dedicated transition endpoints (M4 dispatch). The scope gates tenancy:
    # agency → own, inspector → own assignments, staff → all (spec §0).
    class InspectionsController < BaseController
      after_action :verify_authorized
      after_action :verify_policy_scoped, only: :index

      def index
        authorize Inspection
        inspections, next_cursor = paginate(
          policy_scope(Inspection).includes(:agency, :property, :homeowner)
        )
        render json: {
          data: inspections.map { |i| InspectionSerializer.call(i) },
          meta: { next_cursor: }
        }
      end

      def show
        inspection = policy_scope(Inspection).find(params[:id])
        authorize inspection
        render json: { data: InspectionSerializer.call(inspection) }
      end
    end
  end
end
