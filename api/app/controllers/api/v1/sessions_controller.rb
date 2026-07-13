module Api
  module V1
    class SessionsController < ApplicationController
      skip_forgery_protection only: %i[create failure]

      # GET/POST /auth/:provider/callback — OmniAuth flow
      def create
        auth = request.env["omniauth.auth"]
        return redirect_to_login(error: "auth_failed") if auth.blank?

        organization = resolve_organization
        principal = User.from_omniauth(auth, organization: organization) ||
                    AgencyUser.from_omniauth(auth, organization: organization)

        if principal
          sign_in(principal)
          redirect_to frontend_url(home_path_for(principal)), allow_other_host: true
        else
          redirect_to_login(error: "not_authorized")
        end
      end

      # POST /api/v1/session — email + password login
      def login
        email = params[:email].to_s.strip.downcase
        password = params[:password].to_s

        if email.blank? || password.blank?
          return render_error(code: "invalid_credentials",
                              message: "Email and password are required",
                              status: :unauthorized)
        end

        organization = resolve_organization
        principal = authenticate_by_password(email, password, organization)

        if principal
          sign_in(principal)
          render json: { redirect_to: home_path_for(principal) }
        else
          render_error(code: "invalid_credentials",
                       message: "Invalid email or password",
                       status: :unauthorized)
        end
      end

      # DELETE /api/v1/session
      def destroy
        sign_out
        head :no_content
      end

      # OmniAuth on_failure target
      def failure
        redirect_to_login(error: params[:message].presence || "auth_failed")
      end

      private

      def authenticate_by_password(email, password, organization)
        user = User.active.find_by(organization_id: organization.id, email: email)
        return user if user&.password_digest.present? && user.authenticate(password)

        agency_user = AgencyUser.active.find_by(organization_id: organization.id, email: email)
        return agency_user if agency_user&.password_digest.present? && agency_user.authenticate(password)

        nil
      end

      def redirect_to_login(error:)
        redirect_to frontend_url("/login?error=#{error}"), allow_other_host: true
      end

      def home_path_for(principal)
        return "/agency/dashboard" if principal.agency?

        principal.inspector? ? "/today" : "/dashboard"
      end

      def frontend_url(path = "")
        base = ENV.fetch("FRONTEND_URL", "http://localhost:3000").chomp("/")
        "#{base}#{path}"
      end
    end
  end
end
