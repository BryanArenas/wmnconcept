module Api
  module V1
    # Operational snapshot for the staff dashboard (spec §8): the four queue
    # counts a coordinator works from + a recent-activity feed. Counts are real
    # aggregates (not a paginated page length), tenancy-scoped via policy_scope.
    class DashboardController < BaseController
      after_action :verify_authorized

      RECENT_LIMIT = 15

      def show
        authorize :dashboard, :show?
        render json: { stats:, activity: }
      end

      private

      def stats
        inspections = policy_scope(Inspection)
        {
          # Fed from Requests → Dispatch → Calendar → Review, respectively.
          pending_requests: policy_scope(InspectionRequest).where(status: "submitted").count,
          unassigned:       inspections.where(status: "unassigned").count,
          scheduled:        inspections.where(status: "scheduled").count,
          awaiting_review:  inspections.where(status: "submitted_for_review").count
        }
      end

      # Office staff have org-wide visibility, so the feed is scoped by tenant.
      def activity
        current_organization.inspection_events
                            .includes(inspection: :property)
                            .order(occurred_at: :desc, id: :desc)
                            .limit(RECENT_LIMIT)
                            .map { |e| ActivityEventSerializer.call(e) }
      end
    end
  end
end
