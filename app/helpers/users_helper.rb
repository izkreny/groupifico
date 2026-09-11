module UsersHelper
  # One sentence, two surfaces: the account screen states it standing, and the controller puts the
  # same words in the flash when a delete is refused. Written once here so a reword cannot move one
  # and leave the other saying something different.
  def solely_owned_groups_message(groups)
    "You still own #{groups.map(&:name).to_sentence}. Give another member the owner role first."
  end
end
