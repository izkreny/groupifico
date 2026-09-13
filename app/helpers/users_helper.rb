module UsersHelper
  # The account screen's own sentence. Here rather than in the template because the plural branch is
  # the part worth a spec: one group reads as a name, several as a list, and `to_sentence` is what
  # the reader needs to know which ones to hand over.
  def solely_owned_groups_message(groups)
    "You still own #{groups.map(&:name).to_sentence}. Give another member the owner role first."
  end
end
