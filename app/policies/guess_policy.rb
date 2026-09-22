class GuessPolicy < ApplicationPolicy
  def create? = user.present?

  # "Has this player already guessed?" is deliberately not asked here. It is a
  # uniqueness rule, not an authorization one, and answering it with Pundit
  # would tell a double-submitting player they are "not authorized", then bounce
  # them through redirect_back to wherever they happened to come from.
end
