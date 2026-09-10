# The domain a person arrived through, and what it implies about the group they are starting.
# Groupifico is the general brand and Chorifico and Bandifico are the per-domain ones, so this
# resolves which brand a request belongs to rather than renaming anything.
#
# Resolved from the domain rather than from anything on the group, because at the moment a group is
# being created there is no group to ask - and one person can belong to a choir and a band at once,
# so no membership answers it either. #221 and #223 consume the same rule for a sender address and
# for the application chrome; this carries `group_type` alone, since neither of those is scheduled.
class Brand
  # One entry, because `chorifico.com` is the only registered domain. A second one is a row here.
  GROUP_TYPES = { "chorifico.com" => "choir" }.freeze

  # What the general brand's domains get: `localhost`, a bare IP, and `groupifico.com` itself.
  # `general` is the type that exists for a group that is neither a choir nor a band, so it is the
  # honest answer wherever the domain says nothing - which is why `Group` no longer defaults to
  # `choir`.
  DEFAULT_GROUP_TYPE = "general"

  # Every domain answers with this until #223 gives the branded ones their own. Not folded into
  # `GROUP_TYPES`: an absent key there means "general" and here would have to mean "Groupifico",
  # and one map cannot carry two defaults.
  DEFAULT_NAME = "Groupifico"

  # `nil` is an ordinary argument rather than something to guard against: `request.domain` answers
  # nil for a bare IP, and `Current.brand`'s default constructs one with nothing at all.
  #
  # A domain rather than a host, because `ActionDispatch::Http::URL.extract_domain` - which is what
  # `request.domain` calls - already collapses `www.chorifico.com` and `api.www.chorifico.com` onto
  # `chorifico.com`. Matching a host here would answer `general` on any subdomain the proxy serves.
  #
  # Downcased because nothing upstream does it and hostnames are case-insensitive per RFC 4343:
  # `request.host` is the raw `Host` header with the port stripped, and `extract_domain` only
  # splits and rejoins it, so a client sending `Chorifico.com` would otherwise miss the mapping
  # and get a general group.
  def initialize(domain)
    @domain = domain&.downcase
  end

  def group_type
    GROUP_TYPES.fetch(@domain, DEFAULT_GROUP_TYPE)
  end

  def name
    DEFAULT_NAME
  end
end
