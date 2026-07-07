module Api
  module V1
    # Agency management (spec §8.9), org_admin only. Creating an agency can
    # atomically invite its first partner login (the dialog's "primary contact"),
    # so a partially-created agency never lingers.
    class AgenciesController < BaseController
      # Safety net: every action must authorize; index must also scope.
      after_action :verify_authorized
      after_action :verify_policy_scoped, only: :index

      def index
        authorize Agency # index? → org_admin (spec §4)
        agencies, next_cursor = paginate(policy_scope(Agency))
        render json: {
          data: agencies.map { |a| AgencySerializer.call(a) },
          meta: { next_cursor: next_cursor }
        }
      end

      def create
        authorize Agency

        agency = nil
        ActiveRecord::Base.transaction do
          agency = current_organization.agencies.create!(agency_params)
          invite_first_agency_user!(agency)
        end

        render json: { data: AgencySerializer.call(agency) }, status: :created
      end

      private

      def agency_params
        params.require(:agency).permit(
          :name, :type, :billing_mode, :commission_rate, :primary_contact_email, :phone
        )
      end

      # Optional: the create dialog may include a first agency user to invite.
      def invite_first_agency_user!(agency)
        return unless params.key?(:agency_user)

        attrs = params.require(:agency_user).permit(:name, :email)
        return if attrs[:email].blank?

        authorize AgencyUser
        agency.agency_users.create!(organization: agency.organization, **attrs.to_h.symbolize_keys)
      end
    end
  end
end
