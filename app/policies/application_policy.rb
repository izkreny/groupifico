# Base class for every policy in this application.
#
# It looks empty and is not. ActionPolicy::Base sets `manage?` as the default rule and defines it
# as false, so a rule a policy does not define falls through to it and is denied rather than
# raising. Deny-by-default is inherited from here; nothing needs writing to get it.
class ApplicationPolicy < ActionPolicy::Base
end
