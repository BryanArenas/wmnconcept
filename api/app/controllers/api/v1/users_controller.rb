module Api
  module V1
    # Staff roster (spec §8.8) + provisioning. `index` backs the dispatcher's
    # inspector dropdown; `create` invites a new staff member — the account is
    # created inactive/unconfirmed and cannot sign in until the invitee sets a
    # password via the emailed link (see Invitable).
    class UsersController < BaseController
      after_action :verify_authorized
      after_action :verify_policy_scoped, only: :index

      # Roles a coordinator may hand out. Elevated roles (manager, org_admin)
      # are org_admin-only so a coordinator can't escalate privilege.
      COORDINATOR_ROLES = %w[inspector].freeze

      def index
        authorize User
        # Default to active only (dispatch dropdown); the Team screen passes
        # ?status=all to also surface pending (unconfirmed) invitations.
        scope = policy_scope(User)
        scope = scope.active unless params[:status] == "all"
        scope = scope.where(role: params[:role]) if params[:role].present?
        users, next_cursor = paginate(scope)
        render json: {
          data: users.map { |u| UserSerializer.call(u) },
          meta: { next_cursor: }
        }
      end

      def create
        authorize User
        role = user_params[:role].to_s
        return reject_role unless role_allowed?(role)

        user = current_organization.users.new(user_params)
        user.active = false
        user.confirmed_at = nil
        user.save!

        invite_url = InvitationDispatcher.call(user, inviter: current_user)
        render json: UserSerializer.call(user).merge(invite_url:), status: :created
      end

      private

      def user_params
        params.require(:user).permit(:name, :email, :role, :license_number, :office_id)
      end

      # Valid enum role AND within the actor's authority.
      def role_allowed?(role)
        return false unless User.roles.key?(role)
        return true if current_user.org_admin?

        COORDINATOR_ROLES.include?(role)
      end

      def reject_role
        render_error(
          code: "forbidden_role",
          message: "You are not allowed to provision that role",
          status: :forbidden
        )
      end
    end
  end
end
