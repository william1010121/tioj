class AddUserIdToProblems < ActiveRecord::Migration[7.0]
  def change
    add_reference :problems, :user, foreign_key: true
  end
end
