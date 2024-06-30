require "test_helper"

class AnnouncementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @announcement = announcements(:one)
  end

  test "should get index" do
    sign_in users(:sysadminOne)
    get announcements_url
    assert_response :success
  end

  test "should create announcement" do
    sign_in users(:sysadminOne)
    assert_difference("Announcement.count") do
      post announcements_url, params: { announcement: { body: @announcement.body, title: @announcement.title } }
    end

    assert_redirected_to announcements_url
  end

  test "should get edit" do
    sign_in users(:sysadminOne)
    get edit_announcement_url(@announcement)
    assert_response :success
  end

  test "should update announcement" do
    sign_in users(:sysadminOne)
    patch announcement_url(@announcement), params: { announcement: { body: @announcement.body, title: @announcement.title } }
    assert_redirected_to announcements_url
  end

  test "should destroy announcement" do
    sign_in users(:sysadminOne)
    assert_difference("Announcement.count", -1) do
      delete announcement_url(@announcement)
    end

    assert_redirected_to announcements_url
  end

  test "normal user should not access announcement" do
    sign_in users(:userOne)

    get announcements_url
    assert_response :redirect
    post announcements_url, params: { announcement: { body: @announcement.body, title: @announcement.title } }
    assert_response :redirect
    patch announcement_url(@announcement), params: { announcement: { body: @announcement.body, title: @announcement.title } }
    assert_response :redirect
    delete announcement_url(@announcement)
    assert_response :redirect
  end
end
