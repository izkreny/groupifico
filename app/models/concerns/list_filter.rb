# WHY: what every filtered list asks of its filter, so the events list and the members list draw their tabs, chips and funnel from the same answers. Each filter names its tabs in `TABS`, the parameter that picks one in `TAB`, the open one in `#tab`, and builds its own `#chips` and `#params_with`, since the filters themselves differ.
module ListFilter
  # The record the list lists, which names its route and its noun.
  def model = self.class.module_parent

  def noun = model.model_name.human.downcase

  # WHY: the list never counts, so the funnel says the same thing whichever tab is open.
  def narrowed? = chips.any?

  # WHY: each tab carries every filter on, so switching lists keeps them, the way GitLab's and Mastodon's tabs merge the current query.
  def tabs
    self.class::TABS.map { |value, name| [ name, value, params_with(self.class::TAB => value) ] }
  end

  # WHY: the tab is not a filter, so clearing every filter keeps it.
  def cleared = { self.class::TAB => tab }.compact
end
