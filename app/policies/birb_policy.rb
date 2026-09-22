class BirbPolicy < ApplicationPolicy
  # The gallery is the landing page, and it is the advertisement for the game:
  # you can see that there are birbs before you have an account.
  def index? = true

  def show? = user.present?

  # Only admins post birbs. Unlike the admin dashboard, this is not a secret:
  # ApplicationController answers with a redirect and an alert, which tells an
  # ordinary player the rule rather than pretending the page is missing.
  def create? = user.present? && user.admin?

  def new? = create?
end
