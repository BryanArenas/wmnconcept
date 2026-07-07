# Any authenticated principal may list configs — agency partners need the price
# list to render the request form (spec §8.2). Mutation routes are not exposed
# yet (admin UI is a later milestone).
class InspectionTypeConfigPolicy < ApplicationPolicy
  def index? = true

  class Scope < ApplicationPolicy::Scope
    def resolve
      super.active.ordered
    end
  end
end
