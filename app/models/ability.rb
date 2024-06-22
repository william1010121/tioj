# frozen_string_literal: true

class Ability
  include CanCan::Ability
  require 'pry-remote'

  def initialize(user)
    user ||= User.new(role: 'guest')

    can [:read,:ranklist], Problem, visible_state: "public"
    if user.role == 'sysadmin'
      can :manage, :all
    elsif user.role == 'admin'
      can :create, Problem
      can :update, Problem, visible_state: "public"
      can :read, Testdatum
    elsif user.role == 'problem_setter'
      can :create, Problem
    elsif user.role == 'normal_user'
    elsif user.role == 'guest'
    end

    if user&.id
      can [:read, :show, :edit, :update, :destroy, :ranklist, :ranklist_old, :rejudge], Problem,user_id: user&.id
    end
  end
end
