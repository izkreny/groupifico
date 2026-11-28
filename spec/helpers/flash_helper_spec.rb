require "rails_helper"

RSpec.describe FlashHelper, type: :helper do
  describe "#flash_message" do
    it "passes a plain notice through as it is" do
      expect(helper.flash_message("Member was successfully updated.")).to eq "Member was successfully updated."
    end

    it "builds a hash notice's link into its text" do
      message = { "text" => "Invitation sent to %{link}.", "link" => "new.person@example.com", "url" => "/groups/1/members/2" }

      expect(helper.flash_message(message)).to eq %(Invitation sent to <a class="link" href="/groups/1/members/2">new.person@example.com</a>.)
    end

    # WHY: the link's words are an address somebody typed, and the hash came back through the session, so nothing in it is trusted.
    it "escapes the link's words and the text around it" do
      message = { "text" => "<b>Sent</b> to %{link}.", "link" => "<script>x</script>", "url" => "/groups/1/members/2" }

      expect(helper.flash_message(message)).to eq %(&lt;b&gt;Sent&lt;/b&gt; to <a class="link" href="/groups/1/members/2">&lt;script&gt;x&lt;/script&gt;</a>.)
    end
  end
end
