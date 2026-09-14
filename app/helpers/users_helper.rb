module UsersHelper
  # The account screen's own sentence. Here rather than in the template because the plural branch is
  # the part worth a spec: one group reads as a name, several as a list, and `to_sentence` is what
  # the reader needs to know which ones to hand over.
  def solely_owned_groups_message(groups)
    "You still own #{groups.map(&:name).to_sentence}. Give another member the owner role first."
  end

  # The delete sheet's body. A reader whose every group is still theirs alone, or who belongs to
  # none, leaves nothing by deleting, and `to_sentence` on nothing would read "You leave  and".
  def account_deletion_message(groups)
    if groups.any?
      "You leave #{groups.map(&:name).to_sentence} and every registration goes with you. This can't be undone."
    else
      "Every registration goes with you. This can't be undone."
    end
  end
end
