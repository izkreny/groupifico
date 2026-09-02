# A record that carries an emailed, single-use credential: it is minted with a digest and an
# expiry, it resolves without being spent, and it is spent exactly once.
#
# The name says what the record is at the include site rather than what it holds. A `SignUp` is a
# request to start a group that happens to carry a credential, not a credential with a group name
# stapled to it, so `EmailedToken` or `Credential` would read as a lie on that model.
#
# `redeem!` is deliberately absent. `SignInToken`'s returns the `User` and `SignUp`'s returns the
# `Member` its transaction created, so what the two share is what makes a record redeemable, never
# the redemption itself.
#
# Everything here is ADR 0004's, moved rather than rewritten: the fifteen minutes it calls "the
# only window in the application", the HMAC digest scheme, and the single-statement spend.
module Redeemable
  extend ActiveSupport::Concern

  # Everything that is not a live, unspent link raises this one error: a blank or malformed value,
  # a digest no row carries, a link already spent, a link past its expiry. They are deliberately
  # indistinguishable to the caller, and the typed error is what keeps a malformed value from
  # arriving as a `TypeError` out of the digest call instead.
  class InvalidToken < StandardError; end

  EXPIRES_IN = 15.minutes

  # 32 bytes is 256 bits, twice what #139 asks for. `SecureRandom.urlsafe_base64` draws with
  # replacement; the `Array#sample` generator ADR 0004 found in `mikker/passwordless` does not,
  # which is how a nominally 36^6 keyspace turned out to be about 2^30.
  TOKEN_BYTES = 32

  included do
    scope :outstanding, -> { where(consumed_at: nil) }
  end

  class_methods do
    # Returns the raw token, which is the only moment it exists outside the email. Nothing stores
    # it: the row carries its digest. The attributes are whatever the including model's own
    # columns are, which is the whole of what differs between the two tables.
    def mint(**attributes)
      SecureRandom.urlsafe_base64(TOKEN_BYTES).tap do |token|
        create!(**attributes, token_digest: digest(token), expires_at: EXPIRES_IN.from_now)
      end
    end

    # Resolves a live link without spending it, so a confirmation page can name what it would do.
    # A read, so it races with nothing: whatever it finds, `spend!`'s conditional UPDATE is still
    # the only thing that decides who gets the outcome. Answers `nil` rather than raising, because
    # its caller renders a page instead of authenticating anybody.
    def pending(token)
      return nil unless usable?(token)

      outstanding.find_by(token_digest: digest(token), expires_at: Time.current..)
    end

    # Spends the link and returns the row it spent, for the caller to build its own outcome on.
    #
    # One conditional UPDATE, acting on the number of rows it changed. Reading the row, comparing
    # in Ruby and then updating it by id is a time-of-check gap that two concurrent redemptions
    # both pass; there is no separate read here to race against. ADR 0004 records the rodauth
    # release that had to close exactly that gap.
    def spend!(token)
      raise InvalidToken unless usable?(token)

      now    = Time.current
      wanted = digest(token)

      spent = outstanding.where(token_digest: wanted, expires_at: now..)
                         .update_all(consumed_at: now, updated_at: now)
      raise InvalidToken if spent.zero?

      # Safe to read only because the row is already spent: whatever else raced for it has lost.
      find_by!(token_digest: wanted)
    end

    # Deterministic, so a lookup by digest is an indexed single-row read and the link needs to
    # carry no account id for one. Keyed off `secret_key_base` through the key generator, so there
    # is no new secret to manage and rotation has rodauth's fallback pattern available.
    def digest(token)
      OpenSSL::HMAC.hexdigest("SHA256", hmac_key, token)
    end

    def consume_all(at: Time.current)
      outstanding.update_all(consumed_at: at, updated_at: at)
    end

    private
      # What "malformed" means, in one place: `digest` raises `TypeError` on anything that is not
      # a string, and every caller has to keep that out of their own contract.
      def usable?(token)
        token.is_a?(String) && token.present?
      end

      # Derived from the model name, so the two tables draw from independent keyspaces. Nothing
      # exploits a shared one, since every lookup is already confined to its own table, but
      # independent is the right default and costs a string.
      def hmac_key
        Rails.application.key_generator.generate_key("#{name} token digest", 32)
      end
  end
end
