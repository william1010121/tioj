# test/models/ability_test.rb
require 'test_helper'

class AbilityTest < ActiveSupport::TestCase
  def setup
    @user_one = users(:userOne)
    @sysadmin_one = users(:sysadminOne)
    @admin_one = users(:adminOne)
    @normal_user_one = users(:normal_userOne)
    @problem_setter_one = users(:problem_setterOne)
    @guest_one = users(:guestOne)
  end

  test "userOne should be able to read and ranklist public problems" do
    ability = Ability.new(@user_one)
    assert ability.can?(:read, Problem.new(visible_state: 'public'))
    assert ability.can?(:ranklist, Problem.new(visible_state: 'public'))
  end

  test "sysadminOne should be able to manage all" do
    ability = Ability.new(@sysadmin_one)
    assert ability.can?(:manage, :all)
  end

  test "adminOne should be able to create and update public problems, read testdata" do
    ability = Ability.new(@admin_one)
    assert ability.can?(:create, Problem)
    assert ability.can?(:update, Problem.new(visible_state: 'public'))
    assert ability.can?(:read, Testdatum)
  end

  test "problem_setterOne should be able to create problems" do
    ability = Ability.new(@problem_setter_one)
    assert ability.can?(:create, Problem)
  end

  test "normal_userOne should have no special permissions" do
    ability = Ability.new(@normal_user_one)
    assert ability.cannot?(:create, Problem)
  end

  test "guestOne should have no special permissions" do
    ability = Ability.new(@guest_one)
    assert ability.cannot?(:create, Problem)
  end

  test "user should manage own problems" do
    problem = Problem.new(user_id: @user_one.id)
    ability = Ability.new(@user_one)
    assert ability.can?(:read, problem)
    assert ability.can?(:destroy, problem)
    assert ability.can?(:rejudge, problem)
    assert ability.can?(:update, problem)
  end

  test "user shouldn't manage other's problems" do
    problem = Problem.new(user_id: @user_one.id + 1)
    ability = Ability.new(@user_one)
    assert ability.cannot?(:create, Problem)
    assert ability.cannot?(:read, problem)
    assert ability.cannot?(:destroy, problem)
    assert ability.cannot?(:rejudge, problem)
    assert ability.cannot?(:update, problem)
  end

  test "sysadmin can create problem" do
    ability = Ability.new(@sysadmin_one)
    assert ability.can?(:create, Problem)
  end

  test "admin can create problem" do
    ability = Ability.new(@admin_one)
    assert ability.can?(:create, Problem)
  end

  test "problem setter can create problem" do
    ability = Ability.new(@problem_setter_one)
    assert ability.can?(:create, Problem)
  end

  test "normal user can't do anything except read and ranklist public problems" do
    ability = Ability.new(@normal_user_one)
    problem = Problem.new(user_id: @normal_user_one.id + 1, visible_state: 'public')
    assert ability.cannot?(:create, Problem)
    assert ability.cannot?(:destroy, problem)
    assert ability.cannot?(:update, problem)
    assert ability.cannot?(:rejudge, problem)
    assert ability.cannot?(:ranklist_old, problem)
    assert ability.can?(:read, problem)
    assert ability.can?(:ranklist, problem)
  end

  test "normal user can't do anything on private problems" do
    ability = Ability.new(@normal_user_one)
    problem = Problem.new(user_id: @normal_user_one.id + 1, visible_state: 'invisible')
    assert ability.cannot?(:create, Problem)
    assert ability.cannot?(:destroy, problem)
    assert ability.cannot?(:update, problem)
    assert ability.cannot?(:rejudge, problem)
    assert ability.cannot?(:ranklist_old, problem)
    assert ability.cannot?(:read, problem)
    assert ability.cannot?(:ranklist, problem)
  end



  test "guest can't create problem"  do
    ability = Ability.new(@guest_one)
    assert ability.cannot?(:create, Problem)
  end
end
