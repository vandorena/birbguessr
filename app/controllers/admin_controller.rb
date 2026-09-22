class AdminController < ApplicationController
  # The admin surface should not be discoverable. ApplicationController answers
  # an authorization failure with a redirect and an alert, which confirms that
  # /admin exists; here we 404 instead, the same answer the AdminConstraint
  # gives for the mounted engines. rescue_from in a subclass takes precedence.
  rescue_from Pundit::NotAuthorizedError, with: :not_found

  def index
    authorize :admin, :index?

    @users = User.order(admin: :desc, email_address: :asc)
  end

  private
    def not_found
      raise ActionController::RoutingError, "Not Found"
    end
end
