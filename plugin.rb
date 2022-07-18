# frozen_string_literal: true

# name: discourse-alias
# about: Support for account aliasing
# version: 0.1
# authors: Jeff Wong
# transpile_js: true

after_initialize do

  # Links a base user to an alias:
  # base_user.add_user_alias alias_user
  add_to_class(:user, :add_user_alias) do |user|
    record_id = self.id
    # If current user is also an alias, follow to the 'base' user
    if custom_fields.include? 'alias_for'
      record_id = custom_fields['alias_for']
    end
    user.custom_fields["alias_for"] = record_id
    user.save_custom_fields
  end

  # Remove linked base user for an alias user.
  # Unmarks a user as an alias to another user, removing the associations
  # alias_user.unmark_as_alias
  add_to_class(:user, :unmark_as_alias) do
    custom_fields.delete "alias_for"
    save_custom_fields
  end

  # Finds all aliases for this user
  add_to_class(:user, :aliases) do
    record_id = self.id
    if custom_fields.include? 'alias_for'
      record_id = custom_fields['alias_for']
    end
    User.joins(:user_custom_fields).where(user_custom_fields: { name: "alias_for", value: record_id }).uniq
  end

  # Finds the underlying record for the current user
  add_to_class(:user, :record_for_alias) do
    if custom_fields.include? 'alias_for'
      record_id = custom_fields['alias_for']
      return User.find_by(id: record_id)
    end
    self
  end

  # Reading trust levels - read from base user record
  add_to_serializer(:user_card, :trust_level) do
    object.record_for_alias.trust_level
  end

  reloadable_patch do
    class ::User
      alias_method :has_trust_level_orig?, :has_trust_level?
      def has_trust_level?(level)
        self.record_for_alias.has_trust_level_orig? level
      end
    end
  end

  # Calculating trust levels - needs to consider posts for all aliases as well?
  # Calculated in Promotion.review, called from topics controllers
  # Grab stats from all associated users? seems rather complicated.
  # How about: after review, check to see if trust level is higher after, and promote base user if so
  # TL3 will need to be checked or updated.
  # manual TL pinnings will also need to affect root user as well.
end
