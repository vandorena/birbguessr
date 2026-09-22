class BirbPolicy < ApplicationPolicy
  def index? = user.present?

  def show? = user.present?

  # Only admins post birbs. Unlike the admin dashboard, this is not a secret:
  # ApplicationController answers with a redirect and an alert, which tells an
  # ordinary player the rule rather than pretending the page is missing.
  def create? = user.present? && user.admin?

  def new? = create?
end
