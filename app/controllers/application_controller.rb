class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private
    # Pundit defaults to `current_user`; the Rails 8 authentication generator exposes
    # the signed-in user through Current instead.
    def pundit_user
      Current.user
    end

    def user_not_authorized
      redirect_back fallback_location: root_path, alert: "You are not authorized to do that."
    end
end
