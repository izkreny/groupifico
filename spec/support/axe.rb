require "axe/matchers/be_axe_clean"

# axe-core 4.13 ships `axe.runPartial`, which `Axe::Core#call` prefers, and that path reaches
# `Axe::API::Run#analyze_post_43x` - whose first statement is `page.manage.timeouts.page_load`, a
# Selenium API Cuprite does not have. Legacy mode takes the single-page path instead, and with no
# iframe anywhere in this application the cross-frame path it skips would have found nothing.
Axe::Configuration.instance.legacy_mode = true
Axe::Configuration.instance.skip_iframes = true

# Namespaced for the reason `PaintMatcher` is: `RSpec::Matchers.define` instance-evals its block,
# so a constant assigned inside it lands on Object and is reassigned on every match.
module AxeMatcher
  # WCAG 2.1 AA is cumulative and `according_to` is not. `Axe::API::Rules#according_to` passes its
  # arguments straight into axe's `runOnly: { type: :tag }`, so a lone `:wcag21aa` runs only the
  # rules WCAG 2.1 introduced at AA - a few dozen out of the standard. Measured, not assumed:
  # `image-alt` is tagged at WCAG 2.0 level A in the engine the gem ships, and an image with no
  # `alt` stays green under the 2.1 AA tag alone. `spec/system/axe_matcher_spec.rb` probes both
  # ends of this list; the two levels between them it does not pin, and says so.
  #
  # This is also the one place a rule would be skipped, with `.skipping`, if one ever had to be.
  # Nothing is skipped today: the rule this list first caught was a real defect in the layout.
  STANDARD = [ :wcag2a, :wcag2aa, :wcag21a, :wcag21aa ].freeze

  # `Axe::Core#wrap_driver` probes for methods rather than requiring a driver class, so these are
  # the whole of what axe asks of a browser - and answering them here is what keeps
  # `Capybara::Cuprite::Browser` unreopened. `execute_async_script` is the one that matters: the
  # gem calls Selenium's name for it and Ferrum's is `evaluate_async`. Both append their callback
  # as the last argument, which is what axe's own `arguments[arguments.length - 1]` reads.
  class Page
    def initialize(session)
      @session = session
    end

    def execute_script(script, *args) = @session.execute_script(script, *args)
    def evaluate_script(script, *args) = @session.evaluate_script(script, *args)
    def find_css(selector) = @session.driver.find_css(selector)

    # The wait is read off the browser rather than chosen here, because two numbers that disagree
    # mean the smaller one always wins while the larger one reads as the limit: `evaluate_async`
    # puts its argument in a JS `setTimeout` only, and `Ferrum::Page#command` separately bounds the
    # CDP response by `Ferrum::Browser`'s own `timeout`, which is 5s unless `cuprite.rb` raises it.
    # What this path still buys over `Capybara::Session#evaluate_async_script` is not inheriting
    # `default_max_wait_time`, which is 2s against an audit measured at 0.54s.
    def execute_async_script(script, *args)
      browser = @session.driver.browser
      browser.evaluate_async(script, browser.timeout, *args)
    end
  end
end

# Wraps the gem's matcher rather than replacing it, so a failure carries the gem's own report: the
# rule, its impact, the offending selector and a Deque URL explaining the fix.
RSpec::Matchers.define :be_accessible do
  match do |page|
    @matcher = Axe::Matchers.be_axe_clean.according_to(AxeMatcher::STANDARD)
    @matcher.matches? AxeMatcher::Page.new(page)
  end

  failure_message { @matcher.failure_message }
  failure_message_when_negated { @matcher.failure_message_when_negated }
end
