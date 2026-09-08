# ## Schema Information
#
# Table name: `groups`
#
# ### Columns
#
# Name               | Type               | Attributes
# ------------------ | ------------------ | ---------------------------
# **`id`**           | `integer`          | `not null, primary key`
# **`description`**  | `text(100000)`     |
# **`group_type`**   | `integer`          | `not null`
# **`name`**         | `string(250)`      | `not null`
# **`created_at`**   | `datetime`         | `not null`
# **`updated_at`**   | `datetime`         | `not null`
# **`address_id`**   | `integer`          |
#
# ### Foreign Keys
#
# * `address_id` (_ON DELETE => restrict ON UPDATE => cascade_):
#     * **`address_id => addresses.id`**
#
class Group < ApplicationRecord
  belongs_to :address, optional: true, touch: true
  accepts_nested_attributes_for :address, reject_if: -> { it.values.all?(&:empty?) }
  has_many :members, dependent: :destroy
  has_many :events, dependent: :destroy
  # TODO: add order by `counter_cache` aka Adress field `events_count`
  has_many :events_addresses, -> { distinct }, through: :events, source: :address

  enum :group_type, %i[ general choir band ], validate: true

  # Taken from the domain the request arrived on rather than from a fixed value, so a group started
  # on `chorifico.com` is a choir and one started anywhere else is general. `Brand` owns the mapping
  # and `ApplicationController` puts the answer in `Current`.
  #
  # A callback rather than a callable `enum default:`, which the enum would accept: an attribute's
  # Proc default resolves on first read and memoizes, so a record built in one request and first
  # read in another would answer for whichever brand were current at the read. A `before_validation`
  # runs at a defined point inside `save`, so that gap does not exist. ADR 0006 has the evidence.
  #
  # `||=` carries the whole guarantee, and it carries it twice: a submitted type wins over the
  # domain, and an existing group keeps its type when it is edited from a domain implying another,
  # because the column is `null: false` so a persisted row always has one. An `on: :create` guard
  # was tried and removed - nothing could be made to fail without it.
  before_validation -> { self[:group_type] ||= Current.brand.group_type }

  validates_associated :address
  validates :name, presence: true, length: { maximum: 250 }
  validates :description, length: { maximum: 25_000 }

  def addresses
    Address.where(id: events.select(:address_id)).or(Address.where(id: address_id))
  end

  # Whoever starts a group owns it, and both routes to a group say so through here rather than
  # each assembling the same member and role. The user arrives explicitly because only one of the
  # two callers has a session to read it from: `SignUp.redeem!` is creating the account in the
  # same breath, so there is no `Current.user` to reach for.
  #
  # Built rather than saved, because `GroupsController#create` authorizes the group with its
  # membership already on it and then relies on one `save` failing into `render :new`. Returned so
  # that `SignUp.redeem!` has the member to sign in and land.
  def add_owner(user)
    members.build(user: user, roles: [ Role.new(name: Role::OWNER) ])
  end

  # Asked before a group loses an owner, by whichever end is losing one - the member being removed,
  # the role being revoked, or the status leaving `active`. Kept here because "does this group still
  # have an owner" is a fact about the group, and every caller would otherwise write the same join.
  #
  # `active` is what makes the answer mean anything. A `paused` owner is refused every write by the
  # status pre-check, including the write that would restore them, and an `inactive` one has left,
  # so counting either would let the last owner who can actually act be removed while the predicate
  # still answered yes.
  def owned_by_anyone_but?(member)
    members.active.joins(:roles).where(roles: { name: Role::OWNER }).where.not(id: member.id).exists?
  end
end
