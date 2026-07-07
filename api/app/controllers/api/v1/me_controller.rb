module Api
  module V1
    # GET /api/v1/me — the signed-in user, org, and office. Server Components on
    # the Next side call this with the forwarded session cookie to establish
    # identity and gate role layouts.
    class MeController < BaseController
      def show
        render json: { data: PrincipalSerializer.call(current_principal) }
      end
    end
  end
end
