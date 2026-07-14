module Api
  module V1
    # Public invitation surface. An invitee arrives from the emailed link with a
    # signed, single-use token (see Invitable) and no session. `show` validates
    # the token so the frontend can greet them; `accept` sets the password,
    # confirms the email, activates the account, and signs them in.
    #
    # Inherits ApplicationController (not BaseController) because the invitee is
    # not yet authenticated. CSRF still applies: the frontend GETs `show` first
    # (which seeds the XSRF-TOKEN cookie) before POSTing `accept`.
    class InvitationsController < ApplicationController
      MIN_PASSWORD_LENGTH = 8

      TYPES = {
        "staff"  => User,
        "agency" => AgencyUser
      }.freeze

      # GET /api/v1/invitations?token=...&type=staff
      def show
        principal = resolve_principal
        return render_invalid_token if principal.nil?

        render json: {
          name: principal.name,
          email: principal.email,
          type: params[:type],
          organization: principal.organization.name
        }
      end

      # POST /api/v1/invitations/accept
      def accept
        principal = resolve_principal
        return render_invalid_token if principal.nil?

        password = params[:password].to_s
        return render_weak_password if password.length < MIN_PASSWORD_LENGTH

        principal.confirm_with_password!(password)
        sign_in(principal)
        render json: { redirect_to: home_path_for(principal) }
      end

      private

      def resolve_principal
        klass = TYPES[params[:type].to_s]
        return nil unless klass

        klass.from_invitation_token(params[:token].to_s)
      end

      def render_invalid_token
        render_error(
          code: "invalid_invitation",
          message: "This invitation link is invalid or has expired.",
          status: :unprocessable_content
        )
      end

      def render_weak_password
        render_error(
          code: "weak_password",
          message: "Password must be at least #{MIN_PASSWORD_LENGTH} characters.",
          status: :unprocessable_content,
          details: [{ field: "password", message: "is too short (minimum #{MIN_PASSWORD_LENGTH} characters)" }]
        )
      end

      def home_path_for(principal)
        return "/agency/dashboard" if principal.agency?

        principal.inspector? ? "/today" : "/dashboard"
      end
    end
  end
end
