require "test_helper"

class AdminControllerTest < ActionDispatch::IntegrationTest
  test "signed-out visitors are sent to sign in" do
    get admin_path

    assert_redirected_to new_login_path
  end

  test "non-admins get a 404, so the admin surface stays undiscoverable" do
    sign_in_as users(:member)

    get admin_path

    assert_response :not_found
  end

  test "admins see the dashboard" do
    sign_in_as users(:admin)

    get admin_path

    assert_response :success
    assert_select "h1", "Admin"
    assert_select "td", users(:member).email_address
  end
end
