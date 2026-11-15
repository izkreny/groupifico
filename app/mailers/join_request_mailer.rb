class JoinRequestMailer < ApplicationMailer
  # WHY: the row is minted here, as `SignUpMailer#link` mints its own, because it stores only a digest and the raw token has to reach the URL; and the link arrives as an id rather than a record, so a link turned off or regenerated before the job runs sends nothing instead of failing the job on deserialization.
  def link(join_link_id, email:, first_name:, last_name:, mobile_phone:)
    join_link = JoinLink.find_by(id: join_link_id) or return

    @group_name = join_link.group.name
    @token      = JoinRequest.mint(join_link:, email:, first_name:, last_name:, mobile_phone:)

    mail subject: "Confirm your request to join #{@group_name}", to: email
  end
end
