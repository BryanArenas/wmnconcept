# Session-based auth over the shared HTTPOnly cookie (spec §10). The principal
# is a staff User or an AgencyUser — separate surfaces that never share auth
# (spec §2). Role is derived from the principal record, never from client input
# or a switcher (spec §13). Access the session via `request.session` so this
# works cleanly in API-only controllers.
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :set_current_request_details
  end

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = if (id = request.session[:user_id])
      User.active.find_by(id: id)
    end
  end

  def current_agency_user
    return @current_agency_user if defined?(@current_agency_user)

    @current_agency_user = if (id = request.session[:agency_user_id])
      AgencyUser.active.find_by(id: id)
    end
  end

  # The authenticated actor for this request, whichever surface they came from.
  def current_principal
    current_user || current_agency_user
  end

  def current_organization
    current_principal&.organization || resolve_organization
  end

  def signed_in?
    current_principal.present?
  end

  # Guard for protected actions. Renders the 401 envelope and halts.
  def authenticate_user!
    return if signed_in?

    render_error(code: "unauthorized", message: "Authentication required", status: :unauthorized)
  end

  def sign_in(principal)
    request.reset_session # rotate session id on privilege change (fixation defense)

    case principal
    when User
      request.session[:user_id] = principal.id
      @current_user = principal
      @current_agency_user = nil
    when AgencyUser
      request.session[:agency_user_id] = principal.id
      @current_agency_user = principal
      @current_user = nil
    else
      raise ArgumentError, "unknown principal: #{principal.class}"
    end

    Current.principal = principal
  end

  def sign_out
    @current_user = nil
    @current_agency_user = nil
    Current.principal = nil
    request.reset_session
  end

  private

  def set_current_request_details
    Current.request_id = request.request_id
    Current.user_agent = request.user_agent
    Current.ip_address = request.remote_ip
    Current.principal = current_principal
  end

  # Single tenant at launch: resolve the org by request subdomain, else fall
  # back to the launch (oldest) organization. Ordered by created_at because a
  # UUID PK gives no meaningful `.first`. Kept multi-tenant-ready (spec §13)
  # without building white-label machinery.
  def resolve_organization
    @resolve_organization ||= begin
      subdomain = request.subdomains.first
      Organization.find_by(subdomain: subdomain) if subdomain.present?
    end || Organization.order(:created_at).first
  end
end
