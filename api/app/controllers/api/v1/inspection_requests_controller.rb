module Api
  module V1
    # Inspection intake (spec §8.2) and coordinator triage (spec §8.7).
    # Agency users create; coordinators/org_admins accept or decline.
    class InspectionRequestsController < BaseController
      after_action :verify_authorized
      after_action :verify_policy_scoped, only: :index

      rescue_from InspectionRequest::MissingPriceError do |e|
        render_error(code: "missing_price_config", message: e.message, status: :unprocessable_content)
      end

      rescue_from InspectionRequest::InvalidTransition do |e|
        render_error(code: "invalid_transition", message: e.message, status: :unprocessable_content)
      end

      def index
        authorize InspectionRequest
        scope = policy_scope(InspectionRequest).includes(:agency, :property, :homeowner)
        scope = scope.where(status: params[:status]) if params[:status].present?
        requests, next_cursor = paginate(scope)
        render json: {
          data: requests.map { |r| InspectionRequestSerializer.call(r) },
          meta: { next_cursor: }
        }
      end

      def create
        authorize InspectionRequest

        # Dedupe property and homeowner within this tenant (spec §3).
        property = Property.find_or_create_for!(
          organization: current_organization, **property_params.to_h.symbolize_keys
        )
        homeowner = Homeowner.find_or_create_for!(
          organization: current_organization, **homeowner_params.to_h.symbolize_keys
        )

        req = current_organization.inspection_requests.create!(
          agency: current_agency_user.agency,
          submitted_by_agency_user: current_agency_user,
          property:,
          homeowner:,
          **intake_params.to_h.symbolize_keys
        )

        render json: { data: InspectionRequestSerializer.call(req) }, status: :created
      end

      def accept
        req = find_scoped_request
        authorize req, :accept?
        spawned = req.accept!(actor: current_user)
        render json: {
          data: InspectionRequestSerializer.call(req),
          inspections: spawned.map { |i| InspectionSerializer.call(i) }
        }
      end

      def decline
        req = find_scoped_request
        authorize req, :decline?
        reason = params.require(:inspection_request).permit(:decline_reason)[:decline_reason].to_s
        req.decline!(reason:)
        render json: { data: InspectionRequestSerializer.call(req) }
      end

      private

      def find_scoped_request
        policy_scope(InspectionRequest).find(params[:id])
      end

      def property_params
        params.require(:property).permit(:address, :city, :state, :zip, :county, :structure_type)
      end

      def homeowner_params
        params.require(:homeowner).permit(:name, :email, :phone)
      end

      def intake_params
        params.require(:inspection_request).permit(:preferred_dates, :notes, requested_types: [])
      end
    end
  end
end
