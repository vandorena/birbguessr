# Routing constraint for admin-only mounted engines (Flipper UI, Blazer).
#
# Routing constraints run before any controller, so `Current.user` is not yet
# populated — resolve the session straight from the signed cookie instead, the
# same way Authentication#find_session_by_cookie does.
class AdminConstraint
  def self.matches?(request)
    session_id = request.cookie_jar.signed[:session_id]
    return false if session_id.blank?

    Session.find_by(id: session_id)&.user&.admin?
  end
end
