# Every non-2xx response uses the envelope `{ error: { code, message, details } }`
# (spec §0, §4). Controllers call render_error, and common exceptions are mapped
# here so no raw Rails error HTML/JSON ever leaks to a client.
module ErrorEnvelope
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid
    rescue_from ActionController::ParameterMissing, with: :render_parameter_missing
    rescue_from ActionController::InvalidAuthenticityToken, with: :render_invalid_csrf
    rescue_from Pundit::NotAuthorizedError, with: :render_forbidden
  end

  # Render the canonical error envelope. `details` is always an array so clients
  # can iterate without null-checks; field errors land here.
  def render_error(code:, message:, status:, details: [])
    render json: { error: { code: code, message: message, details: Array(details) } }, status: status
  end

  private

  def render_not_found(error)
    render_error(code: "not_found", message: "Resource not found", status: :not_found)
  end

  def render_record_invalid(error)
    render_error(
      code: "unprocessable_entity",
      message: "Validation failed",
      status: :unprocessable_content,
      details: error.record.errors.map { |e| { field: e.attribute, message: e.message } }
    )
  end

  def render_parameter_missing(error)
    render_error(
      code: "parameter_missing",
      message: error.message,
      status: :unprocessable_content,
      details: [{ field: error.param, message: "is required" }]
    )
  end

  def render_invalid_csrf(error)
    render_error(code: "invalid_csrf_token", message: "Invalid or missing CSRF token", status: :forbidden)
  end

  def render_forbidden(error)
    render_error(code: "forbidden", message: "You are not allowed to do that", status: :forbidden)
  end
end
