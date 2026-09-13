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

    # The one mapping that is not the controller's own name, and the reason the map exists at all.
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

  describe "#pushed_screen?" do
    it "is false on the group home, which the Home tab points at" do
      allow(helper).to receive_messages(controller_name: "groups", action_name: "show")

      expect(helper.pushed_screen?(build_stubbed(:group))).to be false
    end

    it "is false on the events list, which the Events tab points at" do
      allow(helper).to receive_messages(controller_name: "events", action_name: "index")

      expect(helper.pushed_screen?(build_stubbed(:group))).to be false
    end

    it "is false on the members list, which the Members tab points at" do
      allow(helper).to receive_messages(controller_name: "members", action_name: "index")

      expect(helper.pushed_screen?(build_stubbed(:group))).to be false
    end

    it "is true on a detail screen" do
      allow(helper).to receive_messages(controller_name: "events", action_name: "show")

      expect(helper.pushed_screen?(build_stubbed(:group))).to be true
    end

    it "is true on a form" do
      allow(helper).to receive_messages(controller_name: "members", action_name: "edit")

      expect(helper.pushed_screen?(build_stubbed(:group))).to be true
    end

    # A roster is pushed and still answers for Events, so this is the one case where the two
    # helpers disagree about the screen and both are right.
    it "is true on a roster, which answers for the Events section" do
      allow(helper).to receive_messages(controller_name: "registrations", action_name: "index")

      expect(helper.pushed_screen?(build_stubbed(:group))).to be true
      expect(helper.shell_section).to eq :events
    end

    it "is false outside a group, where there is no section to be pushed from" do
      allow(helper).to receive_messages(controller_name: "user_profiles", action_name: "show")

      expect(helper.pushed_screen?(build_stubbed(:group))).to be false
    end

    # The new group form and the groups index are the same controller, the same section and the
    # same absent group, so the action is the only thing that separates a pushed screen from the
    # root it is pushed from.
    it "is true on the new group form, the one pushed screen outside a group" do
      allow(helper).to receive_messages(controller_name: "groups", action_name: "new")

      expect(helper.pushed_screen?(nil)).to be true
    end

    it "is false on the groups index, which is the Home section's root without a group" do
      allow(helper).to receive_messages(controller_name: "groups", action_name: "index")

      expect(helper.pushed_screen?(nil)).to be false
    end
  end

  describe "#section_root_path" do
    it "leads to the group home from the Home section" do
      group = build_stubbed(:group)
      allow(helper).to receive(:controller_name).and_return("groups")

      expect(helper.section_root_path(group)).to eq helper.group_path(group)
    end

    it "leads to the events list from anywhere in the Events section" do
      group = build_stubbed(:group)
      allow(helper).to receive(:controller_name).and_return("registrations")

      expect(helper.section_root_path(group)).to eq helper.group_events_path(group)
    end

    it "leads to the members list from the Members section" do
      group = build_stubbed(:group)
      allow(helper).to receive(:controller_name).and_return("members")

      expect(helper.section_root_path(group)).to eq helper.group_members_path(group)
    end

    it "is nothing outside a group" do
      allow(helper).to receive(:controller_name).and_return("user_profiles")

      expect(helper.section_root_path(build_stubbed(:group))).to be_nil
    end

    it "leads to the groups index from the Home section when there is no group" do
      allow(helper).to receive(:controller_name).and_return("groups")

      expect(helper.section_root_path(nil)).to eq helper.groups_path
    end
  end
end
