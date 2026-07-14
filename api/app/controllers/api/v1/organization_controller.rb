module Api
  module V1
    # Company settings (admin). The signed-in principal's own organization is the
    # only one addressable — there is no cross-tenant org access. org_admin-gated.
    class OrganizationController < BaseController
      def show
        authorize current_organization, policy_class: OrganizationPolicy
        render json: { data: OrganizationSerializer.call(current_organization) }
      end

      def update
        org = current_organization
        authorize org, policy_class: OrganizationPolicy
        org.update!(organization_params)
        render json: { data: OrganizationSerializer.call(org) }
      end

      private

      def organization_params
        params.require(:organization).permit(
          :name, :primary_email, :phone, :timezone, :brand_primary_hex
        )
      end
    end
  end
end
