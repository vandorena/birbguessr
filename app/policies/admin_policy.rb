# frozen_string_literal: true

# Headless policy for the admin dashboard: there is no record to authorize,
# so the controller calls `authorize :admin, :index?` and Pundit routes the
# symbol here.
class AdminPolicy < ApplicationPolicy
  def index?
    user.present? && user.admin?
  end
end
