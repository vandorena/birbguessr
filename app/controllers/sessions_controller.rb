class SessionsController < ApplicationController
  def destroy
    terminate_session
    redirect_to root_path, notice: "Signed out.", status: :see_other
  end
end
