# Base policy. Deny by default — every permission is opt-in per subclass. The
# `user` is the Pundit principal (a staff User or an AgencyUser via pundit_user).
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index? = false
  def show? = false
  def create? = false
  def new? = create?
  def update? = false
  def edit? = update?
  def destroy? = false

  # Tenancy scope. The base enforces the organization_id floor so no query can
  # ever cross tenants (spec §0) — this is the mechanism, NOT a default_scope.
  # Subclasses call `super` and then narrow further (e.g. an agency user to
  # their own agency).
  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      return scope.none if user.nil?

      scope.where(organization_id: user.organization_id)
    end
  end
end
