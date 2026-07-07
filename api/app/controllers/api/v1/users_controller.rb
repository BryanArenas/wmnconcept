module Api
  module V1
    # Read-only staff roster, used by the dispatcher's inspector dropdown
    # (spec §8.8). Filter ?role=inspector to narrow to assignable staff.
    class UsersController < BaseController
      after_action :verify_authorized
      after_action :verify_policy_scoped, only: :index

      def index
        authorize User
        scope = policy_scope(User).active
        scope = scope.where(role: params[:role]) if params[:role].present?
        users, next_cursor = paginate(scope)
        render json: {
          data: users.map { |u| UserSerializer.call(u) },
          meta: { next_cursor: }
        }
      end
    end
  end
end
