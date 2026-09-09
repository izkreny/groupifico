require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe "#shell_section" do
    it "is home inside the groups controller" do
      allow(helper).to receive(:controller_name).and_return("groups")

      expect(helper.shell_section).to eq :home
    end

    it "is members inside the members controller" do
      allow(helper).to receive(:controller_name).and_return("members")

      expect(helper.shell_section).to eq :members
    end

    it "is events inside the events controller" do
      allow(helper).to receive(:controller_name).and_return("events")

      expect(helper.shell_section).to eq :events
    end

    # The roster of an event is reached through the Events tab and never leaves it, so a
    # registration screen answers for the section above it rather than for itself. This is the one
    # mapping that is not the controller's own name, and the reason the map exists at all.
    it "is events inside the registrations controller, since a roster belongs to its event" do
      allow(helper).to receive(:controller_name).and_return("registrations")

      expect(helper.shell_section).to eq :events
    end

    it "is nothing for a controller outside a group" do
      allow(helper).to receive(:controller_name).and_return("user_profiles")

      expect(helper.shell_section).to be_nil
    end
  end

  describe "#shell_tabs?" do
    it "is true on a list screen inside a group" do
      allow(helper).to receive_messages(controller_name: "events", action_name: "index")

      expect(helper.shell_tabs?(build_stubbed(:group))).to be true
    end

    it "is true on a detail screen inside a group" do
      allow(helper).to receive_messages(controller_name: "members", action_name: "show")

      expect(helper.shell_tabs?(build_stubbed(:group))).to be true
    end

    it "is false on a form" do
      allow(helper).to receive_messages(controller_name: "events", action_name: "new")

      expect(helper.shell_tabs?(build_stubbed(:group))).to be false
    end

    # `create` and `update` re-render their form with `unprocessable_content` on a failed save, so
    # a reader who mistypes a field is looking at a form and must see no tabs. Watched failing:
    # with both dropped from `FORM_ACTIONS` these two examples go red and the four above stay
    # green, which is the whole reason they are named separately.
    it "is false on a failed create, which re-renders the form" do
      allow(helper).to receive_messages(controller_name: "events", action_name: "create")

      expect(helper.shell_tabs?(build_stubbed(:group))).to be false
    end

    it "is false on a failed update, which re-renders the form" do
      allow(helper).to receive_messages(controller_name: "groups", action_name: "update")

      expect(helper.shell_tabs?(build_stubbed(:group))).to be false
    end

    it "is false with no group, which is what keeps them off the groups index" do
      allow(helper).to receive_messages(controller_name: "groups", action_name: "index")

      expect(helper.shell_tabs?(nil)).to be false
    end

    it "is false outside a group entirely" do
      allow(helper).to receive_messages(controller_name: "user_profiles", action_name: "show")

      expect(helper.shell_tabs?(nil)).to be false
    end
  end
end
