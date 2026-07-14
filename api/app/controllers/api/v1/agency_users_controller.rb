module Api
  module V1
    # Invite a partner login into an agency (spec §4:
    # POST /agencies/:id/agency_users, role:org_admin). The agency is resolved
    # through policy_scope so an admin can never invite into another org's
    # agency — a cross-tenant id simply 404s.
    class AgencyUsersController < BaseController
      after_action :verify_authorized

      def create
        agency = policy_scope(Agency).find(params[:agency_id])
        authorize AgencyUser

        agency_user = agency.agency_users.create!(
          organization: agency.organization,
          **agency_user_params.to_h.symbolize_keys
        )

        invite_url = InvitationDispatcher.call(agency_user, inviter: current_user)

        render json: { data: AgencyUserSerializer.call(agency_user), invite_url: }, status: :created
      end

      private

      def agency_user_params
        params.require(:agency_user).permit(:name, :email)
      end
    end
  end
end
