module Api
  module V1
    # Inspection read + dispatch transitions (spec §8.8, M4).
    # Read scope: agency→own, inspector→own assignments, staff→all.
    # Transitions (assign/schedule/start/cancel): coordinator-gated via Pundit.
    # AASM::InvalidTransition is rescued globally by ErrorEnvelope.
    class InspectionsController < BaseController
      after_action :verify_authorized
      after_action :verify_policy_scoped, only: :index

      def index
        authorize Inspection
        scope = policy_scope(Inspection)
                  .includes(:agency, :property, :homeowner, :assigned_inspector)
        scope = scope.where(status: params[:status]) if params[:status].present?
        inspections, next_cursor = paginate(scope)
        render json: {
          data: inspections.map { |i| InspectionSerializer.call(i) },
          meta: { next_cursor: }
        }
      end

      def show
        inspection = find_scoped_inspection
        authorize inspection
        render json: { data: InspectionSerializer.call(inspection) }
      end

      # Assign an inspector (unassigned → assigned). Body: { inspection: { inspector_id } }
      def assign
        inspection = find_scoped_inspection
        authorize inspection, :assign?
        inspector = current_organization.users.active.find(inspection_params[:inspector_id])
        inspection.assign_to!(inspector, actor: current_user)
        render json: { data: InspectionSerializer.call(inspection.reload) }
      end

      # Set scheduled_at (assigned → scheduled). Body: { inspection: { scheduled_at } }
      # Enqueues T-24h InspectionReminderJob automatically (spec §9).
      def schedule
        inspection = find_scoped_inspection
        authorize inspection, :schedule?
        time = parse_scheduled_at!(inspection_params[:scheduled_at])
        inspection.schedule_for!(time, actor: current_user)
        render json: { data: InspectionSerializer.call(inspection.reload) }
      end

      # Inspector marks arrival (scheduled → in_progress).
      def start
        inspection = find_scoped_inspection
        authorize inspection, :start?
        inspection.start_by!(actor: current_principal)
        render json: { data: InspectionSerializer.call(inspection.reload) }
      end

      # Coordinator voids an in-flight inspection (spec §6 cancel guard).
      def cancel
        inspection = find_scoped_inspection
        authorize inspection, :cancel?
        inspection.cancel_by!(actor: current_principal)
        render json: { data: InspectionSerializer.call(inspection.reload) }
      end

      private

      def find_scoped_inspection
        policy_scope(Inspection).find(params[:id])
      end

      def inspection_params
        params.require(:inspection).permit(:inspector_id, :scheduled_at)
      end

      def parse_scheduled_at!(str)
        raise ActionController::ParameterMissing.new(:scheduled_at) if str.blank?

        parsed = Time.zone.parse(str.to_s)
        render_error(
          code: "invalid_date",
          message: "scheduled_at is not a valid datetime",
          status: :unprocessable_content
        ) and return if parsed.nil?
        parsed
      end
    end
  end
end
