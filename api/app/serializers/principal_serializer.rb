# Dispatches /me serialization by principal type. Staff and agency principals
# have different shapes but share a `type` discriminator so the frontend can
# route to the right surface.
module PrincipalSerializer
  module_function

  def call(principal)
    case principal
    when User then UserSerializer.call(principal)
    when AgencyUser then AgencyUserSerializer.call(principal)
    end
  end
end
